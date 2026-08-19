#!/usr/bin/env python3
"""Fail the build when a chart renders a credential into a ConfigMap.

Guardrail 3 (AGENTS.md) says credentials live in Secrets, never ConfigMaps. This
enforces it mechanically: every chart is rendered with `helm template` (default
values, then each `overrides/<chart>/values.*.yaml` in turn), and every rendered
ConfigMap is walked for credential-shaped keys and values.

Rendering rather than grepping templates matters — the risky surface is
`applicationYaml`, an arbitrary user-supplied tree that chart-libs serialises
into a single `application.yaml` ConfigMap key. A secret placed there is
invisible to any template-level grep. Values that parse as nested YAML/JSON are
therefore parsed and walked too.

Exit code 0 = clean, 1 = findings, 2 = the linter itself failed (render error,
missing helm, unreadable allowlist) — never silently pass on breakage.

Usage:
    scripts/lint-configmap-secrets.py
    scripts/lint-configmap-secrets.py --chart auditflow
    scripts/lint-configmap-secrets.py --format github
"""

from __future__ import annotations

import argparse
import fnmatch
import json
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

try:
    import yaml
except ImportError:  # pragma: no cover - environment guard
    sys.exit("lint-configmap-secrets: PyYAML is required (pip install pyyaml)")

REPO_ROOT = Path(__file__).resolve().parent.parent
CHARTS_DIR = REPO_ROOT / "charts"
OVERRIDES_DIR = REPO_ROOT / "overrides"
GLOBAL_VALUES = OVERRIDES_DIR / "global-values.yaml"
ALLOWLIST = REPO_ROOT / "scripts" / "configmap-secrets-allowlist.yaml"

# CRDs the charts render against. Without these, `helm template` refuses to emit
# HTTPRoutes/ServiceMonitors/ExternalSecrets and whole charts fail to render —
# which would hide their ConfigMaps from this lint.
API_VERSIONS = [
    "gateway.networking.k8s.io/v1",
    "gateway.networking.k8s.io/v1beta1",
    "monitoring.coreos.com/v1",
    "external-secrets.io/v1",
    "external-secrets.io/v1beta1",
    "traefik.io/v1alpha1",
]

# Charts that deliberately refuse to render against their shipped defaults, mapped
# to the minimum override that makes them renderable. labs64io-ecosystem `fail`s
# while its demo passwords are unchanged (charts/labs64io-ecosystem/templates/
# _guards.tpl) — that guard is the point, so the linter supplies the demo flag
# rather than the guard being softened to keep tooling happy.
RENDER_SETS = {
    "labs64io-ecosystem": ["demoMode=true"],
}


def render_sets_for(chart: str) -> list[str]:
    args: list[str] = []
    for expr in RENDER_SETS.get(chart, []):
        args += ["--set", expr]
    return args


# --- heuristics ---------------------------------------------------------------

# Key names that denote a credential. Matched against the final path segment,
# case-insensitively, on word boundaries so `passwordSecretName` (a reference)
# does not trip the same rule as `password` (a value).
SECRET_KEY_PATTERN = re.compile(
    r"(?:^|[._\-/])(?:"
    r"password|passwd|pwd|secret|token|apikey|api_key|accesskey|access_key"
    r"|secretkey|secret_key|privatekey|private_key|credential|credentials"
    r"|client_secret|clientsecret|auth_token|authtoken|bearer|passphrase"
    r"|sasl_password|dsn|connection_string|connectionstring"
    r")(?:$|[._\-/])",
    re.IGNORECASE,
)

# Key names that only ever hold a *pointer* to a credential, never the credential
# itself. These are the whole point of the guardrail, so they must not be flagged.
REFERENCE_KEY_PATTERN = re.compile(
    r"(?:secretname|secretref|secretkeyref|existingsecret|secretkey_?ref"
    r"|passwordsecret|secretprovider|remoteref|storename|secretstore"
    r"|imagepullsecrets?|_?secrets?_?name|keyref)$",
    re.IGNORECASE,
)

# Value shapes that are a credential regardless of what the key is called.
VALUE_SHAPE_RULES: list[tuple[str, re.Pattern[str]]] = [
    ("PEM private key", re.compile(r"-----BEGIN (?:[A-Z ]+ )?PRIVATE KEY-----")),
    ("AWS access key id", re.compile(r"\b(?:AKIA|ASIA)[0-9A-Z]{16}\b")),
    ("JWT", re.compile(r"\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]+")),
    ("GitHub token", re.compile(r"\bgh[pousr]_[A-Za-z0-9]{30,}\b")),
    ("Slack token", re.compile(r"\bxox[abposr]-[A-Za-z0-9-]{10,}\b")),
    ("Stripe secret key", re.compile(r"\b[sr]k_(?:live|test)_[A-Za-z0-9]{16,}\b")),
    ("Google API key", re.compile(r"\bAIza[0-9A-Za-z_-]{35}\b")),
    ("private key block", re.compile(r"-----BEGIN OPENSSH PRIVATE KEY-----")),
    (
        "URI with embedded credentials",
        # scheme://user:pass@host — the classic way a password hides inside a
        # perfectly innocent-looking `url` key.
        re.compile(r"\b[a-z][a-z0-9+.-]*://[^\s:/@]+:[^\s:/@]+@[^\s/]+", re.IGNORECASE),
    ),
]

# Values that are obviously not a live credential even under a secret-shaped key.
PLACEHOLDER_PATTERN = re.compile(
    r"^\s*(?:"
    r"|<[^>]*>"                      # <your-password-here>
    r"|\$\{[^}]*\}"                  # ${SOME_ENV}  (Spring/helm indirection)
    r"|\{\{[^}]*\}\}"                # leftover template
    r"|change[-_ ]?me|changeit|replace[-_ ]?me|placeholder|example|dummy|none|null|nil"
    r"|todo|tbd|xxx+|\*+|redacted|omitted"
    r")\s*$",
    re.IGNORECASE,
)

# Helm renders absent values as empty; nothing to leak.
EMPTY_VALUES = {"", "~", "null", "None"}


@dataclass(frozen=True)
class Finding:
    chart: str
    values_file: str
    configmap: str
    path: str
    rule: str
    detail: str

    @property
    def location(self) -> str:
        return f"{self.chart}[{self.values_file}] ConfigMap/{self.configmap} {self.path}"

    def allow_key(self) -> str:
        """Stable identifier an allowlist entry can match with globs."""
        return f"{self.chart}/{self.configmap}/{self.path}"


# --- rendering ----------------------------------------------------------------


def chart_dirs(only: str | None) -> list[Path]:
    charts = []
    for d in sorted(CHARTS_DIR.iterdir()):
        chart_yaml = d / "Chart.yaml"
        if not chart_yaml.is_file():
            continue
        if only and d.name != only:
            continue
        meta = yaml.safe_load(chart_yaml.read_text()) or {}
        # Library charts render nothing on their own.
        if meta.get("type") == "library":
            continue
        charts.append(d)
    return charts


def value_files_for(chart: str) -> list[tuple[str, list[Path]]]:
    """Every values combination worth linting, as (label, files)."""
    combos: list[tuple[str, list[Path]]] = [("values.yaml", [])]
    override_dir = OVERRIDES_DIR / chart
    if not override_dir.is_dir():
        return combos
    for override in sorted(override_dir.glob("values.*.yaml")):
        files = [GLOBAL_VALUES] if GLOBAL_VALUES.is_file() else []
        # values.secrets.local.yaml is a companion file, not a standalone
        # profile — layer it under the profile it belongs to.
        if override.name != "values.secrets.local.yaml":
            secrets_companion = override_dir / "values.secrets.local.yaml"
            if override.name == "values.local.yaml" and secrets_companion.is_file():
                combos.append(
                    (
                        f"{override.name}+secrets",
                        files + [override, secrets_companion],
                    )
                )
        combos.append((override.name, files + [override]))
    return combos


def render(chart_dir: Path, values: list[Path]) -> str:
    cmd = ["helm", "template", f"lint-{chart_dir.name}", str(chart_dir)]
    for api in API_VERSIONS:
        cmd += ["--api-versions", api]
    cmd += render_sets_for(chart_dir.name)
    for v in values:
        cmd += ["-f", str(v)]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        raise RuntimeError(f"helm template failed for {chart_dir.name}:\n{proc.stderr.strip()}")
    return proc.stdout


# --- inspection ---------------------------------------------------------------


def maybe_structured(value: str):
    """Parse a string that is itself a YAML/JSON document, else return None.

    `applicationYaml` and tenant configs arrive as one big string under a single
    ConfigMap key; their contents are exactly where a credential hides.
    """
    if "\n" not in value and ":" not in value:
        return None
    try:
        parsed = yaml.safe_load(value)
    except yaml.YAMLError:
        return None
    return parsed if isinstance(parsed, (dict, list)) else None


def is_placeholder(value: str) -> bool:
    stripped = value.strip()
    return stripped in EMPTY_VALUES or bool(PLACEHOLDER_PATTERN.match(stripped))


def inspect_value(path: str, value: str) -> list[tuple[str, str]]:
    """Return (rule, detail) pairs for a single leaf value."""
    hits: list[tuple[str, str]] = []
    leaf = path.rsplit(".", 1)[-1].strip("[]\"'")

    if REFERENCE_KEY_PATTERN.search(leaf):
        return hits  # a pointer to a Secret is the fix, not the finding

    if SECRET_KEY_PATTERN.search(leaf) and not is_placeholder(value):
        hits.append(("secret-shaped key", f"key `{leaf}` carries a literal value"))

    for rule, pattern in VALUE_SHAPE_RULES:
        if pattern.search(value):
            hits.append(("secret-shaped value", rule))
            break
    return hits


def walk(node, path: str, sink: list[tuple[str, str, str]]) -> None:
    """Collect (path, rule, detail) findings from an arbitrary rendered tree."""
    if isinstance(node, dict):
        for key, child in node.items():
            walk(child, f"{path}.{key}" if path else str(key), sink)
    elif isinstance(node, list):
        for i, child in enumerate(node):
            walk(child, f"{path}[{i}]", sink)
    elif isinstance(node, str):
        structured = maybe_structured(node)
        if structured is not None:
            walk(structured, path, sink)
            return
        for rule, detail in inspect_value(path, node):
            sink.append((path, rule, detail))
    elif node is not None:
        for rule, detail in inspect_value(path, str(node)):
            sink.append((path, rule, detail))


def scan_manifests(manifests: str, chart: str, label: str) -> list[Finding]:
    findings: list[Finding] = []
    for doc in yaml.safe_load_all(manifests):
        if not isinstance(doc, dict) or doc.get("kind") != "ConfigMap":
            continue
        name = (doc.get("metadata") or {}).get("name", "<unnamed>")
        for section in ("data", "binaryData"):
            block = doc.get(section)
            if not isinstance(block, dict):
                continue
            sink: list[tuple[str, str, str]] = []
            walk(block, section, sink)
            for path, rule, detail in sink:
                findings.append(Finding(chart, label, name, path, rule, detail))
    return findings


# --- allowlist ----------------------------------------------------------------


def load_allowlist() -> list[dict]:
    if not ALLOWLIST.is_file():
        return []
    data = yaml.safe_load(ALLOWLIST.read_text()) or {}
    entries = data.get("allow") or []
    for entry in entries:
        if not entry.get("match") or not entry.get("reason"):
            raise ValueError(f"allowlist entry needs both `match` and `reason`: {entry!r}")
    return entries


def allowed(finding: Finding, entries: list[dict]) -> bool:
    return any(fnmatch.fnmatch(finding.allow_key(), e["match"]) for e in entries)


# --- reporting ----------------------------------------------------------------


def report(findings: list[Finding], fmt: str) -> None:
    if fmt == "github":
        for f in findings:
            print(
                f"::error title=Credential in ConfigMap::{f.location} — {f.rule}: {f.detail}"
            )
        return
    if fmt == "json":
        print(json.dumps([f.__dict__ for f in findings], indent=2))
        return
    for f in findings:
        print(f"  FAIL {f.location}")
        print(f"       {f.rule}: {f.detail}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--chart", help="lint a single chart instead of all of them")
    parser.add_argument(
        "--format", choices=["text", "github", "json"], default="text"
    )
    args = parser.parse_args()

    if not shutil.which("helm"):
        print("lint-configmap-secrets: helm not found on PATH", file=sys.stderr)
        return 2

    try:
        allowlist = load_allowlist()
    except (ValueError, yaml.YAMLError) as exc:
        print(f"lint-configmap-secrets: bad allowlist: {exc}", file=sys.stderr)
        return 2

    charts = chart_dirs(args.chart)
    if not charts:
        print("lint-configmap-secrets: no charts to lint", file=sys.stderr)
        return 2

    findings: list[Finding] = []
    suppressed = 0
    for chart_dir in charts:
        for label, values in value_files_for(chart_dir.name):
            try:
                manifests = render(chart_dir, values)
            except RuntimeError as exc:
                print(f"lint-configmap-secrets: {exc}", file=sys.stderr)
                return 2
            for finding in scan_manifests(manifests, chart_dir.name, label):
                if allowed(finding, allowlist):
                    suppressed += 1
                    continue
                findings.append(finding)

    # Same ConfigMap key often renders identically across values profiles; report
    # each distinct location once.
    seen: set[tuple[str, str, str, str]] = set()
    unique: list[Finding] = []
    for f in findings:
        key = (f.chart, f.configmap, f.path, f.rule)
        if key in seen:
            continue
        seen.add(key)
        unique.append(f)

    if unique:
        print(f"Credential-shaped values found in {len(unique)} ConfigMap location(s):\n")
        report(unique, args.format)
        print(
            "\nMove these to a Secret (`secrets.data` / `externalSecrets`) and reference "
            "them via envFrom or secretKeyRef.\nIf a finding is a false positive, add it "
            f"to {ALLOWLIST.relative_to(REPO_ROOT)} with a reason."
        )
        return 1

    scanned = len(charts)
    print(
        f"lint-configmap-secrets: clean — {scanned} chart(s) rendered, "
        f"no credentials in ConfigMaps ({suppressed} allowlisted)."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())

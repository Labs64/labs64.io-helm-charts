#!/usr/bin/env python3
"""Helm chart authoring checklist (roadmap item 30) — a gate that runs, not prose.

Four categories, each grounded in an incident or convention already established
in this codebase (see AGENTS.md / OBSERVABILITY.md / DATABASES.md):

  1. Ingress annotations / no rogue Ingress. `chart-libs.gateway-routes` is the
     ONLY place allowed to emit `kind: Ingress` — it hard-fails at render time
     if a non-public route would be served through it, because Ingress has no
     equivalent to the HTTPRoute's ForwardAuth/Cerbos enforcement. A second,
     hand-rolled Ingress template in a module chart would bypass that check
     entirely. Static check: no module chart template may declare `kind:
     Ingress` outside chart-libs.

  2. Sub-path PV mounts. A volumeMount with `subPath` does not receive
     ConfigMap/Secret updates the way a directory mount does (kubelet's
     periodic sync does not touch subPath-mounted files) — a real, easy-to-hit
     "why didn't my ConfigMap change take effect" trap. Every subPath mount in
     the fleet must be a deliberate, reviewed exception, recorded in
     scripts/chart-authoring-allowlist.yaml with a reason; a new one that
     isn't is exactly the case this check exists to catch.

  3. Probe defaults. Every container in a rendered Deployment must declare
     both a livenessProbe and a readinessProbe, each with periodSeconds > 0
     and failureThreshold > 0 — a probe present but misconfigured to (0, 0)
     is silently the same as having none.

  4. NetworkPolicy egress. Guardrail 10 (AGENTS.md): new services must declare
     egress NetworkPolicies restricting outbound traffic to their own
     databases — never a blanket allow. Every application chart must declare
     a `networkPolicy` key in its own values.yaml (present, not merely
     inherited silently), and when rendered with networkPolicy.enabled=true,
     its egress rules must never contain an empty `{}` selector (which,
     combined with no ports restriction, is an allow-all).

Usage:
    scripts/lint-chart-authoring.py
    scripts/lint-chart-authoring.py --chart auditflow
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parent.parent
CHARTS_DIR = REPO_ROOT / "charts"
ALLOWLIST = REPO_ROOT / "scripts" / "chart-authoring-allowlist.yaml"

API_VERSIONS = [
    "gateway.networking.k8s.io/v1",
    "gateway.networking.k8s.io/v1beta1",
    "monitoring.coreos.com/v1",
    "external-secrets.io/v1",
    "external-secrets.io/v1beta1",
    "traefik.io/v1alpha1",
]


@dataclass
class Finding:
    rule: str
    chart: str
    where: str
    detail: str

    def __str__(self) -> str:
        return f"[{self.rule}] {self.chart} {self.where}: {self.detail}"


def app_chart_dirs(only: str | None) -> list[Path]:
    charts = []
    for d in sorted(CHARTS_DIR.iterdir()):
        chart_yaml = d / "Chart.yaml"
        if not chart_yaml.is_file():
            continue
        if only and d.name != only:
            continue
        meta = yaml.safe_load(chart_yaml.read_text()) or {}
        if meta.get("type") == "library":
            continue
        charts.append(d)
    return charts


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


def render(chart_dir: Path, extra_args: list[str] | None = None) -> str:
    cmd = ["helm", "template", f"lint-{chart_dir.name}", str(chart_dir)]
    for api in API_VERSIONS:
        cmd += ["--api-versions", api]
    cmd += render_sets_for(chart_dir.name)
    cmd += extra_args or []
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        raise RuntimeError(f"helm template failed for {chart_dir.name}:\n{proc.stderr.strip()}")
    return proc.stdout


# --- 1. no rogue Ingress --------------------------------------------------------


def check_no_rogue_ingress(chart_dir: Path, findings: list[Finding]) -> None:
    for template in chart_dir.glob("templates/**/*.*"):
        if not template.is_file():
            continue
        text = template.read_text(errors="ignore")
        for lineno, line in enumerate(text.splitlines(), start=1):
            if line.strip() == "kind: Ingress":
                findings.append(Finding(
                    "rogue-ingress", chart_dir.name,
                    f"{template.relative_to(chart_dir)}:{lineno}",
                    "declares kind: Ingress directly; only chart-libs.gateway-routes may do this "
                    "(it hard-fails on non-public routes — a second Ingress template bypasses that).",
                ))


# --- 2. subPath allowlist --------------------------------------------------------


def load_allowlist() -> set[str]:
    if not ALLOWLIST.is_file():
        return set()
    data = yaml.safe_load(ALLOWLIST.read_text()) or {}
    entries = data.get("allow") or []
    allowed = set()
    for entry in entries:
        if not entry.get("chart") or not entry.get("subPath") or not entry.get("reason"):
            raise ValueError(f"allowlist entry needs chart, subPath and reason: {entry!r}")
        allowed.add((entry["chart"], entry["subPath"]))
    return allowed


def walk_containers(manifests: str):
    for doc in yaml.safe_load_all(manifests):
        if not isinstance(doc, dict) or doc.get("kind") != "Deployment":
            continue
        name = doc.get("metadata", {}).get("name", "<unnamed>")
        pod_spec = (((doc.get("spec") or {}).get("template") or {}).get("spec")) or {}
        containers = (pod_spec.get("containers") or []) + (pod_spec.get("initContainers") or [])
        for c in containers:
            yield name, c


def check_subpath_allowlist(chart_dir: Path, manifests: str, allowed: set[tuple[str, str]],
                             findings: list[Finding]) -> None:
    for deployment_name, container in walk_containers(manifests):
        for mount in container.get("volumeMounts") or []:
            sub_path = mount.get("subPath")
            if not sub_path:
                continue
            key = (chart_dir.name, sub_path)
            if key not in allowed:
                findings.append(Finding(
                    "subpath-not-allowlisted", chart_dir.name,
                    f"Deployment/{deployment_name} container={container.get('name')} mount={mount.get('name')}",
                    f"subPath '{sub_path}' is not in {ALLOWLIST.name} — subPath-mounted files do not "
                    f"receive live ConfigMap/Secret updates (no kubelet periodic sync). Add it with a "
                    f"reason if deliberate, or switch to a directory mount.",
                ))


# --- 3. probe defaults -----------------------------------------------------------


def check_probes(chart_dir: Path, manifests: str, findings: list[Finding]) -> None:
    for deployment_name, container in walk_containers(manifests):
        where = f"Deployment/{deployment_name} container={container.get('name')}"
        for probe_kind in ("livenessProbe", "readinessProbe"):
            probe = container.get(probe_kind)
            if not probe:
                findings.append(Finding(
                    "missing-probe", chart_dir.name, where,
                    f"no {probe_kind} configured.",
                ))
                continue
            period = probe.get("periodSeconds", 10)
            threshold = probe.get("failureThreshold", 3)
            if not (isinstance(period, (int, float)) and period > 0):
                findings.append(Finding(
                    "invalid-probe", chart_dir.name, where,
                    f"{probe_kind}.periodSeconds={period!r} must be > 0.",
                ))
            if not (isinstance(threshold, (int, float)) and threshold > 0):
                findings.append(Finding(
                    "invalid-probe", chart_dir.name, where,
                    f"{probe_kind}.failureThreshold={threshold!r} must be > 0.",
                ))


# --- 4. NetworkPolicy egress -----------------------------------------------------


@dataclass(frozen=True)
class WorkloadKind:
    """One long-running workload a chart may declare, and where its own
    NetworkPolicy configuration lives (backend and UI are independent —
    chart-libs.ui-networkpolicy is deliberately not a passthrough of the
    backend's, since a UI has no broker/database/PDP dependency of its own)."""

    label: str
    deployment_markers: tuple[str, ...]
    values_path: tuple[str, ...]
    enable_set: str


WORKLOAD_KINDS = (
    WorkloadKind("backend", ("kind: Deployment", "kind: StatefulSet",
                              'include "chart-libs.deployment"'),
                 ("networkPolicy",), "networkPolicy.enabled=true"),
    WorkloadKind("ui", ('include "chart-libs.ui-deployment"',),
                 ("ui", "networkPolicy"), "ui.networkPolicy.enabled=true"),
)


def workload_kinds_present(chart_dir: Path) -> list[WorkloadKind]:
    """Which of WORKLOAD_KINDS this chart's OWN templates declare.

    Umbrella charts declare none (their Deployments belong to dependencies,
    which render separately and are covered by the dependency's own lint run —
    checking rendered output here would false-positive on those). One-shot Job
    charts (e.g. a connectivity pre-flight check, which needs broad egress by
    design) also declare none. Hence a static check over this chart's own
    templates/, never rendered output.
    """
    present = []
    for template in (chart_dir / "templates").glob("**/*.*"):
        if not template.is_file():
            continue
        text = template.read_text(errors="ignore")
        for kind in WORKLOAD_KINDS:
            if kind not in present and any(m in text for m in kind.deployment_markers):
                present.append(kind)
    return present


def nested_get(values: dict, path: tuple[str, ...]):
    node = values
    for key in path:
        if not isinstance(node, dict) or key not in node:
            return None
        node = node[key]
    return node


def check_network_policy(chart_dir: Path, findings: list[Finding]) -> None:
    values = yaml.safe_load((chart_dir / "values.yaml").read_text()) or {}

    for kind in workload_kinds_present(chart_dir):
        where = f"values.yaml ({kind.label})"
        if nested_get(values, kind.values_path) is None:
            findings.append(Finding(
                "networkpolicy-not-declared", chart_dir.name, where,
                f"no `{'.'.join(kind.values_path)}` key declared for the {kind.label} workload — "
                f"guardrail 10 requires every service to be able to restrict its own egress; a "
                f"workload with no networkPolicy key can never opt in.",
            ))
            continue

        try:
            manifests = render(chart_dir, ["--set", kind.enable_set])
        except RuntimeError as exc:
            findings.append(Finding(
                "networkpolicy-not-enableable", chart_dir.name, f"values.schema.json ({kind.label})",
                f"declares `{'.'.join(kind.values_path)}` but rendering with {kind.enable_set} "
                f"fails schema validation — the key exists but cannot actually be turned on: {exc}",
            ))
            continue

        found_policy = False
        for doc in yaml.safe_load_all(manifests):
            if not isinstance(doc, dict) or doc.get("kind") != "NetworkPolicy":
                continue
            name = doc.get("metadata", {}).get("name", "<unnamed>")
            # Attribute each rendered NetworkPolicy to backend or UI by name
            # convention (chart-libs suffixes the UI one with "-ui") so a
            # chart with both workloads doesn't cross-check the wrong one.
            is_ui_policy = name.endswith("-ui")
            if (kind.label == "ui") != is_ui_policy:
                continue
            found_policy = True
            for rule in (doc.get("spec") or {}).get("egress") or []:
                to = rule.get("to")
                ports = rule.get("ports")
                if not to and not ports:
                    findings.append(Finding(
                        "networkpolicy-allow-all-egress", chart_dir.name, f"NetworkPolicy/{name}",
                        "an egress rule with neither `to` nor `ports` allows all egress traffic.",
                    ))
                    continue
                for peer in to or []:
                    if peer == {} or peer.get("podSelector") == {} and "namespaceSelector" not in peer:
                        findings.append(Finding(
                            "networkpolicy-allow-all-egress", chart_dir.name, f"NetworkPolicy/{name}",
                            f"egress peer {peer!r} matches every pod in the current namespace with no "
                            f"further restriction.",
                        ))
        if not found_policy:
            findings.append(Finding(
                "networkpolicy-not-rendered", chart_dir.name, f"rendered output ({kind.label})",
                f"{kind.enable_set} was set but no matching NetworkPolicy object rendered — "
                f"chart-libs.networkpolicy/ui-networkpolicy may not be wired into this chart's "
                f"templates for the {kind.label} workload.",
            ))


# --- driver -----------------------------------------------------------------------


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--chart", help="lint a single chart instead of all of them")
    args = parser.parse_args()

    try:
        allowed = load_allowlist()
    except (ValueError, yaml.YAMLError) as exc:
        print(f"lint-chart-authoring: bad allowlist: {exc}", file=sys.stderr)
        return 2

    charts = app_chart_dirs(args.chart)
    if not charts:
        print("lint-chart-authoring: no charts to lint", file=sys.stderr)
        return 2

    findings: list[Finding] = []
    for chart_dir in charts:
        check_no_rogue_ingress(chart_dir, findings)
        try:
            manifests = render(chart_dir)
        except RuntimeError as exc:
            print(f"lint-chart-authoring: {exc}", file=sys.stderr)
            return 2
        check_subpath_allowlist(chart_dir, manifests, allowed, findings)
        check_probes(chart_dir, manifests, findings)
        check_network_policy(chart_dir, findings)

    if findings:
        print(f"Chart authoring checklist found {len(findings)} issue(s):\n")
        for f in findings:
            print(f"  FAIL {f}")
        print(
            "\nSee scripts/lint-chart-authoring.py's module docstring for the rationale behind "
            "each rule. A subPath false positive goes in scripts/chart-authoring-allowlist.yaml "
            "with a reason."
        )
        return 1

    print(f"lint-chart-authoring: clean — {len(charts)} chart(s) checked.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

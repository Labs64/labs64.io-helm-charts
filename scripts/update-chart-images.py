#!/usr/bin/env python3
"""Write released image digests into a chart — the Helm end of the release pipeline.

A module release publishes one or more images and reports each one's digest
(`labs64.io-workspace/.github/workflows/docker-publish.yml`). This script takes
those digests and pins them in the chart, so what a cluster runs is the exact
artifact the release validated rather than whatever a mutable tag resolves to at
sync time. Neither Docker Hub nor GHCR can enforce tag immutability, so the digest
is the only identity that cannot move underneath a running workload.

What it changes, and why each part matters:

  1. `values.yaml` — every supplied image's `digest:`. Blocks are located by
     matching their `repository:` value, not by a hand-maintained path map: a
     chart that grows a fourth image is handled automatically, and a chart that
     renames one fails loudly instead of silently skipping it.

  2. `Chart.yaml` — `appVersion` to the released version, and `version` bumped
     (patch by default). The bump is not optional bookkeeping: chart-releaser
     runs with `skip_existing: true`, so a chart whose `version` did not move is
     never republished, and the change would reach no cluster. Chart CI enforces
     the same rule ("Enforce chart version bump").

  3. Nothing else. Edits are line-level, so comments, ordering, and the
     `# --` helm-docs annotations in values.yaml survive untouched — a YAML
     round-trip through PyYAML would silently strip all of them.

Two safety properties the release pipeline depends on:

  * **All-or-nothing.** Every first-party (`labs64/…`) image block in the chart
     must receive a digest. A chart's images share one `appVersion` scalar, so
     pinning two of AuditFlow's three would deploy a mixed set that no release
     ever validated. Third-party wrapper images (swagger-ui, cerbos) are exempt —
     they have no Labs64.IO release.

  * **Idempotent.** Release events are replayable. A second run with the same
     inputs is a no-op: no digest rewrite, and crucially no version bump, so a
     redelivered event cannot inflate the chart version.

Usage:
    scripts/update-chart-images.py --chart auditflow --app-version 1.4.0 \\
        --image labs64/auditflow@sha256:<64 hex> \\
        --image labs64/auditflow-transformer@sha256:<64 hex> \\
        --image labs64/auditflow-sink@sha256:<64 hex>

    scripts/update-chart-images.py --chart checkout --app-version 1.2.0 \\
        --image labs64/checkout@sha256:... --image labs64/checkout-ui@sha256:... \\
        --bump minor --check

    # From a release event payload (how CI calls it — see load_event):
    scripts/update-chart-images.py --event-file event.json
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parent.parent
CHARTS_DIR = REPO_ROOT / "charts"

DIGEST_RE = re.compile(r"^sha256:[a-f0-9]{64}$")
VERSION_RE = re.compile(r"^\d+\.\d+\.\d+$")
# Images published by Labs64.IO itself; everything else in a chart is upstream.
FIRST_PARTY_PREFIX = "labs64/"


class UpdateError(Exception):
    """A condition that must stop the update rather than produce a partial chart."""


@dataclass
class Change:
    file: str
    what: str
    old: str
    new: str


@dataclass
class Result:
    changes: list[Change] = field(default_factory=list)

    @property
    def changed(self) -> bool:
        return bool(self.changes)


# --- values.yaml ----------------------------------------------------------------


def find_image_blocks(values: dict) -> dict[str, list[str]]:
    """Map repository -> dotted path of every mapping holding a `repository` key.

    A list, because nothing prevents a chart from referencing the same image
    twice; the caller updates all of them.
    """
    found: dict[str, list[str]] = {}

    def walk(node, path: list[str]) -> None:
        if isinstance(node, dict):
            repo = node.get("repository")
            if isinstance(repo, str):
                found.setdefault(repo, []).append(".".join(path))
            for key, value in node.items():
                walk(value, path + [str(key)])
        elif isinstance(node, list):
            for i, value in enumerate(node):
                walk(value, path + [str(i)])

    walk(values, [])
    return found


def indent_of(line: str) -> int:
    return len(line) - len(line.lstrip(" "))


def set_digest(lines: list[str], repository: str, digest: str) -> tuple[bool, str]:
    """Rewrite the `digest:` line of the block declaring `repository`.

    Returns (changed, previous_value). Raises if the repository or its sibling
    `digest:` key is absent — a chart on chart-libs < 0.3.0 cannot be pinned, and
    saying so beats writing a value the templates ignore.
    """
    repo_line = None
    for i, line in enumerate(lines):
        m = re.match(r"^(\s*)repository:\s*(\S+)\s*$", line)
        if m and m.group(2).strip("\"'") == repository:
            repo_line = i
            break
    if repo_line is None:
        raise UpdateError(f"no image block with repository '{repository}'")

    base = indent_of(lines[repo_line])
    for i in range(repo_line + 1, len(lines)):
        line = lines[i]
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        current = indent_of(line)
        if current < base:
            break  # left the block
        if current > base:
            continue  # nested under a sibling key
        m = re.match(r"^(\s*)digest:\s*(.*?)\s*$", line)
        if m:
            previous = m.group(2).strip("\"'")
            if previous == digest:
                return False, previous
            lines[i] = f'{m.group(1)}digest: "{digest}"\n'
            return True, previous
    raise UpdateError(
        f"image block '{repository}' has no `digest:` key "
        f"(chart needs chart-libs >= 0.3.0 and a `digest: \"\"` default)"
    )


# --- Chart.yaml -----------------------------------------------------------------


def bump_version(version: str, part: str) -> str:
    if part == "none":
        return version
    if not VERSION_RE.match(version):
        raise UpdateError(f"chart version '{version}' is not MAJOR.MINOR.PATCH; cannot bump")
    major, minor, patch = (int(x) for x in version.split("."))
    if part == "patch":
        return f"{major}.{minor}.{patch + 1}"
    if part == "minor":
        return f"{major}.{minor + 1}.0"
    if part == "major":
        return f"{major + 1}.0.0"
    raise UpdateError(f"unknown bump '{part}'")


def set_scalar(lines: list[str], key: str, value: str, quote: bool = False) -> tuple[bool, str]:
    """Rewrite a top-level `key: value` line.

    `quote` is on for appVersion, which is free-form and may legitimately be
    something YAML would coerce — an unquoted `1.10` is the float 1.1. Chart
    `version` is always MAJOR.MINOR.PATCH and is left bare to match how every
    Chart.yaml in this repo is written.
    """
    for i, line in enumerate(lines):
        m = re.match(rf"^{re.escape(key)}:\s*(.*?)\s*$", line)
        if m:
            previous = m.group(1).strip("\"'")
            if previous == value:
                return False, previous
            lines[i] = f'{key}: "{value}"\n' if quote else f"{key}: {value}\n"
            return True, previous
    raise UpdateError(f"Chart.yaml has no top-level `{key}:`")


# --- orchestration --------------------------------------------------------------


def parse_image_arg(arg: str) -> tuple[str, str]:
    if "@" not in arg:
        raise UpdateError(f"--image must be repository@digest, got '{arg}'")
    repository, digest = arg.rsplit("@", 1)
    if not repository:
        raise UpdateError(f"--image has an empty repository: '{arg}'")
    if not DIGEST_RE.match(digest):
        raise UpdateError(f"invalid digest '{digest}' (expected sha256:<64 lowercase hex>)")
    return repository, digest


@dataclass
class Event:
    chart: str
    version: str
    images: dict[str, str]
    bump: str


def load_event(path: Path) -> Event:
    """Parse a release event payload (the `client_payload` of a repository_dispatch).

    Read from a file rather than shell arguments on purpose: the payload arrives
    from another repository's workflow, so it is untrusted input and must never
    reach a shell. Every field is type- and format-checked here; the chart's own
    contents are validated later by update_chart.

        {"chart": "auditflow", "version": "1.4.0", "bump": "patch",
         "images": [{"image": "labs64/auditflow", "digest": "sha256:<64 hex>"}, ...]}
    """
    try:
        data = json.loads(path.read_text())
    except (OSError, json.JSONDecodeError) as exc:
        raise UpdateError(f"cannot read event payload {path}: {exc}") from exc
    if not isinstance(data, dict):
        raise UpdateError("event payload must be a JSON object")

    def require_str(key: str) -> str:
        value = data.get(key)
        if not isinstance(value, str) or not value:
            raise UpdateError(f"event payload field '{key}' must be a non-empty string")
        return value

    chart = require_str("chart")
    # The chart name lands in a filesystem path; keep it to a plain directory name.
    if not re.match(r"^[a-z0-9][a-z0-9-]*$", chart):
        raise UpdateError(f"event payload chart '{chart}' is not a plain chart name")
    version = require_str("version")
    # Validated here, at the untrusted boundary, and not only in update_chart:
    # callers echo this value into CI outputs, where a newline would be an
    # injection rather than a bad version number.
    if not VERSION_RE.match(version):
        raise UpdateError(f"event payload version '{version}' is not MAJOR.MINOR.PATCH")
    bump = data.get("bump", "patch")
    if bump not in ("patch", "minor", "major", "none"):
        raise UpdateError(f"event payload bump '{bump}' is not patch|minor|major|none")

    raw_images = data.get("images")
    if not isinstance(raw_images, list) or not raw_images:
        raise UpdateError("event payload field 'images' must be a non-empty list")
    images: dict[str, str] = {}
    for entry in raw_images:
        if not isinstance(entry, dict):
            raise UpdateError("each 'images' entry must be an object")
        repository = entry.get("image")
        digest = entry.get("digest")
        if not isinstance(repository, str) or not repository:
            raise UpdateError("each 'images' entry needs a non-empty 'image'")
        if not isinstance(digest, str) or not DIGEST_RE.match(digest):
            raise UpdateError(
                f"image '{repository}' has an invalid digest "
                f"(expected sha256:<64 lowercase hex>)"
            )
        if repository in images and images[repository] != digest:
            raise UpdateError(f"image '{repository}' appears twice with different digests")
        images[repository] = digest
    return Event(chart=chart, version=version, images=images, bump=bump)


def update_chart(
    chart_dir: Path,
    app_version: str,
    images: dict[str, str],
    bump: str = "patch",
    allow_partial: bool = False,
) -> Result:
    chart_yaml = chart_dir / "Chart.yaml"
    values_yaml = chart_dir / "values.yaml"
    for path in (chart_yaml, values_yaml):
        if not path.is_file():
            raise UpdateError(f"{path} not found")
    if not VERSION_RE.match(app_version):
        raise UpdateError(f"app version '{app_version}' is not MAJOR.MINOR.PATCH")

    values = yaml.safe_load(values_yaml.read_text()) or {}
    blocks = find_image_blocks(values)

    unknown = sorted(set(images) - set(blocks))
    if unknown:
        raise UpdateError(
            f"chart '{chart_dir.name}' has no image block for {unknown}; "
            f"it declares {sorted(blocks)}"
        )

    if not allow_partial:
        expected = {r for r in blocks if r.startswith(FIRST_PARTY_PREFIX)}
        missing = sorted(expected - set(images))
        if missing:
            raise UpdateError(
                f"chart '{chart_dir.name}' also deploys {missing}; a chart's images share one "
                f"appVersion, so pin them all or pass --allow-partial"
            )

    result = Result()
    value_lines = values_yaml.read_text().splitlines(keepends=True)
    for repository in sorted(images):
        changed, previous = set_digest(value_lines, repository, images[repository])
        if changed:
            result.changes.append(
                Change("values.yaml", f"{repository} digest", previous or "(unset)", images[repository])
            )

    chart_lines = chart_yaml.read_text().splitlines(keepends=True)
    app_changed, previous_app = set_scalar(chart_lines, "appVersion", app_version, quote=True)
    if app_changed:
        result.changes.append(Change("Chart.yaml", "appVersion", previous_app, app_version))

    # A replayed release event must not inflate the chart version, so the bump
    # happens only when something else actually moved.
    if result.changed:
        current = str(yaml.safe_load(chart_yaml.read_text())["version"])
        new_version = bump_version(current, bump)
        if new_version != current:
            set_scalar(chart_lines, "version", new_version)
            result.changes.append(Change("Chart.yaml", "version", current, new_version))

    if result.changed:
        values_yaml.write_text("".join(value_lines))
        chart_yaml.write_text("".join(chart_lines))
    return result


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--chart", help="chart directory name under charts/")
    parser.add_argument("--app-version", help="released application version X.Y.Z")
    parser.add_argument(
        "--event-file",
        help="release event JSON (chart/version/images/bump); replaces the flags above",
    )
    parser.add_argument(
        "--image",
        action="append",
        default=[],
        metavar="REPO@DIGEST",
        help="released image, repeatable (e.g. labs64/auditflow@sha256:...)",
    )
    parser.add_argument(
        "--bump",
        choices=("patch", "minor", "major", "none"),
        default="patch",
        help="chart version bump when something changes (default: patch)",
    )
    parser.add_argument(
        "--allow-partial",
        action="store_true",
        help="permit pinning only some of the chart's first-party images",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="report what would change and exit 1 if anything would; write nothing",
    )
    parser.add_argument(
        "--print-event",
        action="store_true",
        help="validate --event-file and print `key=value` lines (for CI step outputs); write nothing",
    )
    parser.add_argument("--charts-dir", default=str(CHARTS_DIR), help=argparse.SUPPRESS)
    args = parser.parse_args()

    if args.print_event:
        if not args.event_file:
            print("update-chart-images: --print-event requires --event-file", file=sys.stderr)
            return 2
        try:
            event = load_event(Path(args.event_file))
        except UpdateError as exc:
            print(f"update-chart-images: {exc}", file=sys.stderr)
            return 2
        # Every field printed here has been format-checked by load_event, so none
        # of them can contain a newline and forge an extra output line.
        print(f"chart={event.chart}")
        print(f"version={event.version}")
        print(f"bump={event.bump}")
        print(f"image-count={len(event.images)}")
        return 0

    try:
        if args.event_file:
            if args.chart or args.app_version or args.image:
                raise UpdateError("--event-file replaces --chart/--app-version/--image")
            event = load_event(Path(args.event_file))
            args.chart, args.app_version, images, args.bump = (
                event.chart,
                event.version,
                event.images,
                event.bump,
            )
        else:
            if not args.chart or not args.app_version:
                raise UpdateError("--chart and --app-version are required without --event-file")
            if not args.image:
                raise UpdateError("at least one --image is required")
            images = dict(parse_image_arg(a) for a in args.image)

        chart_dir = Path(args.charts_dir) / args.chart
        if not chart_dir.is_dir():
            available = sorted(p.name for p in Path(args.charts_dir).iterdir() if p.is_dir())
            raise UpdateError(f"unknown chart '{args.chart}'; available: {available}")

        if args.check:
            # Work on a throwaway copy so --check never mutates the tree.
            import shutil
            import tempfile

            with tempfile.TemporaryDirectory() as tmp:
                copy = Path(tmp) / args.chart
                shutil.copytree(chart_dir, copy)
                result = update_chart(copy, args.app_version, images, args.bump, args.allow_partial)
        else:
            result = update_chart(chart_dir, args.app_version, images, args.bump, args.allow_partial)
    except UpdateError as exc:
        print(f"update-chart-images: {exc}", file=sys.stderr)
        return 2

    if not result.changed:
        print(f"update-chart-images: {args.chart} already at {args.app_version} — nothing to do")
        return 0

    for change in result.changes:
        print(f"  {change.file}: {change.what}: {change.old} -> {change.new}")
    if args.check:
        print(f"update-chart-images: {args.chart} would change ({len(result.changes)} edits)")
        return 1
    print(f"update-chart-images: {args.chart} updated ({len(result.changes)} edits)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

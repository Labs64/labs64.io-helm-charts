#!/usr/bin/env python3
"""Fail when a chart changed without the version bumps that publish it.

chart-releaser runs with `skip_existing: true`: a chart whose `version` already has a
release tag is skipped silently. Three ways a change then never reaches the chart
repository, each checked here against a base ref (the PR base, or origin/master):

  1. A chart's files changed but its `version` did not increase. The generated README.md is
     excluded: a README-only difference (docs regenerated after a bump) needs no republish.
  2. A chart was bumped, but a chart that vendors it through `file://../<chart>` was
     not — above all the `labs64io-ecosystem` umbrella, whose version is the ecosystem
     release number: an unbumped umbrella keeps shipping the old module chart.
  3. A chart pins a local dependency at an exact version that is no longer the
     dependency's version (how module charts reference chart-libs).

`just bump <chart>` (scripts/bump-chart-version.py) performs all of these bumps.

Usage:
    scripts/check-chart-version-bumps.py --base origin/master
    just check-bumps
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parent.parent
LOCAL_REPOSITORY_RE = re.compile(r"^file://\.\./(?P<name>[A-Za-z0-9][A-Za-z0-9-]*)/?$")
EXACT_VERSION_RE = re.compile(r"^\d+\.\d+\.\d+$")


@dataclass
class ChartState:
    new_version: str
    old_version: str | None = None  # None: the chart does not exist on the base ref
    changed: bool = False  # any file under the chart directory differs from the base ref
    local_deps: dict[str, str] = field(default_factory=dict)  # dependency name -> declared version


def version_key(version: str) -> tuple[int, ...]:
    return tuple(int(part) for part in version.split("."))


def increased(state: ChartState) -> bool:
    if state.old_version is None:
        return True
    try:
        return version_key(state.new_version) > version_key(state.old_version)
    except ValueError:
        return state.new_version != state.old_version


def find_problems(charts: dict[str, ChartState]) -> list[str]:
    problems: list[str] = []
    for name, state in sorted(charts.items()):
        if state.changed and not increased(state):
            problems.append(
                f"{name}: changed but version did not increase "
                f"({state.old_version} -> {state.new_version})"
            )
        for dep, declared in sorted(state.local_deps.items()):
            dep_state = charts.get(dep)
            if dep_state is None:
                problems.append(f"{name}: depends on file://../{dep}, which is not a chart here")
                continue
            if EXACT_VERSION_RE.match(declared) and declared != dep_state.new_version:
                problems.append(
                    f"{name}: pins {dep} {declared}, but {dep} is now {dep_state.new_version}"
                )
            bumped = dep_state.old_version is not None and dep_state.new_version != dep_state.old_version
            if bumped and not increased(state):
                problems.append(
                    f"{name}: vendors {dep}, which moved {dep_state.old_version} -> "
                    f"{dep_state.new_version}, but its own version is still {state.new_version}"
                )
    return problems


# --- git plumbing ---------------------------------------------------------------


def _git(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(["git", *args], cwd=REPO_ROOT, capture_output=True, text=True)


def _chart_doc(text: str) -> dict:
    return yaml.safe_load(text) or {}


def _local_deps(doc: dict) -> dict[str, str]:
    found = {}
    for dep in doc.get("dependencies") or []:
        m = LOCAL_REPOSITORY_RE.match(str(dep.get("repository", "")))
        if m:
            found[m.group("name")] = str(dep.get("version", ""))
    return found


def load_charts(base: str, charts_dir: Path) -> dict[str, ChartState]:
    charts: dict[str, ChartState] = {}
    for chart_yaml in sorted(charts_dir.glob("*/Chart.yaml")):
        name = chart_yaml.parent.name
        rel = chart_yaml.parent.relative_to(REPO_ROOT).as_posix()
        doc = _chart_doc(chart_yaml.read_text())
        state = ChartState(new_version=str(doc["version"]), local_deps=_local_deps(doc))
        old = _git("show", f"{base}:{rel}/Chart.yaml")
        if old.returncode == 0:
            state.old_version = str(_chart_doc(old.stdout)["version"])
        # The generated README is not part of what a chart ships to run: it is regenerated from
        # Chart.yaml/values.yaml by helm-docs (chart CI's "Enforce docs generation"), so it can lag
        # a version bump that already happened. Demanding a republish to fix a badge would make
        # that drift impossible to correct — a README-only difference needs no bump.
        state.changed = (
            _git("diff", "--quiet", base, "--", rel, f":(exclude){rel}/README.md").returncode != 0
        )
        charts[name] = state
    return charts


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--base", default="origin/master", help="ref to compare against")
    args = parser.parse_args()

    if _git("rev-parse", "--verify", "--quiet", args.base).returncode != 0:
        print(f"check-chart-version-bumps: base ref '{args.base}' not found", file=sys.stderr)
        return 2

    charts = load_charts(args.base, REPO_ROOT / "charts")
    for name, state in sorted(charts.items()):
        if state.old_version is None:
            print(f"  new   {name} ({state.new_version})")
        elif state.new_version != state.old_version:
            print(f"  bump  {name} {state.old_version} -> {state.new_version}")

    problems = find_problems(charts)
    if problems:
        prefix = "::error::" if os.environ.get("GITHUB_ACTIONS") else "  FAIL  "
        print()
        for problem in problems:
            print(f"{prefix}{problem}")
        print(
            "\nBump with `just bump <chart>` — it also moves every chart that vendors it "
            "(chart-libs consumers, the labs64io-ecosystem umbrella)."
        )
        return 1
    print(f"\ncheck-chart-version-bumps: clean against {args.base}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Fail when a packaged chart is not self-contained.

`helm package` does not vendor a chart's dependencies unless they are present under
`charts/` when it runs. The module charts depend on `chart-libs` through
`file://../chart-libs`, and `charts/*/charts/` is gitignored, so on a fresh checkout
only the charts that were themselves packaged (by chart-releaser: the ones that
changed) have it. The umbrella then ships the unchanged module charts *without*
`chart-libs`, and installing it fails at render time with
`no template "chart-libs.<name>" associated with template "gotpl"`.

This checks the finished tarball, at every nesting level: every dependency a bundled
chart's Chart.yaml declares must be present beneath that chart's own `charts/`
(as a directory or as a packaged `<name>-<version>.tgz`).

Usage:
    helm package charts/labs64io-ecosystem -u -d /tmp/pkg
    scripts/check-packaged-chart.py /tmp/pkg/labs64io-ecosystem-*.tgz
    just check-package
"""

from __future__ import annotations

import argparse
import sys
import tarfile
from pathlib import PurePosixPath

import yaml


def find_missing(files: dict[str, str]) -> list[str]:
    """Problems for a packaged chart, given {member path: Chart.yaml text or ""}.

    `files` holds every regular file in the tarball; only Chart.yaml bodies are read.
    """
    paths = set(files)
    problems: list[str] = []
    for path, body in sorted(files.items()):
        if PurePosixPath(path).name != "Chart.yaml":
            continue
        root = PurePosixPath(path).parent
        chart = yaml.safe_load(body) or {}
        for dep in chart.get("dependencies") or []:
            name = dep["name"]
            vendored_dir = f"{root}/charts/{name}/Chart.yaml"
            vendored_tgz = any(
                p.startswith(f"{root}/charts/{name}-") and p.endswith(".tgz") for p in paths
            )
            if vendored_dir not in paths and not vendored_tgz:
                problems.append(
                    f"{root}: dependency '{name}' ({dep.get('repository', 'no repository')}) "
                    f"is not vendored under {root}/charts/"
                )
    return problems


def read_package(path: str) -> dict[str, str]:
    files: dict[str, str] = {}
    with tarfile.open(path, "r:gz") as tar:
        for member in tar:
            if not member.isfile():
                continue
            name = member.name
            body = ""
            if PurePosixPath(name).name == "Chart.yaml":
                extracted = tar.extractfile(member)
                body = extracted.read().decode("utf-8") if extracted else ""
            files[name] = body
    return files


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("packages", nargs="+", help="packaged chart tarball(s) (.tgz)")
    args = parser.parse_args()

    failed = False
    for package in args.packages:
        problems = find_missing(read_package(package))
        if problems:
            failed = True
            print(f"FAIL {package}", file=sys.stderr)
            for problem in problems:
                print(f"  - {problem}", file=sys.stderr)
        else:
            print(f"ok   {package}")
    if failed:
        print(
            "\nBuild every chart's dependencies before packaging "
            "(`helm dependency build charts/<chart>` for each chart, umbrella last).",
            file=sys.stderr,
        )
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

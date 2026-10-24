"""scripts/build-chart-dependencies.sh: every chart's dependencies are built, the umbrella last, from one place.

The umbrella vendors the module charts by packaging them as they are on disk when its own dependencies are built, so
building it before a module chart (an alphabetical loop does that for payment-gateway) ships that module without its
`chart-libs`. A fake `helm` records the order; a second test fails if another copy of the loop appears in a workflow or
the justfile, which is how the lint workflow once drifted from the release workflow.

Run: pytest scripts/test_build_chart_dependencies.py -q
"""

from __future__ import annotations

import os
import re
import shutil
import stat
import subprocess
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[1]
SCRIPT = REPO / "scripts" / "build-chart-dependencies.sh"
UMBRELLA = "labs64io-ecosystem"

pytestmark = pytest.mark.skipif(shutil.which("bash") is None, reason="needs bash")


def make_repo(root: Path, charts: list[str], plain_dirs: tuple[str, ...] = ("notachart",)) -> Path:
    (root / "scripts").mkdir(parents=True)
    shutil.copy(SCRIPT, root / "scripts" / SCRIPT.name)
    for name in charts:
        (root / "charts" / name).mkdir(parents=True)
        (root / "charts" / name / "Chart.yaml").write_text(f"name: {name}\nversion: 0.1.0\n")
    for name in plain_dirs:
        (root / "charts" / name).mkdir(parents=True)  # no Chart.yaml: not a chart
    return root


def fake_helm(bin_dir: Path, log: Path, fail_on: str | None = None) -> None:
    bin_dir.mkdir()
    helm = bin_dir / "helm"
    fail = f'[[ "$3" == *"{fail_on}" ]] && exit 1' if fail_on else ""
    helm.write_text(f'#!/usr/bin/env bash\necho "$1 $2 $3" >> "{log}"\n{fail}\nexit 0\n')
    helm.chmod(helm.stat().st_mode | stat.S_IEXEC)


def run(root: Path, bin_dir: Path, cwd: Path | None = None) -> subprocess.CompletedProcess:
    env = {**os.environ, "PATH": f"{bin_dir}:{os.environ['PATH']}"}
    return subprocess.run(["bash", str(root / "scripts" / SCRIPT.name)], cwd=cwd or root, env=env, capture_output=True, text=True)


def built(log: Path) -> list[str]:
    return [line.split()[2] for line in log.read_text().splitlines()]


def test_the_umbrella_is_built_after_every_other_chart_whatever_the_alphabet_says(tmp_path):
    # alphabetical order puts the umbrella before payment-gateway and zeta: the bug
    charts = ["api-docs", "auditflow", "chart-libs", UMBRELLA, "payment-gateway", "zeta"]
    root, log = make_repo(tmp_path / "repo", charts), tmp_path / "helm.log"
    fake_helm(tmp_path / "bin", log)
    result = run(root, tmp_path / "bin")
    assert result.returncode == 0, result.stderr
    order = built(log)
    assert order[-1] == f"charts/{UMBRELLA}", order
    assert sorted(order[:-1]) == sorted(f"charts/{c}" for c in charts if c != UMBRELLA)
    assert all(call.startswith("dependency build") for call in log.read_text().splitlines())


def test_a_directory_without_a_chart_yaml_is_skipped(tmp_path):
    root, log = make_repo(tmp_path / "repo", ["a", UMBRELLA]), tmp_path / "helm.log"
    fake_helm(tmp_path / "bin", log)
    run(root, tmp_path / "bin")
    assert "charts/notachart" not in built(log)


def test_it_runs_from_any_directory(tmp_path):
    root, log = make_repo(tmp_path / "repo", ["a", UMBRELLA]), tmp_path / "helm.log"
    fake_helm(tmp_path / "bin", log)
    elsewhere = tmp_path / "elsewhere"
    elsewhere.mkdir()
    assert run(root, tmp_path / "bin", cwd=elsewhere).returncode == 0
    assert built(log) == ["charts/a", f"charts/{UMBRELLA}"]


def test_a_failed_build_stops_before_the_umbrella_is_built_from_a_broken_module(tmp_path):
    root, log = make_repo(tmp_path / "repo", ["a", "b", UMBRELLA]), tmp_path / "helm.log"
    fake_helm(tmp_path / "bin", log, fail_on="charts/b")
    result = run(root, tmp_path / "bin")
    assert result.returncode != 0
    assert f"charts/{UMBRELLA}" not in built(log)


def test_this_script_is_the_only_place_that_builds_chart_dependencies():
    """A loop of its own in a workflow or the justfile is how the lint run drifted from the release (PR #73)."""
    offenders = []
    for path in [*justfiles(), *sorted((REPO / ".github" / "workflows").glob("*.yml"))]:
        for number, line in enumerate(path.read_text().splitlines(), 1):
            if re.search(r"helm\s+dependency\s+build", line) and not line.lstrip().startswith("#"):
                offenders.append(f"{path.relative_to(REPO)}:{number}: {line.strip()}")
    assert not offenders, "call scripts/build-chart-dependencies.sh instead:\n" + "\n".join(offenders)


def justfiles():
    """The justfile and the group files it imports (just/*.just)."""
    return [REPO / "justfile", *sorted((REPO / "just").glob("*.just"))]


def test_every_caller_runs_the_script():
    # The release workflow calls the script itself; the recipes call it (_build-chart-dependencies), and the lint
    # workflow runs those recipes rather than a copy of their commands.
    release = (REPO / ".github/workflows/labs64io-release-charts.yml").read_text()
    assert "scripts/build-chart-dependencies.sh" in release
    assert "scripts/build-chart-dependencies.sh" in "\n".join(p.read_text() for p in justfiles())
    lint = (REPO / ".github/workflows/labs64io-lint-charts.yml").read_text()
    assert "just check-package" in lint and "just lint-charts" in lint

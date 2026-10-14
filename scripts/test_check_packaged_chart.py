"""Tests for the packaged-chart self-containment gate.

Pure rule tests on synthetic tarball contents. They pin the failure that shipped in
every umbrella release from 0.20.17 on: module charts bundled without `chart-libs`.
A gate that stops flagging that reports green forever.

Run: pytest scripts/test_check_packaged_chart.py -q
"""

from __future__ import annotations

import importlib.util
import io
import sys
import tarfile
from pathlib import Path

SCRIPT = Path(__file__).parent / "check-packaged-chart.py"
_spec = importlib.util.spec_from_file_location("check_packaged_chart", SCRIPT)
chk = importlib.util.module_from_spec(_spec)
sys.modules["check_packaged_chart"] = chk
_spec.loader.exec_module(chk)

LIBS_DEP = "dependencies:\n  - name: chart-libs\n    version: 0.8.7\n    repository: file://../chart-libs\n"
UMBRELLA_DEPS = (
    "dependencies:\n"
    "  - name: auditflow\n    version: '>=0.1.0'\n    repository: file://../auditflow\n"
    "  - name: valkey\n    alias: redis\n    version: 6.3.4\n    repository: https://charts.bitnami.com/bitnami\n"
)


def umbrella() -> dict[str, str]:
    return {
        "eco/Chart.yaml": UMBRELLA_DEPS,
        "eco/charts/auditflow/Chart.yaml": LIBS_DEP,
        "eco/charts/auditflow/charts/chart-libs/Chart.yaml": "name: chart-libs\n",
        "eco/charts/valkey/Chart.yaml": "name: valkey\n",
    }


def test_self_contained_package_is_clean():
    assert chk.find_missing(umbrella()) == []


def test_module_chart_without_chart_libs_is_flagged():
    files = umbrella()
    del files["eco/charts/auditflow/charts/chart-libs/Chart.yaml"]
    problems = chk.find_missing(files)
    assert len(problems) == 1
    assert "eco/charts/auditflow" in problems[0] and "chart-libs" in problems[0]


def test_missing_remote_dependency_is_flagged():
    files = umbrella()
    del files["eco/charts/valkey/Chart.yaml"]
    problems = chk.find_missing(files)
    assert len(problems) == 1 and "valkey" in problems[0]


def test_alias_resolves_by_chart_name():
    # Helm vendors an aliased dependency under its chart name, not the alias.
    assert chk.find_missing(umbrella()) == []


def test_packed_tgz_dependency_counts():
    files = umbrella()
    del files["eco/charts/auditflow/charts/chart-libs/Chart.yaml"]
    files["eco/charts/auditflow/charts/chart-libs-0.8.7.tgz"] = ""
    assert chk.find_missing(files) == []


def test_chart_without_dependencies_is_clean():
    assert chk.find_missing({"solo/Chart.yaml": "name: solo\n"}) == []


def test_read_package_round_trip(tmp_path):
    pkg = tmp_path / "eco-1.0.0.tgz"
    with tarfile.open(pkg, "w:gz") as tar:
        for name, body in umbrella().items():
            data = body.encode()
            info = tarfile.TarInfo(name)
            info.size = len(data)
            tar.addfile(info, io.BytesIO(data))
    assert chk.find_missing(chk.read_package(str(pkg))) == []

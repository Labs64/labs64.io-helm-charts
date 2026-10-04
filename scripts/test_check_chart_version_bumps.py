"""Tests for the chart version-bump gate.

Pure rule tests on synthetic chart states — no git, no real charts. They pin what
counts as "must be bumped", which is the part that silently rots: a gate that stops
flagging an unbumped umbrella reports green forever.

Run: pytest scripts/test_check_chart_version_bumps.py -q
"""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

SCRIPT = Path(__file__).parent / "check-chart-version-bumps.py"
_spec = importlib.util.spec_from_file_location("check_chart_version_bumps", SCRIPT)
chk = importlib.util.module_from_spec(_spec)
sys.modules["check_chart_version_bumps"] = chk
_spec.loader.exec_module(chk)

S = chk.ChartState


def fleet(**overrides) -> dict:
    charts = {
        "chart-libs": S(new_version="0.8.4", old_version="0.8.4"),
        "auditflow": S(new_version="0.15.6", old_version="0.15.6", local_deps={"chart-libs": "0.8.4"}),
        "labs64io-ecosystem": S(
            new_version="0.20.5", old_version="0.20.5", local_deps={"auditflow": ">=0.1.0"}
        ),
    }
    charts.update(overrides)
    return charts


def test_untouched_fleet_is_clean():
    assert chk.find_problems(fleet()) == []


def test_changed_chart_without_bump_is_flagged():
    charts = fleet(auditflow=S("0.15.6", "0.15.6", changed=True, local_deps={"chart-libs": "0.8.4"}))
    assert any("auditflow: changed but version did not increase" in p for p in chk.find_problems(charts))


def test_version_going_backwards_is_flagged():
    charts = fleet(auditflow=S("0.15.5", "0.15.6", changed=True, local_deps={"chart-libs": "0.8.4"}))
    assert any("did not increase" in p for p in chk.find_problems(charts))


def test_versions_compare_numerically_not_lexically():
    charts = fleet(
        auditflow=S("0.15.10", "0.15.9", changed=True, local_deps={"chart-libs": "0.8.4"}),
        **{"labs64io-ecosystem": S("0.20.6", "0.20.5", changed=True, local_deps={"auditflow": ">=0.1.0"})},
    )
    assert chk.find_problems(charts) == []


def test_bumped_module_chart_requires_an_umbrella_bump():
    charts = fleet(auditflow=S("0.15.7", "0.15.6", changed=True, local_deps={"chart-libs": "0.8.4"}))
    problems = chk.find_problems(charts)
    assert problems == [
        "labs64io-ecosystem: vendors auditflow, which moved 0.15.6 -> 0.15.7, "
        "but its own version is still 0.20.5"
    ]


def test_bumped_module_chart_with_bumped_umbrella_is_clean():
    charts = fleet(
        auditflow=S("0.15.7", "0.15.6", changed=True, local_deps={"chart-libs": "0.8.4"}),
        **{"labs64io-ecosystem": S("0.20.6", "0.20.5", changed=True, local_deps={"auditflow": ">=0.1.0"})},
    )
    assert chk.find_problems(charts) == []


def test_library_bump_requires_pin_move_and_consumer_bump():
    charts = fleet(**{"chart-libs": S("0.8.5", "0.8.4", changed=True)})
    problems = chk.find_problems(charts)
    assert "auditflow: pins chart-libs 0.8.4, but chart-libs is now 0.8.5" in problems
    assert any(p.startswith("auditflow: vendors chart-libs") for p in problems)


def test_full_library_cascade_is_clean():
    charts = {
        "chart-libs": S("0.8.5", "0.8.4", changed=True),
        "auditflow": S("0.15.7", "0.15.6", changed=True, local_deps={"chart-libs": "0.8.5"}),
        "labs64io-ecosystem": S("0.20.6", "0.20.5", changed=True, local_deps={"auditflow": ">=0.1.0"}),
    }
    assert chk.find_problems(charts) == []


def test_new_chart_needs_no_bump():
    charts = fleet(preflight=S("0.1.0", None, changed=True))
    assert chk.find_problems(charts) == []


def test_dependency_on_a_missing_chart_is_flagged():
    charts = fleet(auditflow=S("0.15.6", "0.15.6", local_deps={"ghost": "1.0.0"}))
    assert any("file://../ghost, which is not a chart here" in p for p in chk.find_problems(charts))

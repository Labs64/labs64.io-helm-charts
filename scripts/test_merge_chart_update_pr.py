"""Tests for the chart-update PR merger.

decide() is a pure function over the JSON `gh pr list` returns, so every rule that keeps a PR
from merging is pinned here without GitHub. The last tests keep the names this depends on in
step with the workflow files: a renamed workflow would otherwise make the gate wait forever.

Run: pytest scripts/test_merge_chart_update_pr.py -q
"""

from __future__ import annotations

import importlib.util
import subprocess
import sys
from pathlib import Path

import pytest
import yaml

SCRIPT = Path(__file__).parent / "merge-chart-update-pr.py"
_spec = importlib.util.spec_from_file_location("merge_chart_update_pr", SCRIPT)
mrg = importlib.util.module_from_spec(_spec)
sys.modules["merge_chart_update_pr"] = mrg
_spec.loader.exec_module(mrg)

WORKFLOWS = Path(__file__).resolve().parent.parent / ".github" / "workflows"
SHA = "a" * 40
LINT, E2E = mrg.REQUIRED_WORKFLOWS

not_stale = lambda base, oid: False  # noqa: E731
stale = lambda base, oid: True  # noqa: E731


def report(workflow, name, conclusion="SUCCESS"):
    return {"workflowName": workflow, "name": name, "conclusion": conclusion, "status": "COMPLETED"}


def pr(**overrides):
    base = {
        "number": 95,
        "headRefName": "chart-update/checkout-0.0.9",
        "headRefOid": SHA,
        "labels": [{"name": "chart-update"}, {"name": "automated"}],
        "isDraft": False,
        "isCrossRepository": False,
        "mergeable": "MERGEABLE",
        "statusCheckRollup": [
            report("CodeQL", "Analyze (actions)"),
            report(LINT, "lint"),
            report(E2E, "e2e"),
        ],
    }
    base.update(overrides)
    return base


def decide(p, sha=SHA, stale_fn=not_stale):
    return mrg.decide(p, sha, "origin/master", stale_fn)


def test_merges_when_both_chart_workflows_passed_on_the_current_head():
    ok, why = decide(pr())
    assert ok, why


@pytest.mark.parametrize(
    "overrides, reason",
    [
        ({"isCrossRepository": True}, "fork"),
        ({"headRefName": "renovate/helm"}, "branch"),
        ({"labels": [{"name": "automated"}]}, "label"),
        ({"isDraft": True}, "draft"),
        ({"mergeable": "CONFLICTING"}, "conflicts"),
    ],
)
def test_never_merges_what_it_did_not_create_or_cannot_merge(overrides, reason):
    ok, why = decide(pr(**overrides))
    assert not ok and reason in why


def test_a_run_for_an_older_head_decides_nothing():
    # The PR was rebuilt or pushed to after the run started: the new head has its own runs.
    ok, why = decide(pr(headRefOid="b" * 40))
    assert not ok and "older head" in why


@pytest.mark.parametrize("missing", [LINT, E2E])
def test_waits_for_a_workflow_that_has_not_reported(missing):
    rollup = [r for r in pr()["statusCheckRollup"] if r["workflowName"] != missing]
    ok, why = decide(pr(statusCheckRollup=rollup))
    assert not ok and missing in why


@pytest.mark.parametrize("conclusion", ["FAILURE", "CANCELLED", "SKIPPED", "", None])
def test_anything_but_success_is_not_a_pass(conclusion):
    # A skipped or still-running gate has not found anything out. An empty conclusion is a run in progress.
    rollup = [report(LINT, "lint"), report(E2E, "e2e", conclusion)]
    ok, why = decide(pr(statusCheckRollup=rollup))
    assert not ok and "e2e" in why


def test_one_failing_report_among_passing_ones_blocks():
    rollup = [report(LINT, "lint"), report(E2E, "e2e"), report(E2E, "e2e", "FAILURE")]
    assert not decide(pr(statusCheckRollup=rollup))[0]


def test_other_workflows_failing_do_not_block():
    # CodeQL and friends are not this gate's business.
    rollup = pr()["statusCheckRollup"] + [report("CodeQL", "Analyze (python)", "FAILURE")]
    assert decide(pr(statusCheckRollup=rollup))[0]


def test_a_stale_pr_waits_for_the_refresh_job_even_when_green():
    # The race the staleness rule exists for: green on an old base, master has since taken the umbrella version.
    ok, why = decide(pr(), stale_fn=stale)
    assert not ok and "refresh" in why


# --- the names this depends on ----------------------------------------------------------------


def workflow_name(path: Path) -> str:
    return yaml.safe_load(path.read_text())["name"]


def test_required_workflows_are_workflows_of_this_repository():
    names = {workflow_name(p) for p in WORKFLOWS.glob("*.yml")}
    assert set(mrg.REQUIRED_WORKFLOWS) <= names


def test_the_merge_workflow_wakes_up_on_exactly_the_required_workflows():
    wf = yaml.safe_load((WORKFLOWS / "labs64io-chart-update-merge.yml").read_text())
    triggers = wf.get("on", wf.get(True))
    assert sorted(triggers["workflow_run"]["workflows"]) == sorted(mrg.REQUIRED_WORKFLOWS)


def test_the_required_workflows_run_on_every_chart_update_pr():
    # A required workflow that does not run for a chart-update PR would make the gate wait forever.
    # Every such PR changes charts/** (the module chart and the umbrella).
    for name in ("labs64io-lint-charts.yml", "labs64io-published-chart-e2e.yml"):
        wf = yaml.safe_load((WORKFLOWS / name).read_text())
        paths = (wf.get("on", wf.get(True)))["pull_request"]["paths"]
        assert "charts/**" in paths, name


def test_merge_never_checks_out_pull_request_code():
    # It runs from the default branch with a write token; a ref: here would run the PR's own scripts with it.
    text = (WORKFLOWS / "labs64io-chart-update-merge.yml").read_text()
    wf = yaml.safe_load(text)
    for step in wf["jobs"]["merge"]["steps"]:
        if str(step.get("uses", "")).startswith("actions/checkout"):
            assert "ref" not in step.get("with", {})


def test_dry_run_decides_without_merging(monkeypatch, capsys):
    monkeypatch.setattr(mrg, "find_pr", lambda branch: pr())
    monkeypatch.setattr(mrg.refresh, "is_stale", not_stale)
    monkeypatch.setattr(mrg, "decide", lambda p, sha, base: (True, "ok"))
    called = []
    monkeypatch.setattr(subprocess, "run", lambda *a, **k: called.append(a))
    monkeypatch.setattr(sys, "argv", ["x", "--branch", "chart-update/checkout-0.0.9", "--sha", SHA, "--dry-run"])
    assert mrg.main() == 0
    assert called == []
    assert "merge" in capsys.readouterr().out


def test_merge_pins_the_head_and_tolerates_losing_the_race(monkeypatch, capsys):
    monkeypatch.setattr(mrg, "find_pr", lambda branch: pr())
    monkeypatch.setattr(mrg, "decide", lambda p, sha, base: (True, "ok"))
    calls = []

    def fake_run(cmd, **kwargs):
        calls.append(cmd)
        return subprocess.CompletedProcess(cmd, 1, stdout="", stderr="Pull request #95 was already merged")

    monkeypatch.setattr(mrg.subprocess, "run", fake_run)
    monkeypatch.setattr(sys, "argv", ["x", "--branch", "chart-update/checkout-0.0.9", "--sha", SHA])
    assert mrg.main() == 0
    assert calls[0][:3] == ["gh", "pr", "merge"]
    assert "--match-head-commit" in calls[0] and SHA in calls[0] and "--squash" in calls[0]


def test_an_unexpected_merge_failure_is_not_swallowed(monkeypatch):
    monkeypatch.setattr(mrg, "find_pr", lambda branch: pr())
    monkeypatch.setattr(mrg, "decide", lambda p, sha, base: (True, "ok"))
    monkeypatch.setattr(
        mrg.subprocess, "run",
        lambda cmd, **k: subprocess.CompletedProcess(cmd, 1, stdout="", stderr="Pull request is not mergeable: branch protection"),
    )  # fmt: skip
    monkeypatch.setattr(sys, "argv", ["x", "--branch", "chart-update/checkout-0.0.9", "--sha", SHA])
    assert mrg.main() == 1

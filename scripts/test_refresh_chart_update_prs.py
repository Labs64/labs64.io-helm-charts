"""Tests for the chart-update PR refresher.

The staleness rule runs against real throwaway git repositories (the rule IS git's view
of two branches); everything that talks to GitHub is a plain function over the JSON `gh`
returns, so it is tested without a network.

Run: pytest scripts/test_refresh_chart_update_prs.py -q
"""

from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
from pathlib import Path

import pytest

SCRIPT = Path(__file__).parent / "refresh-chart-update-prs.py"
_spec = importlib.util.spec_from_file_location("refresh_chart_update_prs", SCRIPT)
ref = importlib.util.module_from_spec(_spec)
sys.modules["refresh_chart_update_prs"] = ref
_spec.loader.exec_module(ref)

D1 = "sha256:" + "1" * 64
D2 = "sha256:" + "2" * 64


def event(chart="checkout", version="0.0.9", bump="patch", images=None):
    return ref.upd.Event(
        chart=chart, version=version, bump=bump, images=images or {"labs64/checkout": D1, "labs64/checkout-ui": D2}
    )


# --- the recorded event ---------------------------------------------------------------


def test_marker_round_trips_through_a_pr_body():
    e = event()
    body = f"Automated chart update.\n\n{ref.render_marker(e)}\n"
    assert ref.parse_marker(body) == e


def test_marker_is_one_line_and_cannot_end_the_comment_early():
    # The image repository is the only free-form field; this is what an attacker-shaped one looks like.
    e = event(images={"labs64/x--><script>": D1})
    marker = ref.render_marker(e)
    assert "\n" not in marker
    assert marker.count("-->") == 1 and marker.endswith("-->")
    assert ref.parse_marker(marker) == e


def test_no_marker_is_none_not_an_error():
    assert ref.parse_marker("Automated chart update.") is None
    assert ref.parse_marker(None) is None


@pytest.mark.parametrize(
    "payload",
    [
        {"chart": "../etc", "version": "1.0.0", "images": [{"image": "a/b", "digest": D1}]},
        {"chart": "checkout", "version": "1.0", "images": [{"image": "a/b", "digest": D1}]},
        {"chart": "checkout", "version": "1.0.0", "images": [{"image": "a/b", "digest": "sha256:short"}]},
        {"chart": "checkout", "version": "1.0.0", "bump": "huge", "images": [{"image": "a/b", "digest": D1}]},
        {"chart": "checkout", "version": "1.0.0", "images": []},
    ],
)
def test_an_edited_marker_is_validated_like_a_release_event(payload):
    with pytest.raises(ref.UpdateError):
        ref.parse_marker(f"<!-- chart-update-event: {json.dumps(payload)} -->")


def test_a_marker_that_is_not_json_is_an_error():
    with pytest.raises(ref.UpdateError):
        ref.parse_marker("<!-- chart-update-event: {not json} -->")


# --- staleness, against real git ------------------------------------------------------


def run(repo: Path, *args: str) -> str:
    return subprocess.run(
        ["git", "-C", str(repo), "-c", "user.name=t", "-c", "user.email=t@t", *args],
        check=True, capture_output=True, text=True,
    ).stdout  # fmt: skip


def commit(repo: Path, files: dict[str, str], message: str) -> str:
    for name, text in files.items():
        path = repo / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
    run(repo, "add", "-A")
    run(repo, "commit", "-q", "-m", message)
    return run(repo, "rev-parse", "HEAD").strip()


@pytest.fixture
def repo(tmp_path) -> Path:
    r = tmp_path / "repo"
    r.mkdir()
    run(r, "init", "-q", "-b", "master")
    commit(r, {"charts/labs64io-ecosystem/Chart.yaml": "version: 0.20.53\n", "charts/checkout/Chart.yaml": "version: 1\n"}, "base")
    return r


def stale(repo: Path, head: str) -> bool:
    return ref.is_stale("master", head, git_fn=lambda *a: run(repo, *a))


def pr_branch(repo: Path, name: str, files: dict[str, str]) -> str:
    run(repo, "switch", "-q", "-c", name, "master")
    head = commit(repo, files, name)
    run(repo, "switch", "-q", "master")
    return head


def test_a_pr_on_the_current_master_is_not_stale(repo):
    head = pr_branch(repo, "chart-update/checkout-0.0.9", {"charts/labs64io-ecosystem/Chart.yaml": "version: 0.20.54\n"})
    assert stale(repo, head) is False


def test_another_pr_rewriting_the_umbrella_makes_it_stale(repo):
    # The case this exists for: both PRs bump the umbrella to 0.20.54 — the merge is clean and wrong.
    head = pr_branch(repo, "chart-update/checkout-0.0.9", {"charts/labs64io-ecosystem/Chart.yaml": "version: 0.20.54\n"})
    commit(repo, {"charts/labs64io-ecosystem/Chart.yaml": "version: 0.20.54\n"}, "other PR merged")
    assert stale(repo, head) is True


def test_master_moving_in_unrelated_files_does_not_make_it_stale(repo):
    head = pr_branch(repo, "chart-update/checkout-0.0.9", {"charts/labs64io-ecosystem/Chart.yaml": "version: 0.20.54\n"})
    commit(repo, {"docs/readme.md": "x\n"}, "docs only")
    assert stale(repo, head) is False


# --- plan and dispatch ---------------------------------------------------------------------


def pr(number, branch="chart-update/checkout-0.0.9", body=None, cross=False, oid="a" * 40):
    return {
        "number": number,
        "headRefName": branch,
        "headRefOid": oid,
        "body": ref.render_marker(event()) if body is None else body,
        "isCrossRepository": cross,
    }


def actions(items):
    return {it.number: it.action for it in items}


def test_plan_refreshes_only_stale_prs_in_number_order():
    seen = []

    def stale_fn(base, oid):
        seen.append(oid)
        return oid.startswith("b")

    items = ref.plan([pr(96, oid="b" * 40), pr(95, oid="a" * 40), pr(97, oid="b" * 40)], "origin/master", stale_fn)
    assert [it.number for it in items] == [95, 96, 97]
    assert actions(items) == {95: "current", 96: "refresh", 97: "refresh"}


def test_plan_never_touches_what_it_did_not_create():
    always = lambda base, oid: True  # noqa: E731
    items = ref.plan(
        [
            pr(1, cross=True),
            pr(2, branch="renovate/helm"),
            pr(3, body="no marker here"),
            pr(4, body='<!-- chart-update-event: {"chart":"../x","version":"1.0.0","images":[]} -->'),
        ],
        "origin/master",
        always,
    )
    assert actions(items) == {1: "skip", 2: "skip", 3: "skip", 4: "skip"}
    assert "replay" in items[2].reason


def test_dispatch_command_replays_the_recorded_event():
    cmd = ref.dispatch_command(event(bump="minor"), "master")
    assert cmd[:6] == ["gh", "workflow", "run", "labs64io-chart-image-update.yml", "--ref", "master"]
    fields = dict(a.split("=", 1) for a in cmd if "=" in a and not a.startswith("--"))
    assert fields["chart"] == "checkout" and fields["version"] == "0.0.9" and fields["bump"] == "minor"
    # One image per line, as the workflow_dispatch input documents.
    assert fields["images"].splitlines() == [f"labs64/checkout@{D1}", f"labs64/checkout-ui@{D2}"]


def test_refresh_dry_run_dispatches_nothing(monkeypatch, capsys):
    monkeypatch.setattr(ref, "list_prs", lambda: [])
    monkeypatch.setattr(ref, "plan", lambda prs, base: [ref.Item(96, "chart-update/checkout-0.0.9", "refresh", "r", event())])
    called = []
    monkeypatch.setattr(ref.subprocess, "run", lambda *a, **k: called.append(a))
    args = ref.argparse.Namespace(base="origin/master", ref="master", dry_run=True)
    assert ref.cmd_refresh(args) == 0
    assert called == []
    assert "would regenerate" in capsys.readouterr().out


def test_refresh_dispatches_each_stale_pr(monkeypatch):
    monkeypatch.setattr(ref, "list_prs", lambda: [])
    monkeypatch.setattr(
        ref, "plan",
        lambda prs, base: [ref.Item(96, "b", "refresh", "r", event()), ref.Item(97, "c", "current", "r", event())],
    )  # fmt: skip
    called = []
    monkeypatch.setattr(ref.subprocess, "run", lambda cmd, **k: called.append(cmd))
    args = ref.argparse.Namespace(base="origin/master", ref="master", dry_run=False)
    ref.cmd_refresh(args)
    assert len(called) == 1 and called[0][:3] == ["gh", "workflow", "run"]

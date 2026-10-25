#!/usr/bin/env python3
"""Keep open chart-update PRs built on the current master.

Every chart-update PR (labs64io-chart-image-update.yml) is pure generator output:
a module's image digests, its chart version, and the bump of the `labs64io-ecosystem`
umbrella that vendors it. Two modules released together each branch from the same
master and each rewrite the same umbrella lines (version, README badge, Chart.lock).
The first PR merges cleanly; the second conflicts — or worse, merges cleanly with the
SAME umbrella version, which chart-releaser then skips (`skip_existing`), so its
module chart reaches no cluster.

A conflict in generated output is never resolved by hand. The PR records the release
event that produced it as a hidden comment in its body; when master moves under it,
the updater is run again for that event on top of the new master. Its branch name is
stable, so the existing PR is updated in place, and the updater is idempotent, so
nothing is bumped twice.

    scripts/refresh-chart-update-prs.py marker event.json
        Validate a release event (the same checks the updater applies) and print
        `marker=<!-- chart-update-event: {...} -->`, for a CI step output.

    scripts/refresh-chart-update-prs.py refresh [--dry-run]
        For every open, same-repository PR labelled `chart-update` whose branch
        overlaps what master changed since it branched, dispatch the updater with the
        event recorded in its body. Needs `gh` and a checkout with full history.

A PR without a recorded event (opened before this existed) is reported, not touched:
replay it with `just update-chart-images` or the updater's workflow_dispatch.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
import re
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

HERE = Path(__file__).resolve().parent

# The updater owns what a release event is and how it is validated; reuse it so the
# two cannot drift. (Loaded by path: its file name has a hyphen.)
upd = sys.modules.get("update_chart_images")
if upd is None:
    _spec = importlib.util.spec_from_file_location("update_chart_images", HERE / "update-chart-images.py")
    upd = importlib.util.module_from_spec(_spec)
    sys.modules["update_chart_images"] = upd
    _spec.loader.exec_module(upd)

UpdateError = upd.UpdateError

UPDATER_WORKFLOW = "labs64io-chart-image-update.yml"
PR_LABEL = "chart-update"
BRANCH_PREFIX = "chart-update/"
MARKER_RE = re.compile(r"<!-- chart-update-event: (\{[^\n]*?\}) -->")


# --- the event recorded in a PR body ---------------------------------------------


def render_marker(event) -> str:
    """The event as a single-line HTML comment for the PR body.

    `<` and `>` are escaped inside the JSON so that no field (the image repository is
    the only free-form one) can end the comment early; json.loads reads them back.
    """
    payload = {
        "chart": event.chart,
        "version": event.version,
        "bump": event.bump,
        "images": [{"image": image, "digest": digest} for image, digest in sorted(event.images.items())],
    }
    text = json.dumps(payload, separators=(",", ":")).replace("<", "\\u003c").replace(">", "\\u003e")
    return f"<!-- chart-update-event: {text} -->"


def parse_marker(body: str | None):
    """The Event recorded in a PR body, None if there is none.

    The body is editable by anyone who can write to the PR, so the payload goes through
    the updater's own validation (load_event) and is later handed to a workflow input,
    never to a shell. A marker that is present but invalid raises UpdateError.
    """
    match = MARKER_RE.search(body or "")
    if not match:
        return None
    try:
        data = json.loads(match.group(1))
    except json.JSONDecodeError as exc:
        raise UpdateError(f"recorded event is not valid JSON: {exc}") from exc
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "event.json"
        path.write_text(json.dumps(data))
        return upd.load_event(path)


# --- is a PR stale? -----------------------------------------------------------------


def git(*args: str) -> str:
    return subprocess.run(["git", *args], check=True, capture_output=True, text=True).stdout


def is_stale(base_ref: str, head_sha: str, git_fn: Callable[..., str] = git) -> bool:
    """True when master changed a file this PR also changes since the PR branched.

    Overlap, not mere divergence: a PR that is behind master but shares no file with
    what landed is fine as it is, while two PRs that both rewrite the umbrella's
    version never need a textual conflict to be wrong.
    """
    base = git_fn("rev-parse", base_ref).strip()
    merge_base = git_fn("merge-base", base, head_sha).strip()
    if merge_base == base:
        return False
    on_base = set(git_fn("diff", "--name-only", merge_base, base).splitlines())
    on_pr = set(git_fn("diff", "--name-only", merge_base, head_sha).splitlines())
    return bool(on_base & on_pr)


# --- plan and act ---------------------------------------------------------------------


@dataclass
class Item:
    number: int
    branch: str
    action: str  # refresh | current | skip
    reason: str
    event: object | None = None


def plan(prs: list[dict], base_ref: str, stale_fn: Callable[[str, str], bool] = is_stale) -> list[Item]:
    items: list[Item] = []
    for pr in sorted(prs, key=lambda p: p["number"]):
        number, branch = pr["number"], pr["headRefName"]
        if pr.get("isCrossRepository"):
            items.append(Item(number, branch, "skip", "from a fork"))
            continue
        if not branch.startswith(BRANCH_PREFIX):
            items.append(Item(number, branch, "skip", f"branch is not {BRANCH_PREFIX}*"))
            continue
        try:
            event = parse_marker(pr.get("body"))
        except UpdateError as exc:
            items.append(Item(number, branch, "skip", str(exc)))
            continue
        if event is None:
            # Checked after the marker so the reason names what to do about it.
            items.append(Item(number, branch, "skip", "no recorded event: replay the release by hand"))
            continue
        if not stale_fn(base_ref, pr["headRefOid"]):
            items.append(Item(number, branch, "current", "built on the current master", event))
            continue
        items.append(Item(number, branch, "refresh", "master changed files this PR changes", event))
    return items


def dispatch_command(event, ref: str) -> list[str]:
    images = "\n".join(f"{image}@{digest}" for image, digest in sorted(event.images.items()))
    return [
        "gh", "workflow", "run", UPDATER_WORKFLOW, "--ref", ref,
        "-f", f"chart={event.chart}",
        "-f", f"version={event.version}",
        "-f", f"bump={event.bump}",
        "-f", f"images={images}",
    ]  # fmt: skip


def list_prs() -> list[dict]:
    out = subprocess.run(
        [
            "gh", "pr", "list", "--state", "open", "--label", PR_LABEL, "--limit", "100",
            "--json", "number,headRefName,headRefOid,body,isCrossRepository",
        ],
        check=True, capture_output=True, text=True,
    ).stdout  # fmt: skip
    return json.loads(out)


def summary(items: list[Item], dry_run: bool) -> str:
    if not items:
        return "No open chart-update PRs."
    verb = {"refresh": "would regenerate" if dry_run else "regenerating", "current": "up to date", "skip": "skipped"}
    lines = ["| PR | Branch | | Why |", "| --- | --- | --- | --- |"]
    for it in items:
        lines.append(f"| #{it.number} | `{it.branch}` | {verb[it.action]} | {it.reason} |")
    return "\n".join(lines)


def cmd_refresh(args: argparse.Namespace) -> int:
    items = plan(list_prs(), args.base)
    text = summary(items, args.dry_run)
    print(text)
    summary_file = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_file:
        with open(summary_file, "a") as fh:
            fh.write("### Chart-update PRs\n\n" + text + "\n")
    for it in items:
        if it.action != "refresh" or args.dry_run:
            continue
        subprocess.run(dispatch_command(it.event, args.ref), check=True)
    return 0


def cmd_marker(args: argparse.Namespace) -> int:
    try:
        event = upd.load_event(Path(args.event_file))
    except UpdateError as exc:
        print(f"refresh-chart-update-prs: {exc}", file=sys.stderr)
        return 2
    print(f"marker={render_marker(event)}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)

    marker = sub.add_parser("marker", help="print the PR-body marker for a release event file")
    marker.add_argument("event_file")
    marker.set_defaults(func=cmd_marker)

    refresh = sub.add_parser("refresh", help="regenerate chart-update PRs that master moved under")
    refresh.add_argument("--base", default="origin/master", help="ref the PRs are compared with")
    refresh.add_argument("--ref", default="master", help="branch the updater workflow is dispatched on")
    refresh.add_argument("--dry-run", action="store_true", help="report only; dispatch nothing")
    refresh.set_defaults(func=cmd_refresh)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())

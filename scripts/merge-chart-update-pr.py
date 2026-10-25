#!/usr/bin/env python3
"""Merge a chart-update PR once chart CI has passed on its current head.

The release of a module is the decision (release-process S1); the chart-update PR only carries
the released digests into the umbrella. When the chart workflows pass on that PR there is nothing
left for a person to decide, so this merges it — squash, as the repository allows nothing else.

Why not GitHub auto-merge on a ruleset that requires the checks? The two chart workflows are
path-filtered, and a required check that never runs blocks every PR outside `charts/**`; the
e2e workflow is too long to guard step by step. This asks about exactly the PRs it created.

A PR is merged only when ALL hold (decide() says which one failed):
  * it is an open, non-draft PR from a `chart-update/*` branch of this repository, with the label;
  * the run that woke this up was for the PR's CURRENT head (a re-run or a rebuild moved it on);
  * every required workflow has reported on that head and every report is a success;
  * it is not stale: master has not changed a file this PR also changes since it branched
    (refresh-chart-update-prs.py rebuilds such a PR; merging it first could publish a umbrella
    version that is already taken, and chart-releaser would skip it);
  * GitHub does not report a conflict.

The merge pins the head (`--match-head-commit`), so a push between the decision and the merge
makes it fail instead of merging something nobody checked. Whoever else evaluates the same PR
at the same moment loses the same way, which is why "already merged" is not an error.

    scripts/merge-chart-update-pr.py --branch chart-update/checkout-0.0.9 --sha <head sha> [--dry-run]

Needs `gh` (GH_TOKEN: a token whose pushes start workflows, CHART_UPDATE_TOKEN — a merge made
with GITHUB_TOKEN would not start the release workflow, and nothing would be published) and a
checkout with full history.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import subprocess
import sys
from pathlib import Path
from typing import Callable

HERE = Path(__file__).resolve().parent

_spec = importlib.util.spec_from_file_location("refresh_chart_update_prs", HERE / "refresh-chart-update-prs.py")
refresh = sys.modules.get("refresh_chart_update_prs")
if refresh is None:
    refresh = importlib.util.module_from_spec(_spec)
    sys.modules["refresh_chart_update_prs"] = refresh
    _spec.loader.exec_module(refresh)

# `workflowName` of the checks that must pass: the `name:` of the workflows. A test keeps these,
# the workflow files and labs64io-chart-update-merge.yml in step.
REQUIRED_WORKFLOWS = (
    "Labs64.IO - Helm Charts - Lint Charts",
    "Labs64.IO - Helm Charts - Published Chart E2E",
)
PR_FIELDS = "number,headRefName,headRefOid,labels,isDraft,isCrossRepository,mergeable,statusCheckRollup"


def decide(pr: dict, sha: str, base_ref: str, stale_fn: Callable[[str, str], bool] = refresh.is_stale) -> tuple[bool, str]:
    """(merge?, why). The first reason that stops the merge is the one reported."""
    branch = pr["headRefName"]
    if pr.get("isCrossRepository"):
        return False, "from a fork"
    if not branch.startswith(refresh.BRANCH_PREFIX):
        return False, f"branch is not {refresh.BRANCH_PREFIX}*"
    if refresh.PR_LABEL not in {label["name"] for label in pr.get("labels", [])}:
        return False, f"no {refresh.PR_LABEL} label"
    if pr.get("isDraft"):
        return False, "draft"
    if pr["headRefOid"] != sha:
        return False, "the run was for an older head; the new head has its own runs"

    reports = pr.get("statusCheckRollup") or []
    for workflow in REQUIRED_WORKFLOWS:
        mine = [r for r in reports if r.get("workflowName") == workflow]
        if not mine:
            return False, f"{workflow} has not reported"
        # A run still going has an empty conclusion; anything but SUCCESS (failure, cancelled,
        # skipped) is not a pass for a gate that exists to find out.
        not_passed = [r for r in mine if r.get("conclusion") != "SUCCESS"]
        if not_passed:
            return False, f"{workflow}: {not_passed[0].get('name')} is {(not_passed[0].get('conclusion') or 'still running').lower()}"

    if pr.get("mergeable") == "CONFLICTING":
        return False, "conflicts with master (the refresh job rebuilds it)"
    if stale_fn(base_ref, pr["headRefOid"]):
        return False, "master changed files this PR changes (the refresh job rebuilds it)"
    return True, "chart CI passed on the current head"


def find_pr(branch: str) -> dict | None:
    out = subprocess.run(
        ["gh", "pr", "list", "--head", branch, "--state", "open", "--json", PR_FIELDS],
        check=True, capture_output=True, text=True,
    ).stdout  # fmt: skip
    prs = json.loads(out)
    return prs[0] if prs else None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--branch", required=True, help="head branch of the workflow run")
    parser.add_argument("--sha", required=True, help="head sha of the workflow run")
    parser.add_argument("--base", default="origin/master", help="ref the PR is compared with")
    parser.add_argument("--dry-run", action="store_true", help="decide and report; merge nothing")
    args = parser.parse_args()

    pr = find_pr(args.branch)
    if pr is None:
        print(f"No open PR for {args.branch}: nothing to merge.")
        return 0
    ok, why = decide(pr, args.sha, args.base)
    print(f"#{pr['number']} {args.branch}: {'merge' if ok else 'wait'} — {why}")
    if not ok or args.dry_run:
        return 0

    merge = subprocess.run(
        ["gh", "pr", "merge", str(pr["number"]), "--squash", "--match-head-commit", pr["headRefOid"]],
        capture_output=True, text=True,
    )  # fmt: skip
    if merge.returncode != 0:
        # Lost the race to another evaluation of the same PR, or the head moved: both are fine,
        # the next run decides again. Anything else is worth a red job.
        message = (merge.stderr or merge.stdout).strip()
        # (Not "is not mergeable": a branch rule that forbids the merge says that too, and it must show.)
        benign = ("already merged", "Head branch was modified")
        if any(text in message for text in benign):
            print(f"Not merged: {message}")
            return 0
        print(message, file=sys.stderr)
        return merge.returncode
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Bump a chart's version and everything that has to move with it.

Chart CI rejects a chart change without a version bump, and chart-releaser silently
skips a chart whose version did not move. The bump also cascades: a chart that
depends on the bumped one through `file://../<chart>` vendors it at package time,
so it must be republished as well.

    chart-libs  ->  every module chart (pin moved to the new version + own bump)
                ->  labs64io-ecosystem umbrella (own bump)
    module chart ->  labs64io-ecosystem umbrella (own bump)

Usage:
    scripts/bump-chart-version.py auditflow            # patch
    scripts/bump-chart-version.py chart-libs minor
    just bump auditflow

Run `just generate-all` afterwards (chart READMEs carry the version) and
`helm dependency update` for the charts whose Chart.lock changed.
"""

from __future__ import annotations

import argparse
import importlib.util
import sys
from pathlib import Path

_SCRIPT = Path(__file__).resolve().parent / "update-chart-images.py"
_spec = importlib.util.spec_from_file_location("update_chart_images", _SCRIPT)
upd = importlib.util.module_from_spec(_spec)
sys.modules["update_chart_images"] = upd
_spec.loader.exec_module(upd)


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("chart", help="chart directory name under charts/")
    parser.add_argument("part", nargs="?", default="patch", choices=("patch", "minor", "major"))
    parser.add_argument("--charts-dir", default=str(upd.CHARTS_DIR), help=argparse.SUPPRESS)
    args = parser.parse_args()

    try:
        result = upd.bump_chart(Path(args.charts_dir), args.chart, args.part)
    except upd.UpdateError as exc:
        print(f"bump-chart-version: {exc}", file=sys.stderr)
        return 2
    for change in result.changes:
        print(f"  {change.file}: {change.what}: {change.old} -> {change.new}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

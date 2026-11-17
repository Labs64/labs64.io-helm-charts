#!/usr/bin/env bash
# Builds every chart's dependencies (helm dependency build), the umbrella LAST.
#
# Vendored dependencies (charts/*/charts/) are gitignored, so a fresh checkout has none. The umbrella
# (labs64io-ecosystem) vendors the module charts by packaging them as they are on disk when its own dependencies are
# built, so a module chart whose `chart-libs` has not been built yet reaches the umbrella without it, and the released
# umbrella then fails at render time (`no template "chart-libs.test-connection"`). The order is therefore not a detail:
# every other chart first, the umbrella after them.
#
# The ONE place this loop lives: the lint workflow, the release workflow and `just check-package` all call it. A copy
# in alphabetical order (the umbrella before payment-gateway) is what broke the lint run of the chart-update PR #73;
# scripts/test_build_chart_dependencies.py fails if another copy appears.
#
# Usage: build-chart-dependencies.sh [build|update]   (default: build)
#   build   rebuilds from Chart.lock, which must be in sync (lint, release, `just check-package`)
#   update  re-resolves and rewrites Chart.lock: the chart-image-update workflow, whose updater bumps the umbrella's
#           dependency versions in Chart.yaml and so leaves its Chart.lock behind
set -euo pipefail

mode="${1:-build}"
case "$mode" in
    build|update) ;;
    *) echo "usage: $0 [build|update]" >&2; exit 2 ;;
esac

cd "$(dirname "${BASH_SOURCE[0]}")/.."
umbrella=labs64io-ecosystem

for chart_dir in charts/*/; do
    chart_dir="${chart_dir%/}"
    [ -f "$chart_dir/Chart.yaml" ] || continue
    [ "$(basename "$chart_dir")" = "$umbrella" ] && continue
    helm dependency "$mode" "$chart_dir"
done
helm dependency "$mode" "charts/$umbrella"

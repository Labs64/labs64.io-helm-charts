# Group `quality gates` (docs/justfiles.md in labs64.io-workspace). Imported by the justfile.

# What the pull-request check (.github/workflows/labs64io-lint-charts.yml) runs, in the same order: each of its
# steps calls one of these recipes. Needs helm with the schema plugin, Docker (for helm-docs), python3 with pyyaml
# and pytest, and the bitnami and traefik Helm repositories. No cluster.
#
# Run what the charts' pull-request check runs
[group('quality gates')]
ci: test check-bumps check-generated check-package lint

# The scripts in scripts/ gate every chart change (version bumps, the packaged umbrella, credentials in ConfigMaps,
# the authoring checklist) and rewrite charts unattended (the image updater): a gate nobody tests reports "clean"
# forever. Offline.
#
# Run the tests of the gate scripts and the chart image updater
[group('quality gates')]
test:
    python3 -m pytest scripts -q -p no:cacheprovider

# The three static checks of the charts. No cluster.
#
# Lint the charts: credentials in ConfigMaps, the authoring checklist, helm lint and render of every chart
[group('quality gates')]
lint: lint-secrets lint-authoring lint-charts

# Fail if any chart renders a credential into a ConfigMap
[group('quality gates')]
lint-secrets *ARGS:
    python3 scripts/lint-configmap-secrets.py {{ARGS}}

# chart authoring checklist (item 30): ingress annotations, sub-path PV mounts,
# probe defaults, NetworkPolicy egress — a gate that runs, not prose
#
# Check the charts against the authoring checklist: ingress annotations, PV mounts, probes, egress policy
[group('quality gates')]
lint-authoring *ARGS:
    python3 scripts/lint-chart-authoring.py {{ARGS}}

# Every chart in charts/: helm lint, a values.schema.json present, and (application charts) a render with its
# defaults and one with its committed values, which runs the schema validation. A library chart cannot render on its
# own; the consumer charts exercise its templates. The umbrella renders in its demo mode.
#
# Lint and render every chart with its own values, as the pull-request check does
[group('quality gates')]
lint-charts: _build-chart-dependencies
    #!/usr/bin/env bash
    set -euo pipefail
    FAILED=0
    for chart_dir in charts/*/; do
        chart_name=$(basename "$chart_dir")
        [ -f "$chart_dir/Chart.yaml" ] || continue
        chart_type=$(sed -n -E 's/^type: *//p' "$chart_dir/Chart.yaml")
        echo "=== Linting: $chart_name ==="
        if ! helm lint "$chart_dir"; then
            echo "FAIL: helm lint $chart_name"
            FAILED=1
        fi
        # Schema validation metadata is required for both application and library charts.
        if [ ! -f "$chart_dir/values.schema.json" ]; then
            echo "FAIL: Missing values.schema.json in $chart_name"
            FAILED=1
        fi
        # A library chart only defines named templates for its consumers. Helm deliberately rejects installing or
        # rendering it on its own; consumer charts in this loop exercise those templates through their
        # file://chart-libs dependency.
        if [ "$chart_type" = "library" ]; then
            echo "SKIP: standalone template validation is not applicable to library chart $chart_name"
            echo "PASS: $chart_name"
            continue
        fi
        EXTRA_ARGS=()
        if [ "$chart_name" = "labs64io-ecosystem" ]; then
            EXTRA_ARGS=(--set demoMode=true)
        fi
        # helm template (syntax + render check)
        if ! helm template "test-$chart_name" "$chart_dir" "${EXTRA_ARGS[@]}" > /dev/null 2>&1; then
            echo "FAIL: helm template $chart_name"
            helm template "test-$chart_name" "$chart_dir" "${EXTRA_ARGS[@]}" 2>&1 | tail -5
            FAILED=1
        fi
        # Render once with the committed values to exercise values.schema.json validation.
        if ! helm template "test-$chart_name" "$chart_dir" -f "$chart_dir/values.yaml" "${EXTRA_ARGS[@]}" > /dev/null 2>&1; then
            echo "FAIL: schema validation $chart_name"
            helm template "test-$chart_name" "$chart_dir" -f "$chart_dir/values.yaml" "${EXTRA_ARGS[@]}" 2>&1 | tail -5
            FAILED=1
        fi
        echo "PASS: $chart_name"
    done
    if [ "$FAILED" -ne 0 ]; then
        echo ""
        echo "Some charts failed linting. See errors above."
        exit 1
    fi
    echo ""
    echo "All charts passed."

# verify every changed chart (and every chart vendoring it) is bumped against a base ref —
# the same gate chart CI runs
#
# Check that every changed chart and every chart vendoring it is version-bumped against a base ref
[group('quality gates')]
check-bumps base="origin/master":
    python3 scripts/check-chart-version-bumps.py --base {{base}}

# The schemas and the chart READMEs are generated and committed. This regenerates both and fails when that changed
# a file under charts/; it compares against the state before, so a chart you are editing does not count as stale.
# The regenerated files stay in place: review and commit them.
#
# Check that the committed schemas and chart READMEs are what the generators write
[group('quality gates')]
check-generated:
    #!/usr/bin/env bash
    set -euo pipefail
    state() { git status --porcelain=v1 --untracked-files=all -- charts; git diff --binary -- charts; }
    before=$(state | sha256sum)
    just generate-all
    if [ "$(state | sha256sum)" != "$before" ]; then
        git status --short -- charts >&2
        echo "ERROR: the generated schemas or chart READMEs were out of date. They are regenerated now: review and commit them (just generate-all)." >&2
        exit 1
    fi
    echo "Generated schemas and chart READMEs are up to date."

# Build every chart's dependencies, package the umbrella and fail unless it is self-contained
# (each bundled module chart carries chart-libs) — the same gate the release workflow runs
#
# Check that the packaged umbrella chart bundles every dependency
[group('quality gates')]
check-package: _build-chart-dependencies
    #!/usr/bin/env bash
    set -euo pipefail
    out=$(mktemp -d); trap 'rm -rf "$out"' EXIT
    helm package charts/labs64io-ecosystem --destination "$out" >/dev/null
    python3 scripts/check-packaged-chart.py "$out"/labs64io-ecosystem-*.tgz

# Vendored dependencies (charts/*/charts/) are gitignored, so a fresh checkout has none, and every chart that depends
# on chart-libs fails to lint or render without them. The script builds the umbrella last.
#
# Build the dependencies of every chart into charts/*/charts/
[private]
_build-chart-dependencies:
    bash scripts/build-chart-dependencies.sh >/dev/null

# render every helmfile release without a cluster, failing on any template error
#
# `helm lint` above checks charts in isolation; this catches what it cannot — bad values
# overrides, cross-chart wiring and the `fail` guards in chart-libs (for example a
# non-public route that would be served over Ingress). Needs no cluster and no CRDs:
# helmDefaults.templateArgs in helmfile.yaml.gotmpl supplies the Gateway API version that
# would otherwise only come from a live cluster.
#
# Render every Helmfile release without a cluster and fail on any template error
[group('quality gates')]
check-templates:
    #!/usr/bin/env bash
    set -euo pipefail
    out="$(mktemp)"
    trap 'rm -f "$out"' EXIT
    if helmfile -e {{ENV}} template > "$out"; then
        echo "=== all releases rendered ($(grep -c '^kind:' "$out") manifests) ==="
    else
        echo "=== helmfile template FAILED (see above) ===" >&2
        exit 1
    fi

# Validate the rendered OTel Collector config against the pinned collector binary.
#
# `helm template` only proves the YAML renders — it knows nothing about which keys each
# component accepts. This runs the real collector's `validate` subcommand over the
# rendered config, catching errors that otherwise surface as a CrashLoopBackOff after
# deploy. It has already caught one: the prometheusremotewrite exporter rejects
# `sending_queue` ("has invalid keys"), which the OTLP exporters accept happily.
#
# Requires Docker. The image tag is read from values-collector.{{ENV}}.yaml so the
# validator always matches the collector actually deployed.
#
# Validate the rendered OTel Collector config with the pinned collector binary
[group('quality gates')]
check-otel-config:
    #!/usr/bin/env bash
    set -euo pipefail
    VALUES="overrides/opentelemetry/values-collector.{{ENV}}.yaml"
    WORK="$(mktemp -d)"
    trap 'rm -rf "$WORK"; docker rm -f otel-cfg-validate >/dev/null 2>&1 || true; docker volume rm otel-cfg-validate-vol >/dev/null 2>&1 || true' EXIT

    IMAGE="$(python3 -c "import sys,re;s=open('$VALUES').read();r=re.search(r'^image:\s*$\n(?:\s+.*\n)*?\s+repository:\s*(\S+)',s,re.M);t=re.search(r'^image:\s*$\n(?:\s+.*\n)*?\s+tag:\s*(\S+)',s,re.M);print(f'{r.group(1)}:{t.group(1)}')")"
    echo "=== validating against $IMAGE ==="

    helm template opentelemetry-collector open-telemetry/opentelemetry-collector \
      --version "$(just show-chart-version opentelemetry-collector)" \
      -f "$VALUES" --namespace {{NAMESPACE_MONITORING}} > "$WORK/rendered.yaml"

    # Pull the collector config out of the ConfigMap's `relay` key.
    python3 - "$WORK" <<'PY'
    import sys
    w = sys.argv[1]
    for doc in open(w + "/rendered.yaml").read().split("\n---\n"):
        if "kind: ConfigMap" in doc and "  relay: |" in doc:
            body = doc[doc.index("  relay: |") + len("  relay: |"):]
            out = []
            for ln in body.split("\n"):
                if ln.strip() == "":
                    out.append("")
                    continue
                if ln.startswith("    "):
                    out.append(ln[4:])
                else:
                    break
            open(w + "/config.yaml", "w").write("\n".join(out))
            break
    else:
        sys.exit("could not find collector ConfigMap in rendered output")
    PY

    # K8S_NODE_NAME and the storage dir exist in the pod but not in a bare container;
    # supply both so real config errors are not masked by environment noise.
    docker rm -f otel-cfg-validate >/dev/null 2>&1 || true
    docker volume create otel-cfg-validate-vol >/dev/null
    docker create --name otel-cfg-validate \
      -e K8S_NODE_NAME=validation-node \
      -v otel-cfg-validate-vol:/var/lib/otelcol \
      "$IMAGE" validate --config=/etc/otelcol-contrib/config.yaml >/dev/null
    docker cp "$WORK/config.yaml" otel-cfg-validate:/etc/otelcol-contrib/config.yaml
    if docker start -a otel-cfg-validate; then
        echo "=== OTel Collector config is valid ==="
    else
        echo "=== OTel Collector config is INVALID (see above) ===" >&2
        exit 1
    fi

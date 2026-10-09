# CLI tool versions (HELM_DOCS_VERSION, HELM_DIFF_VERSION, HELM_SCHEMA_VERSION) come from
# the workspace's single tool-versions.env. In CI the setup-k8s-tools action exports the
# same variables; a missing file is not an error, the recipes that need a value say so.
set dotenv-path := "../labs64.io-workspace/tool-versions.env"

ENV := "local"
NAMESPACE_LABS64IO := "labs64io"
NAMESPACE_KUBE_SYSTEM := "kube-system"
NAMESPACE_MONITORING := "monitoring"
NAMESPACE_TOOLS := "tools"

# Chart versions, repositories, release names and value layering all live in
# helmfile.yaml.gotmpl and nowhere else — recipes below read them from there
# (`just chart-version <release>`). The two CRD versions applied outside Helm (Gateway API,
# Traefik CRDs) are in justfile.versions.
import 'justfile.versions'

# List available commands
default:
    @just --list

## 🚀 Getting Started (Cluster & Setup) ##

# Create the local k3d cluster and registry, or start them again if they are stopped
cluster-up:
    k3d cluster list labs64io >/dev/null 2>&1 && k3d cluster start labs64io || k3d cluster create --config k3d/labs64io.yaml
    k3d kubeconfig merge -d labs64io
    if [ -f /.dockerenv ]; then perl -i -pe 's/server: https:\/\/0\.0\.0\.0/server: https:\/\/host.docker.internal/g' ~/.kube/config; fi
    if [ -f /.dockerenv ]; then perl -i -pe 's/server: https:\/\/127\.0\.0\.1/server: https:\/\/host.docker.internal/g' ~/.kube/config; fi

# Start the local k3d cluster and deploy the stack from the Helm overrides
up: generate-secrets cluster-up
    just deploy

# Reconcile tools, the selected identity provider, and all applications.
# The workspace-level `just up` calls this after building first-party images.
#
# Install the core tools, the selected identity provider and all applications
deploy:
    just repo-update
    just install-tools
    just install-all-apps
    @echo "Local environment ready: http://gateway.localhost/swagger-ui/"

# Start the local environment with the monitoring stack and module telemetry enabled
up-otel: up install-monitoring enable-observability

# Uninstall all apps, monitoring and tools but keep the cluster
reset: uninstall-all-apps uninstall-monitoring uninstall-tools

# Reset the environment, then delete the local k3d cluster and its registry
cluster-down: reset
    k3d cluster delete labs64io

# Prune unused Docker data, including volumes, without asking for confirmation
docker-system-prune:
    docker system prune -a --volumes -f

# enable OTel instrumentation on instrumented module apps (requires the monitoring
# stack — the collector DaemonSet must be running so OTLP export has a target).
# Kept off in the base `up` profile so a monitoring-less cluster shows no export errors.
# Which apps are instrumented is declared in helmfile.yaml.gotmpl (label
# `observability: "true"`); every apply below passes the same switch, so neither
# `install-app` nor `install-all-apps` can silently drop telemetry afterwards.
#
# Turn on OpenTelemetry instrumentation for the instrumented module apps
enable-observability:
    helmfile -e {{ENV}} --state-values-set observability.enabled=true apply -l observability=true

# Helmfile state flag that follows the monitoring stack: observability is on exactly when
# the OTel collector is running.
#
# Print the Helmfile flag that enables observability when the OTel collector is running
[private]
_observability-args:
    #!/usr/bin/env bash
    if kubectl get daemonset opentelemetry-collector-agent -n {{NAMESPACE_MONITORING}} >/dev/null 2>&1; then
        echo "--state-values-set observability.enabled=true"
    fi

# Print the chart version that helmfile.yaml.gotmpl pins for a release
chart-version release:
    #!/usr/bin/env bash
    set -euo pipefail
    version="$(helmfile -e {{ENV}} list --output json 2>/dev/null \
        | jq -r --arg name "{{release}}" '.[] | select(.name == $name) | .version')"
    if [ -z "$version" ] || [ "$version" = "null" ]; then
        echo "helmfile.yaml.gotmpl pins no chart version for release '{{release}}'" >&2
        exit 1
    fi
    echo "$version"

# uninstall every release of a helmfile layer (infra | identity | monitoring | apps),
# whether or not the current overrides still select it
#
# Uninstall every release of a Helmfile layer, even if the overrides no longer select it
[private]
_uninstall-layer layer:
    #!/usr/bin/env bash
    set -euo pipefail
    helmfile -e {{ENV}} list --output json 2>/dev/null \
        | jq -r --arg layer "layer:{{layer}}" '.[] | select(.labels | split(",") | index($layer)) | "\(.name) \(.namespace)"' \
        | while read -r name namespace; do
            helm uninstall "$name" --namespace "$namespace" 2>/dev/null || true
        done

# Create missing local secret files from their .example templates
generate-secrets:
    #!/usr/bin/env bash
    set -euo pipefail
    for dir in overrides/*/; do
        if [ -f "${dir}values.secrets.local.yaml.example" ] && [ ! -f "${dir}values.secrets.local.yaml" ]; then
            cp "${dir}values.secrets.local.yaml.example" "${dir}values.secrets.local.yaml"
            echo "Generated ${dir}values.secrets.local.yaml"
        fi
    done


## 📦 Labs64.IO Apps ##

# Install all Labs64.IO apps
install-all-apps:
    helmfile -e {{ENV}} $(just _observability-args) apply -l layer=apps

# Uninstall all Labs64.IO apps
uninstall-all-apps: (_uninstall-layer "apps")

# Install a specific Labs64.IO application — the same helmfile release `install-all-apps`
# applies (chart values, global values, per-env override, secrets, identity provider),
# optionally with one more values file layered on top
#
# Install one Labs64.IO app the way install-all-apps does, optionally with an extra values file
install-app app extra_values="":
    #!/usr/bin/env bash
    set -euo pipefail
    echo "=== Installing Labs64.IO App: {{app}} ==="
    ARGS=()
    extra_values="{{extra_values}}"
    if [ -n "$extra_values" ]; then
      if [ ! -f "$extra_values" ]; then
        echo "Additional values file not found: $extra_values" >&2
        exit 1
      fi
      echo "Using additional override: $extra_values"
      ARGS+=("--values" "$extra_values")
    fi
    STATE_ARGS=()
    if [ "{{app}}" = "checkout" ]; then
      # Not GA, so not in the default set (helmfile.yaml.gotmpl); asking for it by name installs it.
      STATE_ARGS+=("--state-values-set" "installCheckout=true")
    fi
    helmfile -e {{ENV}} $(just _observability-args) "${STATE_ARGS[@]}" apply -l name=labs64io-{{app}} "${ARGS[@]}"

# Point only the existing local Payment Gateway deployment at the host-side PSP stub.
# The extra values file deep-merges provider-owned Spring configuration and rolls the PG pod.
#
# Point the local Payment Gateway at the host-side PSP stub and roll its pod
payment-gateway-psp-stub-enable host_cidr stub_url:
    helm upgrade labs64io-payment-gateway ./charts/payment-gateway \
      --namespace {{NAMESPACE_LABS64IO}} \
      --reuse-values \
      -f ./overrides/payment-gateway/values.psp-stub.local.yaml \
      --set-string 'applicationYaml.payment-provider.stripe.api-base-url={{stub_url}}' \
      --set-string 'applicationYaml.payment-provider.paypal.api-base-url={{stub_url}}' \
      --set-string 'networkPolicy.extraEgress[0].to[0].ipBlock.cidr={{host_cidr}}' \
      --set-string 'networkPolicy.extraEgress[0].ports[0].protocol=TCP' \
      --set 'networkPolicy.extraEgress[0].ports[0].port=8090' \
      --force-conflicts
    # Rollout health is the setup gate. The selected PSP Robot scenarios then prove that both
    # SDK clients actually use this endpoint by making black-box calls that WireMock verifies;
    # startup-log text is diagnostic output, not a stable configuration contract.
    kubectl rollout status deployment/labs64io-payment-gateway --namespace {{NAMESPACE_LABS64IO}} --timeout=180s

# Restore the default Payment Gateway values with the official PSP endpoints
payment-gateway-psp-stub-disable:
    just install-app payment-gateway
    kubectl rollout status deployment/labs64io-payment-gateway --namespace {{NAMESPACE_LABS64IO}} --timeout=180s


# Uninstall a specific Labs64.IO application
uninstall-app app:
    helm uninstall labs64io-{{app}} --namespace {{NAMESPACE_LABS64IO}} || true


## 🛠️ Core Tools ##

# Install the core tools and the identity provider selected in the overrides
install-tools: install-crds
    # traefik is applied separately with --skip-crds: its chart bundles its own copy of
    # the Traefik CRDs, which can now drift ahead of the traefik-crds chart pinned in
    # install-crds (e.g. a middlewares CRD field newer than TRAEFIK_CRDS_CHART_VERSION).
    # Helm's own CRD installer applies its bundled copy via server-side apply, which then
    # conflicts with the field manager from install-crds' `kubectl apply --server-side`
    # instead of the plain create-skip-if-exists this was designed around. Since helmfile
    # has no per-release skip-crds (only the global apply flag), traefik is selected out
    # of the blanket apply below and given its own --skip-crds run — the other layer=infra
    # charts (e.g. external-secrets) still need normal CRD install.
    helmfile -e {{ENV}} apply -l layer=infra,name!=traefik
    helmfile -e {{ENV}} apply -l name=traefik --skip-crds
    kubectl apply -f overrides/traefik/dashboard-httproute.yaml
    # The ClusterSecretStore goes through ESO's validating webhook — wait for it to be
    # ready first, since `helmfile apply` above returns as soon as objects are applied,
    # not once the webhook deployment is actually serving.
    kubectl -n {{NAMESPACE_TOOLS}} wait --for=condition=available --timeout=120s deployment/external-secrets-webhook
    kubectl apply -f overrides/eso/cluster-secret-store.yaml
    just migrate-legacy-mock-oidc
    helmfile -e {{ENV}} apply -l layer=identity

# Uninstall all core tools (identity providers included, whichever is selected)
uninstall-tools: (_uninstall-layer "identity")
    kubectl delete -f overrides/eso/cluster-secret-store.yaml --ignore-not-found
    just _uninstall-layer infra
    kubectl delete pvc -l app=rabbitmq --namespace {{NAMESPACE_TOOLS}} --ignore-not-found

# Install the Gateway API (standard channel) + Traefik CRDs before the `traefik` Helm
# release (Helmfile's release schema has no per-release skip-crds equivalent, and Helm
# never upgrades CRDs bundled in a chart's crds/ directory after first install — so these
# are managed here as an independently-versioned, re-appliable step. Helm/Helmfile only
# install a chart's bundled CRDs "if not already present", so pre-seeding them here means
# the `traefik` release's own bundled copies are simply skipped, no conflict).
#
# Install the Gateway API and Traefik CRDs ahead of the Traefik release
install-crds:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Installing Gateway API (standard channel) CRDs..."
    kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/{{GATEWAY_API_VERSION}}/standard-install.yaml
    echo "Installing Traefik CRDs..."
    helm template traefik-crds traefik/traefik-crds --version {{TRAEFIK_CRDS_CHART_VERSION}} --namespace {{NAMESPACE_TOOLS}} | kubectl apply --server-side -f -

# (Re)install one core or monitoring tool exactly as `install-tools` / `install-monitoring`
# would — same chart version, same values, straight from helmfile.yaml.gotmpl.
# `just install-tool postgresql`, `just install-tool redis`, `just install-tool grafana`, …
# (names: `helmfile -e local list`). Traefik and the monitoring CRD-carrying charts
# have prerequisites: use install-tool-traefik / install-monitoring for a fresh cluster.
#
# Install or reinstall one core or monitoring tool exactly as install-tools and install-monitoring would
install-tool name:
    helmfile -e {{ENV}} apply -l name={{name}}

# Uninstall one core or monitoring tool by its Helmfile release name
uninstall-tool name:
    #!/usr/bin/env bash
    set -euo pipefail
    namespace="$(helmfile -e {{ENV}} list --output json 2>/dev/null \
        | jq -r --arg name "{{name}}" '.[] | select(.name == $name) | .namespace')"
    [ -n "$namespace" ] || { echo "no helmfile release named '{{name}}'" >&2; exit 1; }
    helm uninstall "{{name}}" --namespace "$namespace" || true

# Install the Traefik CRDs, then the Traefik release without its bundled CRDs
install-tool-traefik: install-crds
    helmfile -e {{ENV}} apply -l name=traefik --skip-crds
    kubectl apply -f overrides/traefik/dashboard-httproute.yaml

# Print the identity provider selected in overrides/helmfile/values.<env>.yaml
identity-provider:
    @sed -n -E 's/^identityProvider:[[:space:]]*([a-z]+).*/\1/p' overrides/helmfile/values.{{ENV}}.yaml | grep . || echo mock

# One-time migration for clusters created before mock-oidc became a Helm release: it used to be
# applied as raw manifests (overrides/mock-oidc/mock-oidc.yaml, removed), and Helm refuses to adopt
# objects it does not own ("exists and cannot be imported into the current release"). Deletes only
# those four legacy objects, and only when the Deployment carries no Helm ownership annotation;
# Helmfile then recreates them as the `mock-oidc` release. No-op on every other cluster.
#
# Remove the legacy raw mock-oidc objects so Helm can take them over (one-time migration)
migrate-legacy-mock-oidc:
    #!/usr/bin/env bash
    set -euo pipefail
    kubectl -n {{NAMESPACE_TOOLS}} get deployment mock-oidc >/dev/null 2>&1 || exit 0
    owner=$(kubectl -n {{NAMESPACE_TOOLS}} get deployment mock-oidc -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-name}')
    [ -z "$owner" ] || exit 0
    echo "Migrating legacy raw-manifest mock-oidc to a Helm release..."
    kubectl -n {{NAMESPACE_TOOLS}} delete httproute/mock-oidc service/mock-oidc deployment/mock-oidc configmap/mock-oidc-config --ignore-not-found

# Install mock OIDC only when it is the provider selected by the environment overrides.
# Provider switching remains declarative: this recipe never edits values files itself.
#
# Install mock OIDC if it is the identity provider selected in the overrides
install-tool-mock-oidc: migrate-legacy-mock-oidc
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "$(just identity-provider)" != "mock" ]; then
        echo "identityProvider is not 'mock' in overrides/helmfile/values.{{ENV}}.yaml" >&2
        exit 1
    fi
    helmfile -e {{ENV}} apply -l layer=identity

# Install Keycloak only when it is the provider selected by the environment overrides.
#
# Install Keycloak if it is the identity provider selected in the overrides
install-tool-keycloak:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "$(just identity-provider)" != "keycloak" ]; then
        echo "identityProvider is not 'keycloak' in overrides/helmfile/values.{{ENV}}.yaml" >&2
        exit 1
    fi
    helmfile -e {{ENV}} apply -l layer=identity


## 📊 Monitoring Tools ##

# Install all monitoring tools
install-monitoring: install-monitoring-crds
    helmfile -e {{ENV}} apply -l layer=monitoring
    kubectl apply -f overrides/grafana/grafana-httproute.yaml
    kubectl apply -f overrides/grafana/grafana-dashboards.yaml

# Pre-install kube-prometheus-stack's CRDs (Prometheus/PrometheusRule/ServiceMonitor/etc.).
# Helm only applies a chart's bundled crds/ during actual install/upgrade, but helmfile's
# helm-diff plugin renders+diffs first (even for a brand-new release) and needs those types
# already registered to resolve REST mappings — without this, `install-monitoring` fails with
# "no matches for kind Prometheus/PrometheusRule/ServiceMonitor in version monitoring.coreos.com/v1"
# on a fresh cluster. Mirrors the Traefik/Gateway API CRD pre-install in `install-crds`.
#
# Install the kube-prometheus-stack CRDs ahead of the monitoring release
install-monitoring-crds:
    helm show crds prometheus-community/kube-prometheus-stack --version "$(just chart-version prometheus)" | kubectl apply --server-side -f -

# Uninstall all monitoring tools
uninstall-monitoring: (_uninstall-layer "monitoring")

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
validate-otel-config:
    #!/usr/bin/env bash
    set -euo pipefail
    VALUES="overrides/opentelemetry/values-collector.{{ENV}}.yaml"
    WORK="$(mktemp -d)"
    trap 'rm -rf "$WORK"; docker rm -f otel-cfg-validate >/dev/null 2>&1 || true; docker volume rm otel-cfg-validate-vol >/dev/null 2>&1 || true' EXIT

    IMAGE="$(python3 -c "import sys,re;s=open('$VALUES').read();r=re.search(r'^image:\s*$\n(?:\s+.*\n)*?\s+repository:\s*(\S+)',s,re.M);t=re.search(r'^image:\s*$\n(?:\s+.*\n)*?\s+tag:\s*(\S+)',s,re.M);print(f'{r.group(1)}:{t.group(1)}')")"
    echo "=== validating against $IMAGE ==="

    helm template opentelemetry-collector open-telemetry/opentelemetry-collector \
      --version "$(just chart-version opentelemetry-collector)" \
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

# Install the OpenTelemetry operator and collector after validating the collector config
install-tool-opentelemetry: validate-otel-config
    helmfile -e {{ENV}} apply -l name=opentelemetry-operator
    helmfile -e {{ENV}} apply -l name=opentelemetry-collector

# Install Grafana with its route and dashboards
install-tool-grafana:
    helmfile -e {{ENV}} apply -l name=grafana
    kubectl apply -f overrides/grafana/grafana-httproute.yaml
    kubectl apply -f overrides/grafana/grafana-dashboards.yaml

# Print the Grafana admin password
grafana-password:
    @echo "Password: " && kubectl get secret --namespace {{NAMESPACE_MONITORING}} grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo


## 🏗️ Build & CodeGen ##

# Install the Helm plugins at the versions pinned in tool-versions.env
helm-tools:
    #!/usr/bin/env bash
    set -euo pipefail
    : "${HELM_DIFF_VERSION:?not set — check out labs64.io-workspace next to this repo (tool-versions.env)}"
    : "${HELM_SCHEMA_VERSION:?not set — check out labs64.io-workspace next to this repo (tool-versions.env)}"
    helm plugin install --verify=false https://github.com/databus23/helm-diff --version "v${HELM_DIFF_VERSION}" 2>/dev/null || true
    helm plugin install --verify=false https://github.com/dadav/helm-schema --version "${HELM_SCHEMA_VERSION}" 2>/dev/null || true
    echo "Installed Helm plugins:"
    helm plugin list

# Generate Helm chart documentation (README.md) for all charts. Uses a local `helm-docs` binary
# when it is the pinned version (the dev container installs it), else the pinned Docker image —
# which cannot work inside the dev container, where Docker resolves bind-mount paths on the host.
#
# Generate the README.md documentation for all Helm charts
generate-docu:
    #!/usr/bin/env bash
    set -euo pipefail
    : "${HELM_DOCS_VERSION:?not set — check out labs64.io-workspace next to this repo (tool-versions.env)}"
    if command -v helm-docs >/dev/null 2>&1 && [ "$(helm-docs --version | awk '{print $NF}')" = "${HELM_DOCS_VERSION}" ]; then
        helm-docs --chart-search-root ./charts --log-level warning
    else
        docker run --rm \
            --volume "$(pwd):/helm-docs" \
            --user "$(id -u):$(id -g)" \
            "jnorwood/helm-docs:v${HELM_DOCS_VERSION}" \
            --chart-search-root ./charts \
            --log-level warning
    fi

# Generate Helm values schema (values.schema.json) for all charts
#
# helm-schema exits non-zero when it cannot parse a *vendored subchart's* own
# @schema comments: Traefik's values.yaml uses a single-line
# `@schema type: [boolean, null]` form its parser rejects. It still writes every
# schema in this repo correctly, so the run is judged by its output rather than its
# exit code — fail only when a chart ends up without a schema. (--dependencies-filter
# silences the message but writes 1 schema instead of 11; do not "fix" it that way.)
#
# Generate values.schema.json for all Helm charts
generate-schema: helm-tools
    #!/usr/bin/env bash
    set -uo pipefail
    helm schema \
        --chart-search-root ./charts \
        --no-dependencies \
        --append-newline || true
    missing=0
    for chart in charts/*/values.yaml; do
        dir=$(dirname "$chart")
        if [ ! -f "$dir/values.schema.json" ]; then
            echo "generate-schema: no schema written for $dir" >&2
            missing=1
        fi
    done
    exit $missing

# Generate the chart documentation and the values schemas
generate-all: generate-docu generate-schema

# Generate the Cerbos policy set + authproxy routes manifests from module OpenAPI
# specs. Writes charts/authz-pdp/{policies,schemas} + charts/api-gateway/routes.
#
# Generate the Cerbos policies and authproxy routes from the module OpenAPI specs
build-policies:
    ./policies/build-authz-policies.sh

# add + refresh exactly the helm repositories helmfile.yaml.gotmpl declares
#
# Deliberately not a bare `helm repo update`, which updates EVERY repo in the caller's
# local helm config and fails the whole command if any one is unreachable: a stale
# entry left over in a developer's config was enough to abort `just up`. `helmfile repos`
# runs `helm repo add --force-update` for the declared repositories only.
#
# Add and refresh only the Helm repositories declared in helmfile.yaml.gotmpl
repo-update:
    helmfile -e {{ENV}} repos

# Same as repo-update, kept for existing scripts
repo-add: repo-update


## 🧪 Testing & Debugging ##

# Lint the application charts behind the Helmfile apps releases
lint-all:
    #!/usr/bin/env bash
    set -euo pipefail
    helmfile -e {{ENV}} list --output json 2>/dev/null \
        | jq -r '.[] | select(.labels | split(",") | index("layer:apps")) | .chart' \
        | while read -r chart; do
            helm lint "$chart"
        done

# render every helmfile release without a cluster, failing on any template error
#
# `helm lint` above checks charts in isolation; this catches what it cannot — bad values
# overrides, cross-chart wiring and the `fail` guards in chart-libs (for example a
# non-public route that would be served over Ingress). Needs no cluster and no CRDs:
# helmDefaults.templateArgs in helmfile.yaml.gotmpl supplies the Gateway API version that
# would otherwise only come from a live cluster.
#
# Render every Helmfile release without a cluster and fail on any template error
template-all:
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

# Fail if any chart renders a credential into a ConfigMap
lint-secrets *ARGS:
    python3 scripts/lint-configmap-secrets.py {{ARGS}}

# Run the tests of the ConfigMap credential linter
test-lint-secrets:
    python3 -m pytest scripts/test_lint_configmap_secrets.py -q

# chart authoring checklist (item 30): ingress annotations, sub-path PV mounts,
# probe defaults, NetworkPolicy egress — a gate that runs, not prose
#
# Check the charts against the authoring checklist: ingress annotations, PV mounts, probes, egress policy
lint-authoring *ARGS:
    python3 scripts/lint-chart-authoring.py {{ARGS}}

# Run the tests of the chart authoring checklist
test-lint-authoring:
    python3 -m pytest scripts/test_lint_chart_authoring.py -q

# pin released image digests into a chart (what the release pipeline runs).
# Normally driven by the module-released event; use this to replay a release or
# pin a chart by hand. Pass every first-party image of the release.
#   just update-chart-images auditflow 1.4.0 \
#       --image labs64/auditflow@sha256:... \
#       --image labs64/auditflow-transformer@sha256:... \
#       --image labs64/auditflow-sink@sha256:...
#
# Pin released image digests into a chart, as the release pipeline does
update-chart-images chart version *ARGS:
    python3 scripts/update-chart-images.py --chart {{chart}} --app-version {{version}} {{ARGS}}

# Run the tests of the chart image updater
test-update-chart-images:
    python3 -m pytest scripts/test_update_chart_images.py -q

# bump a chart's version AND every chart that vendors it (chart-libs consumers, the
# labs64io-ecosystem umbrella) — chart CI rejects a change without these bumps.
#   just bump auditflow          # patch
#   just bump chart-libs minor
#
# Bump a chart's version and the version of every chart that vendors it
bump chart part="patch":
    python3 scripts/bump-chart-version.py {{chart}} {{part}}

# verify every changed chart (and every chart vendoring it) is bumped against a base ref —
# the same gate chart CI runs
#
# Check that every changed chart and every chart vendoring it is version-bumped against a base ref
check-bumps base="origin/master":
    python3 scripts/check-chart-version-bumps.py --base {{base}}

# Run the tests of the version-bump gate
test-check-bumps:
    python3 -m pytest scripts/test_check_chart_version_bumps.py -q

# Render one application exactly as Helmfile would install it, with all value layers
template app:
    helmfile -e {{ENV}} $(just _observability-args) template -l name=labs64io-{{app}}

# Show the diff between one application and the cluster, as Helmfile would apply it
diff app:
    helmfile -e {{ENV}} $(just _observability-args) diff -l name=labs64io-{{app}}

# Run helm test for one application
test app:
    helm test labs64io-{{app}} --namespace {{NAMESPACE_LABS64IO}}


## 🔧 Utilities & Operations ##

# Show pods, services and ingresses in the apps, tools and monitoring namespaces
status:
    @echo "\n=== Labs64.IO Apps ==="
    @kubectl get pods,svc,ingress -n {{NAMESPACE_LABS64IO}}
    @echo "\n=== Tools ==="
    @kubectl get pods,svc,ingress -n {{NAMESPACE_TOOLS}}
    @echo "\n=== Monitoring ==="
    @kubectl get pods,svc,ingress -n {{NAMESPACE_MONITORING}}

# Follow the logs of one application
logs app:
    kubectl logs -f -n {{NAMESPACE_LABS64IO}} -l app.kubernetes.io/name={{app}}

# Show warnings and errors from the Labs64.IO pod logs
logs-errors:
    kubectl --namespace {{NAMESPACE_LABS64IO}} logs -l app.kubernetes.io/part-of=Labs64.IO | grep -E 'WARN|ERROR|FATAL|FAILURE|FAILED' || true

# Restart one application with a rollout restart
restart app:
    kubectl rollout restart deployment labs64io-{{app}} -n {{NAMESPACE_LABS64IO}}

# Delete all persistent volume claims in the apps, tools and monitoring namespaces
clean-pvcs:
    kubectl delete pvc --all -n {{NAMESPACE_LABS64IO}} || true
    kubectl delete pvc --all -n {{NAMESPACE_TOOLS}} || true
    kubectl delete pvc --all -n {{NAMESPACE_MONITORING}} || true

# Open the Swagger UI of the local gateway in the browser
docs:
    open "http://gateway.localhost/swagger-ui/"

# Open the Traefik dashboard in the browser
traefik-dashboard:
    open "http://dashboard.localhost/dashboard/"

# Print the Grafana password and open Grafana in the browser
grafana:
    @just grafana-password
    @echo "Opening Grafana... (Press Ctrl+C to quit)"
    open http://gateway.localhost/grafana/ || echo "Visit http://gateway.localhost/grafana/"

# generate an M2M JWT from the selected identity provider (identityProvider).
# mock: pass a persona (admin|auditflow|ecommerce|no-access) for a curated scope set, or ANY exact
# scope string(s) to mint a token carrying precisely those scopes, e.g.
# `just generate-jwt audit-event:read` (echoed verbatim into the token).
# keycloak: a persona selects the realm client whose role grants that scope set (arbitrary scope
# strings are not a thing a real IdP does).
#
# Request an M2M JWT from the selected identity provider
generate-jwt scope="admin":
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "$(just identity-provider)" = "keycloak" ]; then
        case "{{scope}}" in
            admin) CLIENT=local-tooling; KEY=LOCAL_TOOLING_CLIENT_SECRET ;;
            auditflow) CLIENT=auditflow; KEY=AUDITFLOW_CLIENT_SECRET ;;
            ecommerce) CLIENT=payment-gateway; KEY=PAYMENT_GATEWAY_CLIENT_SECRET ;;
            no-access) CLIENT=preflight; KEY=PREFLIGHT_CLIENT_SECRET ;;
            *) echo "keycloak: persona must be admin|auditflow|ecommerce|no-access" >&2; exit 1 ;;
        esac
        SECRET=$(sed -n -E "s/^[[:space:]]*${KEY}:[[:space:]]*\"?([^\"]*)\"?[[:space:]]*$/\1/p" overrides/keycloak/values.secrets.{{ENV}}.yaml)
        curl -s -X POST 'http://keycloak.localhost/realms/labs64io/protocol/openid-connect/token' \
          --data-urlencode 'grant_type=client_credentials' \
          --data-urlencode "client_id=$CLIENT" \
          --data-urlencode "client_secret=$SECRET" | jq .
    else
        curl -s -X POST 'http://mock-oidc.localhost/labs64io/token' \
          -H 'Content-Type: application/x-www-form-urlencoded' \
          --data-urlencode 'grant_type=client_credentials' \
          --data-urlencode 'client_id=local-test' \
          --data-urlencode 'client_secret=local-test' \
          --data-urlencode 'scope={{scope}}' | jq .
    fi

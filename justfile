ENV := "local"
NAMESPACE_LABS64IO := "labs64io"
NAMESPACE_KUBE_SYSTEM := "kube-system"
NAMESPACE_MONITORING := "monitoring"
NAMESPACE_TOOLS := "tools"
HELM_DOCS_VERSION := "v1.14.2"
TRAEFIK_CHART_VERSION := "41.0.1"
TRAEFIK_CRDS_CHART_VERSION := "1.18.0"
GATEWAY_API_VERSION := "v1.6.0"
METRICS_SERVER_CHART_VERSION := "3.13.1"
RABBITMQ_CHART_VERSION := "16.0.14"
POSTGRESQL_CHART_VERSION := "18.7.11"
REDIS_CHART_VERSION := "27.0.13"
OTEL_OPERATOR_CHART_VERSION := "0.120.2"
OTEL_COLLECTOR_CHART_VERSION := "0.169.0"
PROMETHEUS_STACK_CHART_VERSION := "87.15.1"
TEMPO_CHART_VERSION := "1.24.4"
GRAFANA_CHART_VERSION := "10.5.15"
LOKI_CHART_VERSION := "6.24.0"

LABS64IO_APPS := "authz-pdp api-gateway api-docs auditflow checkout payment-gateway customer-portal mock-oidc"
# Apps carrying runtime OTel instrumentation (Java agent / opentelemetry-instrument).
# `up-otel` enables observability on these once the monitoring stack is present.
OBSERVABILITY_APPS := "api-gateway auditflow checkout payment-gateway"

# List available commands
default:
    @just --list

## 🚀 Getting Started (Cluster & Setup) ##

# create the local k3d cluster + registry only
cluster-up:
    k3d cluster create --config k3d/labs64io.yaml || true
    k3d kubeconfig merge -d labs64io
    if [ -f /.dockerenv ]; then perl -i -pe 's/server: https:\/\/0\.0\.0\.0/server: https:\/\/host.docker.internal/g' ~/.kube/config; fi
    if [ -f /.dockerenv ]; then perl -i -pe 's/server: https:\/\/127\.0\.0\.1/server: https:\/\/host.docker.internal/g' ~/.kube/config; fi

# start local k3d cluster + registry, install toolset and all Labs64.IO components
up: generate-secrets cluster-up
    just repo-update
    just install-tools
    just install-all-apps
    @echo "Local environment ready: http://gateway.localhost/swagger-ui/"

# start local environment with monitoring stack + module telemetry enabled
up-otel: up install-monitoring enable-observability

# reset the environment (uninstall all apps, monitoring, and tools) without destroying the cluster
reset: uninstall-all-apps uninstall-monitoring uninstall-tools

# delete the local k3d cluster (and its registry)
cluster-down: reset
    k3d cluster delete labs64io

# prune docker system (including volumes) without prompting
docker-system-prune:
    docker system prune -a --volumes -f

# enable OTel instrumentation on instrumented module apps (requires the monitoring
# stack — the collector DaemonSet must be running so OTLP export has a target).
# Kept off in the base `up` profile so a monitoring-less cluster shows no export errors.
# Once the collector exists, `install-app` re-enables observability automatically on
# every (re)install, so this recipe is only needed for the initial up-otel flip.
enable-observability:
    #!/usr/bin/env bash
    set -euo pipefail
    for app in {{OBSERVABILITY_APPS}}; do
        echo "=== Enabling observability: $app ==="
        helm upgrade labs64io-"$app" ./charts/"$app" \
          --namespace {{NAMESPACE_LABS64IO}} --reuse-values \
          --set observability.enabled=true
    done

# automatically scaffold missing local secrets from their .example templates
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
    helmfile -e {{ENV}} apply -l layer=apps

# Uninstall all Labs64.IO apps
uninstall-all-apps:
    #!/usr/bin/env bash
    set -euo pipefail
    for app in {{LABS64IO_APPS}}; do
        just uninstall-app "$app"
    done

# Install a specific Labs64.IO application
install-app app:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "=== Installing Labs64.IO App: {{app}} ==="
    helm dependencies update ./charts/{{app}}
    ARGS=(
      "--namespace" "{{NAMESPACE_LABS64IO}}"
      "--create-namespace"
      "-f" "./charts/{{app}}/values.yaml"
      "-f" "./overrides/global-values.yaml"
      "-f" "./overrides/{{app}}/values.{{ENV}}.yaml"
    )
    if [ -f "./overrides/{{app}}/values.secrets.{{ENV}}.yaml" ]; then
      echo "Using secrets override: overrides/{{app}}/values.secrets.{{ENV}}.yaml"
      ARGS+=("-f" "./overrides/{{app}}/values.secrets.{{ENV}}.yaml")
    fi
    # Observability follows the monitoring stack declaratively: if the OTel
    # collector is running and this app is instrumented, enable it on every
    # (re)install so a reinstall can never silently drop telemetry.
    if [[ " {{OBSERVABILITY_APPS}} " == *" {{app}} "* ]] \
       && kubectl get daemonset opentelemetry-collector-agent -n {{NAMESPACE_MONITORING}} >/dev/null 2>&1; then
      echo "Monitoring stack detected — enabling observability for {{app}}"
      ARGS+=("--set" "observability.enabled=true")
    fi
    helm upgrade --install labs64io-{{app}} ./charts/{{app}} "${ARGS[@]}" --force-conflicts


# Uninstall a specific Labs64.IO application
uninstall-app app:
    helm uninstall labs64io-{{app}} --namespace {{NAMESPACE_LABS64IO}} || true


## 🛠️ Core Tools ##

# Install all core tools
install-tools: install-crds
    helmfile -e {{ENV}} apply -l layer=infra
    kubectl apply -f overrides/traefik/dashboard-httproute.yaml
    kubectl apply -f overrides/mock-oidc/mock-oidc.yaml
    # The ClusterSecretStore goes through ESO's validating webhook — wait for it to be
    # ready first, since `helmfile apply` above returns as soon as objects are applied,
    # not once the webhook deployment is actually serving.
    kubectl -n {{NAMESPACE_TOOLS}} wait --for=condition=available --timeout=120s deployment/external-secrets-webhook
    kubectl apply -f overrides/eso/cluster-secret-store.yaml

# Uninstall all core tools
uninstall-tools: uninstall-tool-traefik uninstall-tool-external-secrets uninstall-tool-mock-oidc uninstall-tool-rabbitmq uninstall-tool-postgresql uninstall-tool-redis

# Install the Gateway API (standard channel) + Traefik CRDs before the `traefik` Helm
# release (Helmfile's release schema has no per-release skip-crds equivalent, and Helm
# never upgrades CRDs bundled in a chart's crds/ directory after first install — so these
# are managed here as an independently-versioned, re-appliable step. Helm/Helmfile only
# install a chart's bundled CRDs "if not already present", so pre-seeding them here means
# the `traefik` release's own bundled copies are simply skipped, no conflict).
install-crds:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Installing Gateway API (standard channel) CRDs..."
    kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/{{GATEWAY_API_VERSION}}/standard-install.yaml
    echo "Installing Traefik CRDs..."
    helm template traefik-crds traefik/traefik-crds --version {{TRAEFIK_CRDS_CHART_VERSION}} --namespace {{NAMESPACE_TOOLS}} | kubectl apply --server-side -f -

# install Traefik standalone (bypasses helmfile — for single-tool workflows only;
# `install-tools` uses helmfile for the actual release)
install-tool-traefik: install-crds
    helm upgrade --install traefik traefik/traefik --version {{TRAEFIK_CHART_VERSION}} -f overrides/traefik/values.{{ENV}}.yaml --namespace {{NAMESPACE_TOOLS}} --create-namespace --wait --skip-crds
    kubectl apply -f overrides/traefik/dashboard-httproute.yaml

# uninstall Traefik
uninstall-tool-traefik:
    helm uninstall traefik --namespace {{NAMESPACE_TOOLS}} || true

# uninstall External Secrets Operator + the local ClusterSecretStore/RBAC it serves
uninstall-tool-external-secrets:
    kubectl delete -f overrides/eso/cluster-secret-store.yaml --ignore-not-found
    helm uninstall external-secrets --namespace {{NAMESPACE_TOOLS}} || true

# install RabbitMQ (official image; standalone, bypasses helmfile/the bitnami chart)
install-tool-rabbitmq:
	@echo "Installing RabbitMQ (official image)..."
	kubectl apply -n {{NAMESPACE_TOOLS}} -f overrides/rabbitmq/rabbitmq-secret.yaml
	kubectl apply -n {{NAMESPACE_TOOLS}} -f overrides/rabbitmq/rabbitmq.yaml
	@echo "Waiting for RabbitMQ to be ready..."
	kubectl wait --namespace {{NAMESPACE_TOOLS}} --for=condition=ready pod -l app=rabbitmq --timeout=120s
	@echo "Username      : labs64"
	@echo "Credentials   : from overrides/rabbitmq/rabbitmq-secret.yaml (rabbitmq-secret)"

# uninstall RabbitMQ
uninstall-tool-rabbitmq:
	kubectl delete -f overrides/rabbitmq/rabbitmq.yaml --namespace {{NAMESPACE_TOOLS}} --ignore-not-found
	kubectl delete -f overrides/rabbitmq/rabbitmq-secret.yaml --namespace {{NAMESPACE_TOOLS}} --ignore-not-found || true
	kubectl delete pvc -l app=rabbitmq --namespace {{NAMESPACE_TOOLS}} --ignore-not-found

# install PostgreSQL
install-tool-postgresql:
    helm upgrade --install postgresql bitnami/postgresql \
      --version {{POSTGRESQL_CHART_VERSION}} \
      -f overrides/postgresql/values.{{ENV}}.yaml \
      --namespace {{NAMESPACE_TOOLS}} --create-namespace --wait
    @echo "PostgreSQL pod(s):" && kubectl get pods --namespace {{NAMESPACE_TOOLS}} -l app.kubernetes.io/instance=postgresql
    @echo "postgres password : $(kubectl get secret --namespace {{NAMESPACE_TOOLS}} postgresql -o jsonpath='{.data.postgres-password}' | base64 -d 2>/dev/null || kubectl get secret --namespace {{NAMESPACE_TOOLS}} postgresql -o jsonpath='{.data.postgresql-password}' | base64 -d)"
    @echo "user password     : $(kubectl get secret --namespace {{NAMESPACE_TOOLS}} postgresql -o jsonpath='{.data.password}' | base64 -d 2>/dev/null || true)"

# uninstall PostgreSQL
uninstall-tool-postgresql:
    helm uninstall postgresql --namespace {{NAMESPACE_TOOLS}} || true

# install Redis
install-tool-redis:
    helm upgrade --install redis bitnami/redis --version {{REDIS_CHART_VERSION}} -f overrides/redis/values.{{ENV}}.yaml --namespace {{NAMESPACE_TOOLS}} --create-namespace --wait

# uninstall Redis
uninstall-tool-redis:
    helm uninstall redis --namespace {{NAMESPACE_TOOLS}} || true

# install mock OIDC provider (DEV ONLY - M2M tokens for local testing)
install-tool-mock-oidc:
    kubectl apply -f overrides/mock-oidc/mock-oidc.yaml
    kubectl apply -f overrides/eso/cluster-secret-store.yaml

# uninstall mock OIDC provider
uninstall-tool-mock-oidc:
    kubectl delete -f overrides/mock-oidc/mock-oidc.yaml || true


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
install-monitoring-crds:
    helm show crds prometheus-community/kube-prometheus-stack --version {{PROMETHEUS_STACK_CHART_VERSION}} | kubectl apply --server-side -f -

# Uninstall all monitoring tools
uninstall-monitoring: uninstall-tool-grafana uninstall-tool-tempo uninstall-tool-loki uninstall-tool-prometheus uninstall-tool-opentelemetry uninstall-tool-metrics-server

# install Metrics Server
install-tool-metrics-server:
    helm upgrade --install metrics-server metrics-server/metrics-server \
      --version {{METRICS_SERVER_CHART_VERSION}} \
      -f overrides/metrics-server/values.{{ENV}}.yaml \
      --namespace {{NAMESPACE_KUBE_SYSTEM}} \
      --set args="{--kubelet-insecure-tls}" || echo "metrics-server install failed (possibly pre-installed), continuing"

# uninstall Metrics Server
uninstall-tool-metrics-server:
    helm uninstall metrics-server --namespace {{NAMESPACE_KUBE_SYSTEM}} || true

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
validate-otel-config:
    #!/usr/bin/env bash
    set -euo pipefail
    VALUES="overrides/opentelemetry/values-collector.{{ENV}}.yaml"
    WORK="$(mktemp -d)"
    trap 'rm -rf "$WORK"; docker rm -f otel-cfg-validate >/dev/null 2>&1 || true; docker volume rm otel-cfg-validate-vol >/dev/null 2>&1 || true' EXIT

    IMAGE="$(python3 -c "import sys,re;s=open('$VALUES').read();r=re.search(r'^image:\s*$\n(?:\s+.*\n)*?\s+repository:\s*(\S+)',s,re.M);t=re.search(r'^image:\s*$\n(?:\s+.*\n)*?\s+tag:\s*(\S+)',s,re.M);print(f'{r.group(1)}:{t.group(1)}')")"
    echo "=== validating against $IMAGE ==="

    helm template opentelemetry-collector open-telemetry/opentelemetry-collector \
      --version {{OTEL_COLLECTOR_CHART_VERSION}} \
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

# install Open Telemetry
install-tool-opentelemetry: validate-otel-config
    helm upgrade --install opentelemetry-operator open-telemetry/opentelemetry-operator \
      --version {{OTEL_OPERATOR_CHART_VERSION}} \
      -f overrides/opentelemetry/values-operator.{{ENV}}.yaml \
      --namespace {{NAMESPACE_MONITORING}} --create-namespace --wait
    helm upgrade --install opentelemetry-collector open-telemetry/opentelemetry-collector \
      --version {{OTEL_COLLECTOR_CHART_VERSION}} \
      -f overrides/opentelemetry/values-collector.{{ENV}}.yaml \
      --namespace {{NAMESPACE_MONITORING}} --create-namespace --wait

# uninstall Open Telemetry
uninstall-tool-opentelemetry:
    helm uninstall opentelemetry-operator --namespace {{NAMESPACE_MONITORING}} || true
    helm uninstall opentelemetry-collector --namespace {{NAMESPACE_MONITORING}} || true

# install Prometheus
install-tool-prometheus:
    helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
      --version {{PROMETHEUS_STACK_CHART_VERSION}} \
      -f overrides/prometheus/values.{{ENV}}.yaml \
      --namespace {{NAMESPACE_MONITORING}} --create-namespace
    kubectl --namespace {{NAMESPACE_MONITORING}} get pods,svc -l "release=prometheus"

# uninstall Prometheus
uninstall-tool-prometheus:
    helm uninstall prometheus --namespace {{NAMESPACE_MONITORING}} || true

# install Loki
install-tool-loki:
    helm upgrade --install loki grafana/loki \
      --version {{LOKI_CHART_VERSION}} \
      -f overrides/loki/values.{{ENV}}.yaml \
      --namespace {{NAMESPACE_MONITORING}} --create-namespace

# uninstall Loki
uninstall-tool-loki:
    helm uninstall loki --namespace {{NAMESPACE_MONITORING}} || true

# install Tempo
install-tool-tempo:
    helm upgrade --install tempo grafana/tempo \
      --version {{TEMPO_CHART_VERSION}} \
      -f overrides/tempo/values.{{ENV}}.yaml \
      --namespace {{NAMESPACE_MONITORING}} --create-namespace

# uninstall Tempo
uninstall-tool-tempo:
    helm uninstall tempo --namespace {{NAMESPACE_MONITORING}} || true

# install Grafana
install-tool-grafana:
    helm upgrade --install grafana grafana/grafana \
      --version {{GRAFANA_CHART_VERSION}} \
      -f overrides/grafana/values.{{ENV}}.yaml \
      --namespace {{NAMESPACE_MONITORING}} --create-namespace
    kubectl apply -f overrides/grafana/grafana-httproute.yaml
    kubectl apply -f overrides/grafana/grafana-dashboards.yaml

# uninstall Grafana
uninstall-tool-grafana:
    helm uninstall grafana --namespace {{NAMESPACE_MONITORING}} || true

# retrieve Grafana password
grafana-password:
    @echo "Password: " && kubectl get secret --namespace {{NAMESPACE_MONITORING}} grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo


## 🏗️ Build & CodeGen ##

# Install required Helm plugins
helm-tools:
    @helm plugin install --verify=false https://github.com/databus23/helm-diff --version v3.15.11 2>/dev/null || true
    @helm plugin install --verify=false https://github.com/dadav/helm-schema 2>/dev/null || true
    @echo "Installed Helm plugins:"
    @helm plugin list

# Generate Helm chart documentation (README.md) for all charts
generate-docu:
    docker run --rm \
        --volume "$(pwd):/helm-docs" \
        --user "$(id -u):$(id -g)" \
        jnorwood/helm-docs:{{ HELM_DOCS_VERSION }} \
        --chart-search-root ./charts \
        --log-level warning

# Generate Helm values schema (values.schema.json) for all charts
#
# helm-schema exits non-zero when it cannot parse a *vendored subchart's* own
# @schema comments: Traefik's values.yaml uses a single-line
# `@schema type: [boolean, null]` form its parser rejects. It still writes every
# schema in this repo correctly, so the run is judged by its output rather than its
# exit code — fail only when a chart ends up without a schema. (--dependencies-filter
# silences the message but writes 1 schema instead of 11; do not "fix" it that way.)
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

# Generate all — Helm charts docs and schema
generate-all: generate-docu generate-schema

# Generate the Cerbos policy set + authproxy routes manifests from module OpenAPI
# specs. Writes charts/authz-pdp/{policies,schemas} + charts/api-gateway/routes.
build-policies:
    ./policies/build-authz-policies.sh

# add external helm repositories
repo-add:
    helm repo add labs64io https://labs64.github.io/labs64.io-helm-charts
    helm repo add traefik https://traefik.github.io/charts
    helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# update helm repositories
#
# Named explicitly rather than a bare `helm repo update`, which updates EVERY repo in the
# caller's local helm config and fails the whole command if any one is unreachable. A
# stale external-secrets entry left over in a developer's config was enough to abort
# `just up` even though repo-add never declared it and nothing here pulls from it.
repo-update: repo-add
    helm repo update \
      labs64io traefik metrics-server bitnami \
      open-telemetry grafana prometheus-community


## 🧪 Testing & Debugging ##

# lint all application charts
lint-all:
    #!/usr/bin/env bash
    set -euo pipefail
    for app in {{LABS64IO_APPS}}; do
        helm lint ./charts/"$app"
    done

# render every helmfile release without a cluster, failing on any template error
#
# `helm lint` above checks charts in isolation; this catches what it cannot — bad values
# overrides, cross-chart wiring and the `fail` guards in chart-libs (for example a
# non-public route that would be served over Ingress). Needs no cluster and no CRDs:
# helmDefaults.templateArgs in helmfile.yaml.gotmpl supplies the Gateway API version that
# would otherwise only come from a live cluster.
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

# fail if any chart renders a credential into a ConfigMap (guardrail 3)
lint-secrets *ARGS:
    python3 scripts/lint-configmap-secrets.py {{ARGS}}

# test the ConfigMap credential linter itself
test-lint-secrets:
    python3 -m pytest scripts/test_lint_configmap_secrets.py -q

# chart authoring checklist (item 30): ingress annotations, sub-path PV mounts,
# probe defaults, NetworkPolicy egress — a gate that runs, not prose
lint-authoring *ARGS:
    python3 scripts/lint-chart-authoring.py {{ARGS}}

# test the chart authoring checklist itself
test-lint-authoring:
    python3 -m pytest scripts/test_lint_chart_authoring.py -q

# pin released image digests into a chart (what the release pipeline runs).
# Normally driven by the module-released event; use this to replay a release or
# pin a chart by hand. Pass every first-party image of the release.
#   just update-chart-images auditflow 1.4.0 \
#       --image labs64/auditflow@sha256:... \
#       --image labs64/auditflow-transformer@sha256:... \
#       --image labs64/auditflow-sink@sha256:...
update-chart-images chart version *ARGS:
    python3 scripts/update-chart-images.py --chart {{chart}} --app-version {{version}} {{ARGS}}

# test the chart image updater itself
test-update-chart-images:
    python3 -m pytest scripts/test_update_chart_images.py -q

# run helm template for an application locally to inspect output
template app:
    helm template labs64io-{{app}} ./charts/{{app}} \
      --namespace {{NAMESPACE_LABS64IO}} \
      -f ./charts/{{app}}/values.yaml \
      -f ./overrides/{{app}}/values.{{ENV}}.yaml

# run helm diff for an application (requires helm-diff plugin)
diff app:
    helm diff upgrade labs64io-{{app}} ./charts/{{app}} \
      --namespace {{NAMESPACE_LABS64IO}} \
      --allow-unreleased \
      -f ./charts/{{app}}/values.yaml \
      -f ./overrides/{{app}}/values.{{ENV}}.yaml

# test an application using helm test
test app:
    helm test labs64io-{{app}} --namespace {{NAMESPACE_LABS64IO}}


## 🔧 Utilities & Operations ##

# show overall cluster status (pods, services, ingresses) across key namespaces
status:
    @echo "\n=== Labs64.IO Apps ==="
    @kubectl get pods,svc,ingress -n {{NAMESPACE_LABS64IO}}
    @echo "\n=== Tools ==="
    @kubectl get pods,svc,ingress -n {{NAMESPACE_TOOLS}}
    @echo "\n=== Monitoring ==="
    @kubectl get pods,svc,ingress -n {{NAMESPACE_MONITORING}}

# show logs for a specific application in real-time
logs app:
    kubectl logs -f -n {{NAMESPACE_LABS64IO}} -l app.kubernetes.io/name={{app}}

# show errors in Labs64.IO kubectl logs
logs-errors:
    kubectl --namespace {{NAMESPACE_LABS64IO}} logs -l app.kubernetes.io/part-of=Labs64.IO | grep -E 'WARN|ERROR|FATAL|FAILURE|FAILED' || true

# rollout restart a specific application
restart app:
    kubectl rollout restart deployment labs64io-{{app}} -n {{NAMESPACE_LABS64IO}}

# clean all PVCs in the cluster (use with caution!)
clean-pvcs:
    kubectl delete pvc --all -n {{NAMESPACE_LABS64IO}} || true
    kubectl delete pvc --all -n {{NAMESPACE_TOOLS}} || true
    kubectl delete pvc --all -n {{NAMESPACE_MONITORING}} || true

# Labs64.IO :: Documentation
docs:
    open "http://gateway.localhost/swagger-ui/"

# Traefik Dashboard
traefik-dashboard:
    open "http://dashboard.localhost/dashboard/"

# open grafana and print password
grafana:
    @just grafana-password
    @echo "Opening Grafana... (Press Ctrl+C to quit)"
    open http://gateway.localhost/grafana/ || echo "Visit http://gateway.localhost/grafana/"

# generate an M2M JWT from the mock OIDC provider.
# Pass a persona (admin|auditflow|ecommerce|no-access) for a curated scope set,
# or ANY exact scope string(s) to mint a token carrying precisely those scopes,
# e.g. `just generate-jwt audit-event:read` (echoed verbatim into the token).
generate-jwt scope="admin":
    curl -s -X POST 'http://mock-oidc.localhost/labs64io/token' \
      -H 'Content-Type: application/x-www-form-urlencoded' \
      --data-urlencode 'grant_type=client_credentials' \
      --data-urlencode 'client_id=local-test' \
      --data-urlencode 'client_secret=local-test' \
      --data-urlencode 'scope={{scope}}' | jq .

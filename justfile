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
OTEL_OPERATOR_CHART_VERSION := "0.119.0"
OTEL_COLLECTOR_CHART_VERSION := "0.165.0"
PROMETHEUS_STACK_CHART_VERSION := "87.15.1"
TEMPO_CHART_VERSION := "1.24.4"
GRAFANA_CHART_VERSION := "10.5.15"
LOKI_CHART_VERSION := "6.24.0"

LABS64IO_APPS := "traefik-authproxy gateway-common swagger-ui auditflow checkout checkout-ui payment-gateway customer-portal-ui"
# Apps carrying runtime OTel instrumentation (Java agent / opentelemetry-instrument).
# `up-full` enables observability on these once the monitoring stack is present.
OBSERVABILITY_APPS := "traefik-authproxy auditflow checkout payment-gateway"

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
up-full: up install-monitoring enable-observability

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
# every (re)install, so this recipe is only needed for the initial up-full flip.
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
    #!/usr/bin/env bash
    set -euo pipefail
    for app in {{LABS64IO_APPS}}; do
        just install-app "$app"
    done

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

# Install a single Labs64.IO application standalone (bundled infra, no swagger-ui stack)
install-app-standalone app:
    helm dependencies update ./charts/{{app}}
    helm upgrade --install labs64io-{{app}} ./charts/{{app}} \
      --namespace {{NAMESPACE_LABS64IO}} --create-namespace \
      -f ./charts/{{app}}/values.yaml \
      --force-conflicts \
      -f ./overrides/{{app}}/values.standalone.yaml

# Uninstall a specific Labs64.IO application
uninstall-app app:
    helm uninstall labs64io-{{app}} --namespace {{NAMESPACE_LABS64IO}} || true


## 🛠️ Core Tools ##

# Install all core tools
install-tools: install-tool-traefik install-tool-mock-oidc install-tool-rabbitmq install-tool-postgresql install-tool-redis

# Uninstall all core tools
uninstall-tools: uninstall-tool-traefik uninstall-tool-mock-oidc uninstall-tool-rabbitmq uninstall-tool-postgresql uninstall-tool-redis

# install Traefik
install-tool-traefik:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Installing Gateway API (standard channel) CRDs..."
    kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/{{GATEWAY_API_VERSION}}/standard-install.yaml
    echo "Installing Traefik CRDs..."
    helm template traefik-crds traefik/traefik-crds --version {{TRAEFIK_CRDS_CHART_VERSION}} --namespace {{NAMESPACE_TOOLS}} | kubectl apply --server-side -f -
    helm upgrade --install traefik traefik/traefik --version {{TRAEFIK_CHART_VERSION}} -f overrides/traefik/values.{{ENV}}.yaml --namespace {{NAMESPACE_TOOLS}} --create-namespace --wait --skip-crds
    kubectl apply -f overrides/traefik/dashboard-httproute.yaml

# uninstall Traefik
uninstall-tool-traefik:
    helm uninstall traefik --namespace {{NAMESPACE_TOOLS}} || true
    helm uninstall traefik-crds --namespace {{NAMESPACE_TOOLS}} || true

# install RabbitMQ (official image)
install-tool-rabbitmq:
	@echo "Installing RabbitMQ (official image)..."
	kubectl apply -n {{NAMESPACE_TOOLS}} -f overrides/rabbitmq/values.secrets.local.yaml
	kubectl apply -n {{NAMESPACE_TOOLS}} -f overrides/rabbitmq/rabbitmq.yaml
	@echo "Waiting for RabbitMQ to be ready..."
	kubectl wait --namespace {{NAMESPACE_TOOLS}} --for=condition=ready pod -l app=rabbitmq --timeout=120s
	@echo "Username      : labs64"
	@echo "Credentials   : from overrides/rabbitmq/values.secrets.local.yaml (rabbitmq-secret)"

# uninstall RabbitMQ
uninstall-tool-rabbitmq:
	kubectl delete -f overrides/rabbitmq/rabbitmq.yaml --namespace {{NAMESPACE_TOOLS}} --ignore-not-found
	kubectl delete -f overrides/rabbitmq/values.secrets.local.yaml --namespace {{NAMESPACE_TOOLS}} --ignore-not-found
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

# uninstall mock OIDC provider
uninstall-tool-mock-oidc:
    kubectl delete -f overrides/mock-oidc/mock-oidc.yaml || true


## 📊 Monitoring Tools ##

# Install all monitoring tools
install-monitoring: install-tool-metrics-server install-tool-opentelemetry install-tool-prometheus install-tool-loki install-tool-tempo install-tool-grafana

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

# install Open Telemetry
install-tool-opentelemetry:
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
    @helm plugin install --verify=false https://github.com/databus23/helm-diff 2>/dev/null || true
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
generate-schema: helm-tools
    helm schema \
        --chart-search-root ./charts \
        --no-dependencies \
        --append-newline

# Generate all — Helm charts docs and schema
generate-all: generate-docu generate-schema

# add external helm repositories
repo-add:
    helm repo add labs64io-pub https://labs64.github.io/labs64.io-helm-charts
    helm repo add traefik https://traefik.github.io/charts
    helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# update helm repositories
repo-update: repo-add
    helm repo update


## 🧪 Testing & Debugging ##

# lint all application charts
lint-all:
    #!/usr/bin/env bash
    set -euo pipefail
    for app in {{LABS64IO_APPS}}; do
        helm lint ./charts/"$app"
    done

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
show-errors:
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

ENV := "local"
NAMESPACE_LABS64IO := "labs64io"
NAMESPACE_KUBE_SYSTEM := "kube-system"
NAMESPACE_MONITORING := "monitoring"
NAMESPACE_TOOLS := "tools"
HELM_DOCS_VERSION := "v1.14.2"
TRAEFIK_CHART_VERSION := "41.0.1"
TRAEFIK_CRDS_CHART_VERSION := "1.18.0"
METRICS_SERVER_CHART_VERSION := "3.13.1"
RABBITMQ_CHART_VERSION := "16.0.14"
POSTGRESQL_CHART_VERSION := "18.7.11"
REDIS_CHART_VERSION := "27.0.13"
OTEL_OPERATOR_CHART_VERSION := "0.118.0"
OTEL_COLLECTOR_CHART_VERSION := "0.162.0"
PROMETHEUS_STACK_CHART_VERSION := "87.5.1"
TEMPO_CHART_VERSION := "1.24.4"
GRAFANA_CHART_VERSION := "10.5.15"

LABS64IO_APPS := "traefik-authproxy gateway-common gateway auditflow checkout checkout-ui payment-gateway customer-portal-ui"

# List available commands
default:
    @just --list

## 🚀 Getting Started (Cluster & Setup) ##

# start local k3d cluster + registry, install toolset and all Labs64.IO components
up: generate-secrets cluster-create
    just repo-update
    just install-tools
    just install-all-apps
    @echo "Local environment ready: http://gateway.localhost/swagger-ui/"

# create the local k3d cluster + registry only
cluster-create:
    k3d cluster create --config k3d/labs64io.yaml || true
    k3d kubeconfig merge -d labs64io
    if [ -f /.dockerenv ]; then perl -i -pe 's/server: https:\/\/0\.0\.0\.0/server: https:\/\/host.docker.internal/g' ~/.kube/config; fi
    if [ -f /.dockerenv ]; then perl -i -pe 's/server: https:\/\/127\.0\.0\.1/server: https:\/\/host.docker.internal/g' ~/.kube/config; fi

# delete the local k3d cluster (and its registry)
down:
    k3d cluster delete labs64io

# reset the environment (uninstall all apps, monitoring, and tools) without destroying the cluster
reset: uninstall-all-apps uninstall-monitoring uninstall-tools

# start local environment with monitoring stack
up-full: up install-monitoring

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
    helm upgrade --install labs64io-{{app}} ./charts/{{app}} "${ARGS[@]}"

# Install a single Labs64.IO application standalone (bundled infra, no gateway stack)
install-app-standalone app:
    helm dependencies update ./charts/{{app}}
    helm upgrade --install labs64io-{{app}} ./charts/{{app}} \
      --namespace {{NAMESPACE_LABS64IO}} --create-namespace \
      -f ./charts/{{app}}/values.yaml \
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
    if helm upgrade --install traefik-crds traefik/traefik-crds --version {{TRAEFIK_CRDS_CHART_VERSION}} --namespace {{NAMESPACE_TOOLS}} --create-namespace 2>/dev/null; then
      EXTRA_ARGS=()
    else
      echo "traefik-crds chart failed (likely existing CRDs without Helm tracking) — adopting CRDs and skipping CRD install"
      for crd in $(kubectl get crd -o name 2>/dev/null | grep traefik || true); do
        kubectl annotate "$crd" meta.helm.sh/release-name=traefik meta.helm.sh/release-namespace={{NAMESPACE_TOOLS}} --overwrite 2>/dev/null || true
        kubectl label "$crd" app.kubernetes.io/managed-by=Helm --overwrite 2>/dev/null || true
      done
      EXTRA_ARGS=(--skip-crds)
    fi
    helm upgrade --install traefik traefik/traefik --version {{TRAEFIK_CHART_VERSION}} -f overrides/traefik/values.{{ENV}}.yaml --namespace {{NAMESPACE_TOOLS}} --create-namespace --wait "${EXTRA_ARGS[@]}"

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
install-monitoring: install-tool-metrics-server install-tool-opentelemetry install-tool-prometheus install-tool-tempo install-tool-grafana

# Uninstall all monitoring tools
uninstall-monitoring: uninstall-tool-grafana uninstall-tool-tempo uninstall-tool-prometheus uninstall-tool-opentelemetry uninstall-tool-metrics-server

# install Metrics Server
install-tool-metrics-server:
    helm upgrade --install metrics-server metrics-server/metrics-server \
      --version {{METRICS_SERVER_CHART_VERSION}} \
      -f overrides/metrics-server/values.{{ENV}}.yaml \
      --namespace {{NAMESPACE_KUBE_SYSTEM}} \
      --set args="{--kubelet-insecure-tls}"

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
    @echo "Run this command to open Grafana: kubectl port-forward svc/grafana --namespace {{NAMESPACE_MONITORING}} 3000:80"
    @just grafana-password

# retrieve Grafana password
grafana-password:
    @echo "Username: admin"
    @echo "Password: " && kubectl get secret --namespace {{NAMESPACE_MONITORING}} grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

# uninstall Grafana
uninstall-tool-grafana:
    helm uninstall grafana --namespace {{NAMESPACE_MONITORING}} || true


## 🏗️ Build & CodeGen ##

# Build and push all module images to local registry (localhost:5005)
build-images module="all":
	./scripts/build-images.sh {{module}}

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

# end-to-end auth smoke test through Traefik
e2e-auth-test:
    #!/usr/bin/env bash
    set -euo pipefail
    TOKEN=$(curl -s -X POST 'http://mock-oidc.localhost/labs64io/token' \
      --data-urlencode 'grant_type=client_credentials' \
      --data-urlencode 'client_id=e2e' --data-urlencode 'client_secret=e2e' \
      --data-urlencode 'scope=admin' | jq -r '.access_token')
    no_token=$(curl -s -o /dev/null -w '%{http_code}' 'http://gateway.localhost/auditflow/api/v1/audit/publish')
    with_token=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $TOKEN" 'http://gateway.localhost/auditflow/api/v1/audit/publish')
    BAD_TOKEN=$(curl -s -X POST 'http://mock-oidc.localhost/labs64io/token' \
      --data-urlencode 'grant_type=client_credentials' \
      --data-urlencode 'client_id=e2e' --data-urlencode 'client_secret=e2e' \
      --data-urlencode 'scope=no-access' | jq -r '.access_token')
    wrong_scope=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $BAD_TOKEN" 'http://gateway.localhost/auditflow/api/v1/audit/publish')
    echo "no token   -> $no_token (expected 401)"
    echo "with token -> $with_token (expected not 401/403)"
    echo "wrong scope -> $wrong_scope (expected 403)"
    [ "$no_token" = "401" ] || { echo "FAIL: expected 401 without token"; exit 1; }
    case "$with_token" in 401|403) echo "FAIL: token rejected"; exit 1;; esac
    [ "$wrong_scope" = "403" ] || { echo "FAIL: expected 403 for wrong-scope token"; exit 1; }
    echo "e2e auth: OK"

# generate an M2M JWT from the mock OIDC provider (scope: admin|auditflow|ecommerce)
generate-jwt scope="admin":
    curl -s -X POST 'http://mock-oidc.localhost/labs64io/token' \
      -H 'Content-Type: application/x-www-form-urlencoded' \
      --data-urlencode 'grant_type=client_credentials' \
      --data-urlencode 'client_id=local-test' \
      --data-urlencode 'client_secret=local-test' \
      --data-urlencode 'scope={{scope}}' | jq .

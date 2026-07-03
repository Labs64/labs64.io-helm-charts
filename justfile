ENV := "local"
NAMESPACE_LABS64IO := "labs64io"
NAMESPACE_INGRESS := "ingress-nginx"
NAMESPACE_KUBE_SYSTEM := "kube-system"
NAMESPACE_MONITORING := "monitoring"
NAMESPACE_TOOLS := "tools"
HELM_DOCS_VERSION := "v1.14.2"
TRAEFIK_CHART_VERSION := "41.0.1"
TRAEFIK_CRDS_CHART_VERSION := "1.18.0"
METRICS_SERVER_CHART_VERSION := "3.13.1"
RABBITMQ_CHART_VERSION := "16.0.14"
POSTGRESQL_CHART_VERSION := "16.7.27"
REDIS_CHART_VERSION := "20.13.4"
KEYCLOAK_CHART_VERSION := "25.2.0"
OTEL_OPERATOR_CHART_VERSION := "0.118.0"
OTEL_COLLECTOR_CHART_VERSION := "0.162.0"
PROMETHEUS_STACK_CHART_VERSION := "87.5.1"
TEMPO_CHART_VERSION := "1.24.4"
GRAFANA_CHART_VERSION := "10.5.15"
INGRESS_NGINX_CHART_VERSION := "4.15.1"

## Useful Commands ##

# setup docker registry (precondition)
docker-registry-install:
    docker run -d -p 5005:5000 --restart=always --name registry registry:2

# show helm releases
helm-ls:
    helm ls --all-namespaces

# show pods, services in all namespaces
kubectl-pods:
    kubectl get svc,pods --all-namespaces -o wide

# show persistent volumes and claims in all namespaces
kubectl-pv:
    kubectl get pv,pvc --all-namespaces -o wide

# add external helm repositories
repo-add:
    helm repo add labs64io-pub https://labs64.github.io/labs64.io-helm-charts
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo add traefik https://traefik.github.io/charts
    helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# update helm repositories
repo-update: repo-add
    helm repo update

# show repositories versions
repo-search: repo-update
    helm search repo


## Labs64.IO Components ##

# Install required Helm plugins
helm-tools:
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

# install Labs64.IO :: API Gateway
labs64io-traefik-authproxy-install:
    helm dependencies update ./charts/traefik-authproxy
    helm upgrade --install labs64io-traefik-authproxy ./charts/traefik-authproxy \
      --namespace {{NAMESPACE_LABS64IO}} --create-namespace \
      -f ./charts/traefik-authproxy/values.yaml \
      -f ./overrides/traefik-authproxy/values.{{ENV}}.yaml

# uninstall Labs64.IO :: API Gateway
labs64io-traefik-authproxy-uninstall:
    helm uninstall labs64io-traefik-authproxy --namespace {{NAMESPACE_LABS64IO}}

# install Labs64.IO :: Swagger UI / Gateway
labs64io-gateway-install:
    helm dependencies update ./charts/gateway
    helm upgrade --install labs64io-gateway ./charts/gateway \
      --namespace {{NAMESPACE_LABS64IO}} --create-namespace \
      -f ./charts/gateway/values.yaml \
      -f ./overrides/gateway/values.{{ENV}}.yaml

# uninstall Labs64.IO :: Swagger UI / Gateway
labs64io-gateway-uninstall:
    helm uninstall labs64io-gateway --namespace {{NAMESPACE_LABS64IO}}

# install Labs64.IO :: Gateway Common (shared Traefik middlewares)
labs64io-gateway-common-install:
    helm dependencies update ./charts/gateway-common
    helm upgrade --install labs64io-gateway-common ./charts/gateway-common \
      --namespace {{NAMESPACE_LABS64IO}} --create-namespace \
      -f ./charts/gateway-common/values.yaml \
      -f ./overrides/gateway-common/values.{{ENV}}.yaml

# uninstall Labs64.IO :: Gateway Common
labs64io-gateway-common-uninstall:
    helm uninstall labs64io-gateway-common --namespace {{NAMESPACE_LABS64IO}}

# install Labs64.IO :: AuditFlow
labs64io-auditflow-install:
    helm dependencies update ./charts/auditflow
    helm upgrade --install labs64io-auditflow ./charts/auditflow \
      --namespace {{NAMESPACE_LABS64IO}} --create-namespace \
      -f ./charts/auditflow/values.yaml \
      -f ./overrides/auditflow/values.{{ENV}}.yaml \
      -f ./overrides/auditflow/values.secrets.{{ENV}}.yaml

# uninstall Labs64.IO :: AuditFlow
labs64io-auditflow-uninstall:
    helm uninstall labs64io-auditflow --namespace {{NAMESPACE_LABS64IO}}

# install Labs64.IO :: Checkout
labs64io-checkout-install:
    helm dependencies update ./charts/checkout
    helm upgrade --install labs64io-checkout ./charts/checkout \
      --namespace {{NAMESPACE_LABS64IO}} --create-namespace \
      -f ./charts/checkout/values.yaml \
      -f ./overrides/checkout/values.{{ENV}}.yaml

# uninstall Labs64.IO :: Checkout
labs64io-checkout-uninstall:
    helm uninstall labs64io-checkout --namespace {{NAMESPACE_LABS64IO}}

# install Labs64.IO :: Checkout UI
labs64io-checkout-ui-install:
    helm dependencies update ./charts/checkout-ui
    helm upgrade --install labs64io-checkout-ui ./charts/checkout-ui \
      --namespace {{NAMESPACE_LABS64IO}} --create-namespace \
      -f ./charts/checkout-ui/values.yaml \
      -f ./overrides/checkout-ui/values.{{ENV}}.yaml

# uninstall Labs64.IO :: Checkout UI
labs64io-checkout-ui-uninstall:
    helm uninstall labs64io-checkout-ui --namespace {{NAMESPACE_LABS64IO}}

# install Labs64.IO :: Payment Gateway
labs64io-payment-gateway-install:
    helm dependencies update ./charts/payment-gateway
    helm upgrade --install labs64io-payment-gateway ./charts/payment-gateway \
      --namespace {{NAMESPACE_LABS64IO}} --create-namespace \
      -f ./charts/payment-gateway/values.yaml \
      -f ./overrides/payment-gateway/values.{{ENV}}.yaml

# uninstall Labs64.IO :: Payment Gateway
labs64io-payment-gateway-uninstall:
    helm uninstall labs64io-payment-gateway --namespace {{NAMESPACE_LABS64IO}}

# install Labs64.IO :: Customer Portal UI
labs64io-customer-portal-ui-install:
    helm dependencies update ./charts/customer-portal-ui
    helm upgrade --install labs64io-customer-portal-ui ./charts/customer-portal-ui \
      --namespace {{NAMESPACE_LABS64IO}} --create-namespace \
      -f ./charts/customer-portal-ui/values.yaml \
      -f ./overrides/customer-portal-ui/values.{{ENV}}.yaml

# uninstall Labs64.IO :: Customer Portal UI
labs64io-customer-portal-ui-uninstall:
    helm uninstall labs64io-customer-portal-ui --namespace {{NAMESPACE_LABS64IO}}

# install Labs64.IO :: all components
labs64io-all-install: labs64io-traefik-authproxy-install labs64io-gateway-common-install labs64io-gateway-install labs64io-auditflow-install labs64io-checkout-install labs64io-checkout-ui-install labs64io-payment-gateway-install labs64io-customer-portal-ui-install

# uninstall Labs64.IO :: all components
labs64io-all-uninstall: labs64io-traefik-authproxy-uninstall labs64io-gateway-common-uninstall labs64io-gateway-uninstall labs64io-auditflow-uninstall labs64io-checkout-uninstall labs64io-checkout-ui-uninstall labs64io-payment-gateway-uninstall labs64io-customer-portal-ui-uninstall

# show errors in Labs64.IO kubectl logs
labs64io-show-errors:
    kubectl --namespace {{NAMESPACE_LABS64IO}} logs -l app.kubernetes.io/part-of=Labs64.IO | grep -E 'WARN|ERROR|FATAL|FAILURE|FAILED' || true

# Labs64.IO :: Documentation
labs64io-documentation:
    open "http://gateway.localhost/swagger-ui/"


## Kubernetes Components ##

# install Metrics Server
metrics-server-install: repo-update
    helm search repo metrics-server/metrics-server
    helm show values metrics-server/metrics-server > overrides/metrics-server/values.orig.yaml
    helm upgrade --install metrics-server metrics-server/metrics-server \
      --version {{METRICS_SERVER_CHART_VERSION}} \
      -f overrides/metrics-server/values.{{ENV}}.yaml \
      --namespace {{NAMESPACE_KUBE_SYSTEM}} \
      --set args="{--kubelet-insecure-tls}"

# uninstall Metrics Server
metrics-server-uninstall:
    helm uninstall metrics-server --namespace {{NAMESPACE_KUBE_SYSTEM}}


## Tools ##

# install Traefik
traefik-install: repo-update
    helm search repo traefik/traefik
    helm show values traefik/traefik > overrides/traefik/values.orig.yaml
    helm show values traefik/traefik-crds > overrides/traefik/values-crds.orig.yaml
    helm upgrade --install traefik-crds traefik/traefik-crds --version {{TRAEFIK_CRDS_CHART_VERSION}} --namespace {{NAMESPACE_TOOLS}} --create-namespace
    helm upgrade --install traefik traefik/traefik --version {{TRAEFIK_CHART_VERSION}} -f overrides/traefik/values.{{ENV}}.yaml --namespace {{NAMESPACE_TOOLS}} --wait

# Traefik Dashboard
traefik-dashboard:
    open "http://dashboard.localhost/dashboard/"

# uninstall Traefik
traefik-uninstall:
    helm uninstall traefik --namespace {{NAMESPACE_TOOLS}} || true
    helm uninstall traefik-crds --namespace {{NAMESPACE_TOOLS}} || true

# install RabbitMQ
rabbitmq-install: repo-update
    helm search repo bitnami/rabbitmq
    helm show values bitnami/rabbitmq > overrides/rabbitmq/values.orig.yaml
    helm upgrade --install rabbitmq bitnami/rabbitmq --version {{RABBITMQ_CHART_VERSION}} -f overrides/rabbitmq/values.{{ENV}}.yaml --namespace {{NAMESPACE_TOOLS}} --create-namespace
    @echo "Username      : labs64"
    @echo "Password      : $(kubectl get secret --namespace tools rabbitmq -o jsonpath="{.data.rabbitmq-password}" | base64 -d)"
    @echo "ErLang Cookie : $(kubectl get secret --namespace tools rabbitmq -o jsonpath="{.data.rabbitmq-erlang-cookie}" | base64 -d)"

# uninstall RabbitMQ
rabbitmq-uninstall:
    helm uninstall rabbitmq --namespace {{NAMESPACE_TOOLS}}

# install PostgreSQL
postgresql-install: repo-update
    helm search repo bitnami/postgresql
    helm show values bitnami/postgresql > overrides/postgresql/values.orig.yaml
    helm upgrade --install postgresql bitnami/postgresql \
      --version {{POSTGRESQL_CHART_VERSION}} \
      -f overrides/postgresql/values.{{ENV}}.yaml \
      --namespace {{NAMESPACE_TOOLS}} --create-namespace
    @echo "PostgreSQL pod(s):" && kubectl get pods --namespace {{NAMESPACE_TOOLS}} -l app.kubernetes.io/instance=postgresql
    @echo "postgres password : $(kubectl get secret --namespace {{NAMESPACE_TOOLS}} postgresql -o jsonpath="{.data.postgres-password}" | base64 -d 2>/dev/null || kubectl get secret --namespace {{NAMESPACE_TOOLS}} postgresql -o jsonpath="{.data.postgresql-password}" | base64 -d)"
    @echo "user password     : $(kubectl get secret --namespace {{NAMESPACE_TOOLS}} postgresql -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || true)"

# uninstall PostgreSQL
postgresql-uninstall:
    helm uninstall postgresql --namespace {{NAMESPACE_TOOLS}}

# install Redis
redis-install: repo-update
    helm search repo bitnami/redis
    helm show values bitnami/redis > overrides/redis/values.orig.yaml
    helm upgrade --install redis bitnami/redis --version {{REDIS_CHART_VERSION}} -f overrides/redis/values.{{ENV}}.yaml --namespace {{NAMESPACE_TOOLS}} --create-namespace

# uninstall Redis
redis-uninstall:
    helm uninstall redis --namespace {{NAMESPACE_TOOLS}}

# install Keycloak
keycloak-install: repo-update
    helm search repo bitnami/keycloak
    helm show values bitnami/keycloak > overrides/keycloak/values.orig.yaml
    helm upgrade --install keycloak bitnami/keycloak --version {{KEYCLOAK_CHART_VERSION}} -f overrides/keycloak/values.{{ENV}}.yaml --namespace {{NAMESPACE_TOOLS}} --create-namespace
    kubectl --namespace {{NAMESPACE_TOOLS}} apply -f overrides/keycloak/keycloak-ingressroute.yaml

# uninstall Keycloak
keycloak-uninstall:
    kubectl --namespace {{NAMESPACE_TOOLS}} delete -f overrides/keycloak/keycloak-ingressroute.yaml
    helm uninstall keycloak --namespace {{NAMESPACE_TOOLS}}

# install mock OIDC provider (DEV ONLY - M2M tokens for local testing)
mock-oidc-install:
    kubectl apply -f overrides/mock-oidc/mock-oidc.yaml

# uninstall mock OIDC provider
mock-oidc-uninstall:
    kubectl delete -f overrides/mock-oidc/mock-oidc.yaml

# generate an M2M JWT from the mock OIDC provider (scope: admin|auditflow|ecommerce)
test-generate-jwt-token-mock scope="admin":
    curl -s -X POST 'http://mock-oidc.localhost/labs64io/token' \
      -H 'Content-Type: application/x-www-form-urlencoded' \
      --data-urlencode 'grant_type=client_credentials' \
      --data-urlencode 'client_id=local-test' \
      --data-urlencode 'client_secret=local-test' \
      --data-urlencode 'scope={{scope}}'

# end-to-end auth smoke test through Traefik (requires: traefik, gateway-common, traefik-authproxy, auditflow, mock-oidc)
labs64io-e2e-auth:
    #!/usr/bin/env bash
    set -euo pipefail
    TOKEN=$(curl -s -X POST 'http://mock-oidc.localhost/labs64io/token' \
      --data-urlencode 'grant_type=client_credentials' \
      --data-urlencode 'client_id=e2e' --data-urlencode 'client_secret=e2e' \
      --data-urlencode 'scope=admin' | python3 -c 'import sys,json; print(json.load(sys.stdin)["access_token"])')
    no_token=$(curl -s -o /dev/null -w '%{http_code}' 'http://gateway.localhost/auditflow/api')
    with_token=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer ${TOKEN}" 'http://gateway.localhost/auditflow/api')
    BAD_TOKEN=$(curl -s -X POST 'http://mock-oidc.localhost/labs64io/token' \
      --data-urlencode 'grant_type=client_credentials' \
      --data-urlencode 'client_id=e2e' --data-urlencode 'client_secret=e2e' \
      --data-urlencode 'scope=no-access' | python3 -c 'import sys,json; print(json.load(sys.stdin)["access_token"])')
    wrong_scope=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer ${BAD_TOKEN}" 'http://gateway.localhost/auditflow/api')
    echo "no token   -> ${no_token} (expected 401)"
    echo "with token -> ${with_token} (expected not 401/403)"
    echo "wrong scope -> ${wrong_scope} (expected 403)"
    [ "${no_token}" = "401" ] || { echo "FAIL: expected 401 without token"; exit 1; }
    case "${with_token}" in 401|403) echo "FAIL: token rejected"; exit 1;; esac
    [ "${wrong_scope}" = "403" ] || { echo "FAIL: expected 403 for wrong-scope token"; exit 1; }
    echo "e2e auth: OK"


## Monitoring Tools ##

# install Open Telemetry
opentelemetry-install: repo-update
    helm search repo open-telemetry
    helm show values open-telemetry/opentelemetry-operator > overrides/opentelemetry/values-operator.orig.yaml
    helm show values open-telemetry/opentelemetry-collector > overrides/opentelemetry/values-collector.orig.yaml
    helm upgrade --install opentelemetry-operator open-telemetry/opentelemetry-operator \
      --version {{OTEL_OPERATOR_CHART_VERSION}} \
      -f overrides/opentelemetry/values-operator.{{ENV}}.yaml \
      --namespace {{NAMESPACE_MONITORING}} --create-namespace --wait
    helm upgrade --install opentelemetry-collector open-telemetry/opentelemetry-collector \
      --version {{OTEL_COLLECTOR_CHART_VERSION}} \
      -f overrides/opentelemetry/values-collector.{{ENV}}.yaml \
      --namespace {{NAMESPACE_MONITORING}} --create-namespace --wait

# uninstall Open Telemetry
opentelemetry-uninstall:
    helm uninstall opentelemetry-operator --namespace {{NAMESPACE_MONITORING}}
    helm uninstall opentelemetry-collector --namespace {{NAMESPACE_MONITORING}}

# install Prometheus
prometheus-install: repo-update
    helm search repo prometheus-community
    helm show values prometheus-community/kube-prometheus-stack > overrides/prometheus/values.orig.yaml
    helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
      --version {{PROMETHEUS_STACK_CHART_VERSION}} \
      -f overrides/prometheus/values.{{ENV}}.yaml \
      --namespace {{NAMESPACE_MONITORING}} --create-namespace
    kubectl --namespace {{NAMESPACE_MONITORING}} get pods,svc -l "release=prometheus"

# uninstall Prometheus
prometheus-uninstall:
    helm uninstall prometheus --namespace {{NAMESPACE_MONITORING}}

# install Tempo
tempo-install: repo-update
    helm search repo grafana/tempo
    helm show values grafana/tempo > overrides/tempo/values.orig.yaml
    helm upgrade --install tempo grafana/tempo \
      --version {{TEMPO_CHART_VERSION}} \
      -f overrides/tempo/values.{{ENV}}.yaml \
      --namespace {{NAMESPACE_MONITORING}} --create-namespace

# uninstall Tempo
tempo-uninstall:
    helm uninstall tempo --namespace {{NAMESPACE_MONITORING}}

# install Grafana
grafana-install: repo-update
    helm search repo grafana/grafana
    helm show values grafana/grafana > overrides/grafana/values.orig.yaml
    helm upgrade --install grafana grafana/grafana \
      --version {{GRAFANA_CHART_VERSION}} \
      -f overrides/grafana/values.{{ENV}}.yaml \
      --namespace {{NAMESPACE_MONITORING}} --create-namespace
    @echo "Run this command to open Grafana: kubectl port-forward svc/grafana --namespace {{NAMESPACE_MONITORING}} 3000:80"
    @echo "Username: admin"
    @echo "Password: " && kubectl get secret --namespace {{NAMESPACE_MONITORING}} grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

# retrieve Grafana password
grafana-password:
    @echo "Username: admin"
    @echo "Password: " && kubectl get secret --namespace {{NAMESPACE_MONITORING}} grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

# uninstall Grafana
grafana-uninstall:
    helm uninstall grafana --namespace {{NAMESPACE_MONITORING}}


## Other/Backup Tools ##

# install Ingress controller
ingress-install: repo-update
    helm search repo ingress-nginx/ingress-nginx
    helm show values ingress-nginx/ingress-nginx > overrides/ingress-nginx/values.orig.yaml
    helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
      --version {{INGRESS_NGINX_CHART_VERSION}} \
      -f overrides/ingress-nginx/values.{{ENV}}.yaml \
      --namespace {{NAMESPACE_INGRESS}} --create-namespace

# uninstall Ingress controller
ingress-uninstall:
    helm uninstall ingress-nginx --namespace {{NAMESPACE_INGRESS}}

ENV := "local"
NAMESPACE_LABS64IO := "labs64io"
NAMESPACE_INGRESS := "ingress-nginx"
NAMESPACE_KUBE_SYSTEM := "kube-system"
NAMESPACE_MONITORING := "monitoring"
NAMESPACE_TOOLS := "tools"

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
    helm repo add victoria-metrics https://victoriametrics.github.io/helm-charts/
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add opensearch https://opensearch-project.github.io/helm-charts/

# update helm repositories
repo-update: repo-add
    helm repo update

# show repositories versions
repo-search: repo-update
    helm search repo


## Labs64.IO Components ##

# Generate Helm chart docu
generate-docu:
    docker run --rm --volume "$(pwd):/helm-docs" -u $(id -u) jnorwood/helm-docs:latest

# Generate Helm values schema
generate-schema:
    helm schema -input charts/api-gateway/values.yaml -output charts/api-gateway/values.schema.json
    helm schema -input charts/traefik-authproxy/values.yaml -output charts/traefik-authproxy/values.schema.json
    helm schema -input charts/auditflow/values.yaml -output charts/auditflow/values.schema.json
    helm schema -input charts/ecommerce/values.yaml -output charts/ecommerce/values.schema.json

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

# install Labs64.IO :: API Gateway
labs64io-api-gateway-install:
    helm dependencies update ./charts/api-gateway
    helm upgrade --install labs64io-api-gateway ./charts/api-gateway \
      --namespace {{NAMESPACE_LABS64IO}} --create-namespace \
      -f ./charts/api-gateway/values.yaml \
      -f ./overrides/api-gateway/values.{{ENV}}.yaml

# uninstall Labs64.IO :: API Gateway
labs64io-api-gateway-uninstall:
    helm uninstall labs64io-api-gateway --namespace {{NAMESPACE_LABS64IO}}

# install Labs64.IO :: AuditFlow
labs64io-auditflow-install:
    helm dependencies update ./charts/auditflow
    helm upgrade --install labs64io-auditflow ./charts/auditflow \
      --namespace {{NAMESPACE_LABS64IO}} --create-namespace \
      -f ./charts/auditflow/values.yaml \
      -f ./overrides/auditflow/values.{{ENV}}.yaml

# uninstall Labs64.IO :: AuditFlow
labs64io-auditflow-uninstall:
    helm uninstall labs64io-auditflow --namespace {{NAMESPACE_LABS64IO}}

# install Labs64.IO :: eCommerce
labs64io-ecommerce-install:
    helm dependencies update ./charts/ecommerce
    helm upgrade --install labs64io-ecommerce ./charts/ecommerce \
      --namespace {{NAMESPACE_LABS64IO}} --create-namespace \
      -f ./charts/ecommerce/values.yaml \
      -f ./overrides/ecommerce/values.{{ENV}}.yaml

# uninstall Labs64.IO :: eCommerce
labs64io-ecommerce-uninstall:
    helm uninstall labs64io-ecommerce --namespace {{NAMESPACE_LABS64IO}}

# install Labs64.IO :: eCommerce-UI
labs64io-ecommerce-ui-install:
    helm dependencies update ./charts/ecommerce-ui
    helm upgrade --install labs64io-ecommerce-ui ./charts/ecommerce-ui \
      --namespace {{NAMESPACE_LABS64IO}} --create-namespace \
      -f ./charts/ecommerce-ui/values.yaml \
      -f ./overrides/ecommerce-ui/values.{{ENV}}.yaml

# uninstall Labs64.IO :: eCommerce
labs64io-ecommerce-ui-uninstall:
    helm uninstall labs64io-ecommerce-ui --namespace {{NAMESPACE_LABS64IO}}


# install Labs64.IO :: all components
labs64io-all-install: labs64io-traefik-authproxy-install labs64io-auditflow-install labs64io-ecommerce-install labs64io-api-gateway-install

# uninstall Labs64.IO :: all components
labs64io-all-uninstall: labs64io-traefik-authproxy-uninstall labs64io-auditflow-uninstall labs64io-ecommerce-uninstall labs64io-api-gateway-uninstall

# show errors in Labs64.IO kubectl logs
labs64io-show-errors:
    kubectl --namespace {{NAMESPACE_LABS64IO}} logs -l app.kubernetes.io/part-of=Labs64.IO | grep -E 'WARN|ERROR|FATAL|FAILURE|FAILED'


## Kubernetes Components ##

# install Metrics Server
metrics-server-install: repo-update
    helm search repo metrics-server/metrics-server
    helm show values metrics-server/metrics-server > overrides/metrics-server/values.orig.yaml
    helm upgrade --install metrics-server metrics-server/metrics-server -f overrides/metrics-server/values.{{ENV}}.yaml --namespace {{NAMESPACE_KUBE_SYSTEM}} --set args="{--kubelet-insecure-tls}"

# uninstall Metrics Server
metrics-server-uninstall:
    helm uninstall metrics-server --namespace {{NAMESPACE_KUBE_SYSTEM}}


## Tools ##

# install Traefik
traefik-install: repo-update
    helm search repo traefik/traefik
    helm show values traefik/traefik > overrides/traefik/values.orig.yaml
    helm show values traefik/traefik-crds > overrides/traefik/values-crds.orig.yaml
    #helm upgrade --install traefik-crds traefik/traefik-crds --namespace {{NAMESPACE_TOOLS}} --create-namespace
    helm upgrade --install traefik traefik/traefik -f overrides/traefik/values.{{ENV}}.yaml --namespace {{NAMESPACE_TOOLS}} --wait

# Traefik Dashboard
traefik-dashboard:
    open "http://dashboard.localhost/dashboard/"

# uninstall Traefik
traefik-uninstall:
    helm uninstall traefik --namespace {{NAMESPACE_TOOLS}}

# install Keycloak
keycloak-install: repo-update
    helm search repo bitnami/keycloak
    helm show values bitnami/keycloak > overrides/keycloak/values.orig.yaml
    helm upgrade --install keycloak bitnami/keycloak -f overrides/keycloak/values.{{ENV}}.yaml --namespace {{NAMESPACE_TOOLS}} --create-namespace
    kubectl --namespace {{NAMESPACE_TOOLS}} apply -f overrides/keycloak/keycloak-ingressroute.yaml

# uninstall Keycloak
keycloak-uninstall:
    kubectl --namespace {{NAMESPACE_TOOLS}} delete -f overrides/keycloak/keycloak-ingressroute.yaml
    helm uninstall keycloak --namespace {{NAMESPACE_TOOLS}}

# install RabbitMQ
rabbitmq-install: repo-update
    helm search repo bitnami/rabbitmq
    helm show values bitnami/rabbitmq > overrides/rabbitmq/values.orig.yaml
    helm upgrade --install rabbitmq bitnami/rabbitmq -f overrides/rabbitmq/values.{{ENV}}.yaml --namespace {{NAMESPACE_TOOLS}} --create-namespace
    echo "Username      : labs64"
    echo "Password      : $(kubectl get secret --namespace tools rabbitmq -o jsonpath="{.data.rabbitmq-password}" | base64 -d)"
    echo "ErLang Cookie : $(kubectl get secret --namespace tools rabbitmq -o jsonpath="{.data.rabbitmq-erlang-cookie}" | base64 -d)"

# uninstall RabbitMQ
rabbitmq-uninstall:
    helm uninstall rabbitmq --namespace {{NAMESPACE_TOOLS}}

# install Redis
redis-install: repo-update
    helm search repo bitnami/redis
    helm show values bitnami/redis > overrides/redis/values.orig.yaml
    helm upgrade --install redis bitnami/redis -f overrides/redis/values.{{ENV}}.yaml --namespace {{NAMESPACE_TOOLS}} --create-namespace

# uninstall Redis
redis-uninstall:
    helm uninstall redis --namespace {{NAMESPACE_TOOLS}}

# install OpenSearch
opensearch-install: repo-update
    helm search repo opensearch
    helm show values opensearch/opensearch > overrides/opensearch/values.orig.yaml
    helm show values opensearch/opensearch-dashboards > overrides/opensearch/values-dashboards.orig.yaml
    helm upgrade --install opensearch opensearch/opensearch -f overrides/opensearch/values.{{ENV}}.yaml --namespace {{NAMESPACE_TOOLS}} --create-namespace
    helm upgrade --install opensearch-dashboards opensearch/opensearch-dashboards -f overrides/opensearch/values-dashboards.{{ENV}}.yaml --namespace {{NAMESPACE_TOOLS}} --create-namespace
    kubectl --namespace {{NAMESPACE_TOOLS}} get pods,svc | grep "opensearch"
    echo "Run this command to open OpenSearch Dashboard: kubectl port-forward svc/opensearch-dashboards --namespace {{NAMESPACE_TOOLS}} 5601:5601"

# extract OpenSearch certificate
opensearch-extract-cert:
    kubectl --namespace {{NAMESPACE_TOOLS}} cp opensearch-cluster-master-0:/usr/share/opensearch/config/root-ca.pem ./overrides/opensearch/root-ca.pem -c opensearch
    rm -f overrides/opensearch/truststore.jks
    keytool -import -trustcacerts -file overrides/opensearch/root-ca.pem -alias opensearch-ca -keystore ./overrides/opensearch/truststore.jks -storepass "changeit" -noprompt
    kubectl --namespace {{NAMESPACE_LABS64IO}} delete secret opensearch-truststore-secret || true
    kubectl --namespace {{NAMESPACE_LABS64IO}} create secret generic opensearch-truststore-secret --from-file=./overrides/opensearch/truststore.jks
    kubectl --namespace {{NAMESPACE_LABS64IO}} get secret opensearch-truststore-secret -o yaml

# uninstall OpenSearch
opensearch-uninstall:
    helm uninstall opensearch --namespace {{NAMESPACE_TOOLS}}
    helm uninstall opensearch-dashboards --namespace {{NAMESPACE_TOOLS}}


## Monitoring Tools ##

# install Open Telemetry
opentelemetry-install: repo-update
    helm search repo open-telemetry
    helm show values open-telemetry/opentelemetry-operator > overrides/opentelemetry/values-operator.orig.yaml
    helm show values open-telemetry/opentelemetry-collector > overrides/opentelemetry/values-collector.orig.yaml
    helm upgrade --install opentelemetry-operator open-telemetry/opentelemetry-operator -f overrides/opentelemetry/values-operator.{{ENV}}.yaml --namespace {{NAMESPACE_MONITORING}} --create-namespace --wait
    helm upgrade --install opentelemetry-collector open-telemetry/opentelemetry-collector -f overrides/opentelemetry/values-collector.{{ENV}}.yaml --namespace {{NAMESPACE_MONITORING}} --create-namespace --wait

# uninstall Open Telemetry
opentelemetry-uninstall:
    helm uninstall opentelemetry-operator --namespace {{NAMESPACE_MONITORING}}
    helm uninstall opentelemetry-collector --namespace {{NAMESPACE_MONITORING}}

# install Prometheus
prometheus-install: repo-update
    helm search repo prometheus-community
    helm show values prometheus-community/kube-prometheus-stack > overrides/prometheus/values.orig.yaml
    helm upgrade --install prometheus prometheus-community/kube-prometheus-stack -f overrides/prometheus/values.{{ENV}}.yaml --namespace {{NAMESPACE_MONITORING}} --create-namespace
    kubectl --namespace {{NAMESPACE_MONITORING}} get pods,svc -l "release=prometheus"

# uninstall Prometheus
prometheus-uninstall:
    helm uninstall prometheus --namespace {{NAMESPACE_MONITORING}}

# install tempo
tempo-install: repo-update
    helm search repo grafana/tempo
    helm show values grafana/tempo > overrides/tempo/values.orig.yaml
    helm upgrade --install tempo grafana/tempo -f overrides/tempo/values.{{ENV}}.yaml --namespace {{NAMESPACE_MONITORING}} --create-namespace

# uninstall tempo
tempo-uninstall:
    helm uninstall tempo --namespace {{NAMESPACE_MONITORING}}

# install VictoriaLogs
victoria-logs-install: repo-update
    helm search repo victoria-metrics
    helm show values victoria-metrics/victoria-logs-single > overrides/victoria-logs/values.orig.yaml
    helm upgrade --install victoria-logs victoria-metrics/victoria-logs-single -f overrides/victoria-logs/values.{{ENV}}.yaml --namespace {{NAMESPACE_MONITORING}} --create-namespace

# uninstall VictoriaLogs
victoria-logs-uninstall:
    helm uninstall victoria-logs --namespace {{NAMESPACE_MONITORING}}

# install grafana
grafana-install: repo-update
    helm search repo grafana/grafana
    helm show values grafana/grafana > overrides/grafana/values.orig.yaml
    helm upgrade --install grafana grafana/grafana -f overrides/grafana/values.{{ENV}}.yaml --namespace {{NAMESPACE_MONITORING}} --create-namespace
    echo "Run this command to open Grafana: kubectl port-forward svc/grafana --namespace {{NAMESPACE_MONITORING}} 3000:80"
    echo "Username: admin"
    echo "Password: " && kubectl get secret --namespace {{NAMESPACE_MONITORING}} grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

# retrieve grafana password
grafana-password:
    echo "Username: admin"
    echo "Password: " && kubectl get secret --namespace {{NAMESPACE_MONITORING}} grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

# uninstall grafana
grafana-uninstall:
    helm uninstall grafana --namespace {{NAMESPACE_MONITORING}}


## Other/Backup Tools ##

# install Ingress controller
ingress-install: repo-update
    helm search repo ingress-nginx/ingress-nginx
    helm show values ingress-nginx/ingress-nginx > overrides/ingress-nginx/values.orig.yaml
    helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx -f overrides/ingress-nginx/values.{{ENV}}.yaml --namespace {{NAMESPACE_INGRESS}} --create-namespace

# uninstall Ingress controller
ingress-uninstall:
    helm uninstall ingress-nginx --namespace {{NAMESPACE_INGRESS}}

# install Loki
loki-install: repo-update
    helm search repo grafana/loki
    helm show values grafana/loki > overrides/loki/values.orig.yaml
    helm upgrade --install loki grafana/loki -f overrides/loki/values.{{ENV}}.yaml --namespace {{NAMESPACE_MONITORING}} --create-namespace

# uninstall Loki
loki-uninstall:
    helm uninstall loki --namespace {{NAMESPACE_MONITORING}}

# install OpenSearch Data Prepper
opensearch-data-prepper-install: repo-update
    helm search repo opensearch
    helm show values opensearch/data-prepper > overrides/opensearch/values-data-prepper.orig.yaml
    helm upgrade --install opensearch-data-prepper opensearch/data-prepper -f overrides/opensearch/values-data-prepper.{{ENV}}.yaml --namespace {{NAMESPACE_MONITORING}} --create-namespace

# uninstall OpenSearch Data Prepper
opensearch-data-prepper-uninstall:
    helm uninstall opensearch-data-prepper --namespace {{NAMESPACE_MONITORING}}

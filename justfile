NAMESPACE_LABS64IO := "labs64io"
NAMESPACE_INGRESS := "ingress-nginx"
NAMESPACE_KUBE_SYSTEM := "kube-system"
NAMESPACE_MONITORING := "monitoring"
NAMESPACE_TOOLS := "tools"

## Useful Commands ##

# show helm releases
helm-ls:
    helm ls --all-namespaces

# show pods, services in all namespaces
kubectl-pods:
    kubectl get pods,svc --all-namespaces -o wide


# add external helm repositories
repo-add:
    helm repo add labs64io-pub https://labs64.github.io/labs64.io-helm-charts
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add opensearch https://opensearch-project.github.io/helm-charts/

# update helm repositories
repo-update:
    helm repo update

# show repositories versions
repo-search: repo-update
    helm search repo


## Install Tools ##

# install Metrics Server
metrics-server-install:
    helm search repo metrics-server/metrics-server
    helm show values metrics-server/metrics-server > charts/third-party/metrics-server/values.orig.yaml
    helm upgrade --install metrics-server metrics-server/metrics-server -f charts/third-party/metrics-server/values.yaml --namespace {{NAMESPACE_KUBE_SYSTEM}} --set args="{--kubelet-insecure-tls}"

# uninstall Metrics Server
metrics-server-uninstall:
    helm uninstall metrics-server --namespace {{NAMESPACE_KUBE_SYSTEM}}

# install Ingress controller
ingress-install:
    helm search repo ingress-nginx/ingress-nginx
    helm show values ingress-nginx/ingress-nginx > charts/third-party/ingress-nginx/values.orig.yaml
    helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx -f charts/third-party/ingress-nginx/values.yaml --namespace {{NAMESPACE_INGRESS}} --create-namespace

# uninstall Ingress controller
ingress-uninstall:
    helm uninstall ingress-nginx --namespace {{NAMESPACE_INGRESS}}


# install RabbitMQ
rabbitmq-install:
    helm search repo bitnami/rabbitmq
    helm show values bitnami/rabbitmq > charts/third-party/rabbitmq/values.orig.yaml
    helm upgrade --install rabbitmq bitnami/rabbitmq -f charts/third-party/rabbitmq/values.yaml --namespace {{NAMESPACE_TOOLS}} --create-namespace
    echo "Username      : labs64"
    echo "Password      : $(kubectl get secret --namespace tools rabbitmq -o jsonpath="{.data.rabbitmq-password}" | base64 -d)"
    echo "ErLang Cookie : $(kubectl get secret --namespace tools rabbitmq -o jsonpath="{.data.rabbitmq-erlang-cookie}" | base64 -d)"

# uninstall RabbitMQ
rabbitmq-uninstall:
    helm uninstall rabbitmq

# install Kafka
kafka-install:
    helm search repo bitnami/kafka
    helm show values bitnami/kafka > charts/third-party/kafka/values.orig.yaml
    helm upgrade --install kafka bitnami/kafka -f charts/third-party/kafka/values.yaml --namespace {{NAMESPACE_TOOLS}} --create-namespace

# uninstall Kafka
kafka-uninstall:
    helm uninstall kafka


## Install Monitoring Tools ##

# install Grafana Alloy
alloy-install:
    helm search repo grafana/alloy
    helm show values grafana/alloy > charts/third-party/alloy/values.orig.yaml
    helm upgrade --install alloy grafana/alloy -f charts/third-party/alloy/values.yaml --namespace {{NAMESPACE_MONITORING}} --create-namespace

# uninstall Grafana Alloy
alloy-uninstall:
    helm uninstall alloy --namespace {{NAMESPACE_MONITORING}}

# install OpenSearch
opensearch-install:
    helm search repo opensearch
    helm show values opensearch/opensearch > charts/third-party/opensearch/values.orig.yaml
    helm show values opensearch/opensearch-dashboards > charts/third-party/opensearch/values-dashboards.orig.yaml
    helm upgrade --install opensearch opensearch/opensearch -f charts/third-party/opensearch/values.yaml --namespace {{NAMESPACE_MONITORING}} --create-namespace
    helm upgrade --install opensearch-dashboards opensearch/opensearch-dashboards -f charts/third-party/opensearch/values-dashboards.yaml --namespace {{NAMESPACE_MONITORING}} --create-namespace
    kubectl --namespace {{NAMESPACE_MONITORING}} get pods,svc | grep "opensearch"
    echo "Run this command to open OpenSearch Dashboard: kubectl port-forward svc/opensearch-dashboards --namespace {{NAMESPACE_MONITORING}} 5601:5601"

# extract OpenSearch certificate
opensearch-extract-cert:
    kubectl --namespace {{NAMESPACE_MONITORING}} cp opensearch-cluster-master-0:/usr/share/opensearch/config/root-ca.pem charts/third-party/opensearch/root-ca.pem -c opensearch
    rm -f charts/third-party/opensearch/truststore.jks
    keytool -import -trustcacerts -file charts/third-party/opensearch/root-ca.pem -alias opensearch-ca -keystore charts/third-party/opensearch/truststore.jks -storepass "changeit" -noprompt
    kubectl --namespace {{NAMESPACE_LABS64IO}} delete secret opensearch-truststore-secret
    kubectl --namespace {{NAMESPACE_LABS64IO}} create secret generic opensearch-truststore-secret --from-file=./charts/third-party/opensearch/truststore.jks
    kubectl --namespace {{NAMESPACE_LABS64IO}} get secret opensearch-truststore-secret -o yaml

# uninstall OpenSearch
opensearch-uninstall:
    helm uninstall opensearch --namespace {{NAMESPACE_MONITORING}}
    helm uninstall opensearch-dashboards --namespace {{NAMESPACE_MONITORING}}

# install Prometheus
prometheus-install:
    helm search repo prometheus-community
    helm show values prometheus-community/kube-prometheus-stack > charts/third-party/prometheus/values.orig.yaml
    helm upgrade --install prometheus prometheus-community/kube-prometheus-stack -f charts/third-party/prometheus/values.yaml --namespace {{NAMESPACE_MONITORING}} --create-namespace
    kubectl --namespace {{NAMESPACE_MONITORING}} get pods,svc -l "release=prometheus"

# uninstall Prometheus
prometheus-uninstall:
    helm uninstall prometheus --namespace {{NAMESPACE_MONITORING}}

# install Loki
loki-install:
    helm search repo grafana/loki
    helm show values grafana/loki > charts/third-party/loki/values.orig.yaml
    helm upgrade --install loki grafana/loki -f charts/third-party/loki/values.yaml --namespace {{NAMESPACE_MONITORING}} --create-namespace

# uninstall Loki
loki-uninstall:
    helm uninstall loki --namespace {{NAMESPACE_MONITORING}}

# install tempo
tempo-install:
    helm search repo grafana/tempo
    helm show values grafana/tempo > charts/third-party/tempo/values.orig.yaml
    helm upgrade --install tempo grafana/tempo -f charts/third-party/tempo/values.yaml --namespace {{NAMESPACE_MONITORING}} --create-namespace

# uninstall tempo
tempo-uninstall:
    helm uninstall tempo --namespace {{NAMESPACE_MONITORING}}

# install grafana
grafana-install:
    helm search repo grafana/grafana
    helm show values grafana/grafana > charts/third-party/grafana/values.orig.yaml
    helm upgrade --install grafana grafana/grafana -f charts/third-party/grafana/values.yaml --namespace {{NAMESPACE_MONITORING}} --create-namespace
    echo "Run this command to open Grafana: kubectl port-forward svc/grafana --namespace {{NAMESPACE_MONITORING}} 3000:80"
    echo "Username: admin"
    echo "Password: " && kubectl get secret --namespace {{NAMESPACE_MONITORING}} grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

# uninstall grafana
grafana-uninstall:
    helm uninstall grafana --namespace {{NAMESPACE_MONITORING}}

# install Open Telemetry
open-telemetry-install:
    helm search repo open-telemetry
    helm show values open-telemetry/opentelemetry-collector > charts/third-party/otel/values.orig.yaml
    helm upgrade --install otel open-telemetry/opentelemetry-collector -f charts/third-party/otel/values.yaml --namespace {{NAMESPACE_MONITORING}} --create-namespace

# uninstall Open Telemetry
open-telemetry-uninstall:
    helm uninstall otel --namespace {{NAMESPACE_MONITORING}}


## Install Labs64.IO Components ##

# Generate Helm chart docu
generate-docu:
    docker run --rm --volume "$(pwd):/helm-docs" -u $(id -u) jnorwood/helm-docs:latest

# Generate Helm values schema
generate-schema:
    helm schema -input charts/api-gateway/values.yaml -output charts/api-gateway/values.schema.json
    helm schema -input charts/auditflow/values.yaml -output charts/auditflow/values.schema.json

# install Labs64.IO :: API Gateway
helm-install-gw:
    helm dependencies update ./charts/api-gateway
    helm upgrade --install l64-local-gw ./charts/api-gateway \
      --namespace {{NAMESPACE_LABS64IO}} --create-namespace \
      --set image.repository=localhost:5005/api-gateway \
      --set image.tag=latest \
      --set application.rabbitmq.host=rabbitmq.{{NAMESPACE_TOOLS}}.svc.cluster.local
    echo "Run this command to tunnel API Gateway: kubectl --namespace {{NAMESPACE_LABS64IO}} port-forward svc/l64-local-gw-api-gateway 8080:8080"
    echo "Visit http://localhost:8080/swagger-ui/index.html for API documentation"

# install Labs64.IO :: AuditFlow
helm-install-au:
    helm dependencies update ./charts/auditflow
    helm upgrade --install l64-local-au ./charts/auditflow \
      --namespace {{NAMESPACE_LABS64IO}} --create-namespace \
      --set image.repository=localhost:5005/auditflow \
      --set image.tag=latest \
      --set application.rabbitmq.host=rabbitmq.{{NAMESPACE_TOOLS}}.svc.cluster.local \
      --set transformer.image.repository=localhost:5005/auditflow-transformer \
      --set transformer.image.tag=latest

# install Labs64.IO :: all components
helm-install-all: helm-install-gw helm-install-au

# uninstall Labs64.IO :: API Gateway
helm-uninstall-gw:
    helm uninstall l64-local-gw

# uninstall Labs64.IO :: AuditFlow
helm-uninstall-au:
    helm uninstall l64-local-au

# uninstall Labs64.IO :: all components
helm-uninstall-all: helm-uninstall-gw helm-uninstall-au

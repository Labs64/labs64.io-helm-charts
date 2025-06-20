NAMESPACE_LABS64IO := "labs64io"
NAMESPACE_MONITORING := "monitoring"
NAMESPACE_TOOLS := "tools"

# add external helm repositories
repo-add:
    helm repo add labs64io-pub https://labs64.github.io/labs64.io-helm-charts
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# update helm repositories
repo-update:
    helm repo update

# show repositories versions
repo-search: repo-update
    helm search repo


## Install Tools ##

# install RabbitMQ
rabbitmq-install:
    helm search repo bitnami/rabbitmq
    helm show values bitnami/rabbitmq > charts/third-party/rabbitmq/values.orig.yaml
    helm upgrade --install rabbitmq bitnami/rabbitmq -f charts/third-party/rabbitmq/values.yaml -n {{NAMESPACE_TOOLS}} --create-namespace
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
    helm upgrade --install kafka bitnami/kafka -f charts/third-party/kafka/values.yaml -n {{NAMESPACE_TOOLS}} --create-namespace

# uninstall Kafka
kafka-uninstall:
    helm uninstall kafka


## Install Monitoring Tools ##

# install Prometheus
prometheus-install:
    helm search repo prometheus-community
    helm show values prometheus-community/kube-prometheus-stack > charts/third-party/prometheus/values.orig.yaml
    helm upgrade --install prometheus prometheus-community/kube-prometheus-stack -f charts/third-party/prometheus/values.yaml -n {{NAMESPACE_MONITORING}} --create-namespace
    kubectl --namespace {{NAMESPACE_MONITORING}} get pods -l "release=prometheus"

# uninstall Prometheus
prometheus-uninstall:
    helm uninstall prometheus -n {{NAMESPACE_MONITORING}}

# install Loki
loki-install:
    helm search repo grafana/loki
    helm show values grafana/loki > charts/third-party/loki/values.orig.yaml
    helm upgrade --install loki grafana/loki -f charts/third-party/loki/values.yaml -n {{NAMESPACE_MONITORING}} --create-namespace

# uninstall Loki
loki-uninstall:
    helm uninstall loki -n {{NAMESPACE_MONITORING}}

# install tempo
tempo-install:
    helm search repo grafana/tempo
    helm show values grafana/tempo > charts/third-party/tempo/values.orig.yaml
    helm upgrade --install tempo grafana/tempo -f charts/third-party/tempo/values.yaml -n {{NAMESPACE_MONITORING}} --create-namespace

# uninstall tempo
tempo-uninstall:
    helm uninstall tempo -n {{NAMESPACE_MONITORING}}

# install grafana
grafana-install:
    helm search repo grafana/grafana
    helm show values grafana/grafana > charts/third-party/grafana/values.orig.yaml
    helm upgrade --install grafana grafana/grafana -f charts/third-party/grafana/values.yaml -n {{NAMESPACE_MONITORING}} --create-namespace
    echo "Run this command to open Grafana: kubectl port-forward svc/grafana -n {{NAMESPACE_MONITORING}} 3000:80"
    echo "Username: admin"
    echo "Password: " && kubectl get secret --namespace {{NAMESPACE_MONITORING}} grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

# uninstall grafana
grafana-uninstall:
    helm uninstall grafana -n {{NAMESPACE_MONITORING}}

# install Open Telemetry
open-telemetry-install:
    helm search repo open-telemetry
    helm show values open-telemetry/opentelemetry-collector > charts/third-party/otel/values.orig.yaml
    helm upgrade --install otel open-telemetry/opentelemetry-collector -f charts/third-party/otel/values.yaml -n {{NAMESPACE_MONITORING}} --create-namespace

# uninstall Open Telemetry
open-telemetry-uninstall:
    helm uninstall otel -n {{NAMESPACE_MONITORING}}


## Install Labs64.IO Components ##

# Generate Helm chart docu
generate-docu:
    docker run --rm --volume "$(pwd):/helm-docs" -u $(id -u) jnorwood/helm-docs:latest

# Generate Helm values schema
generate-schema:
    helm schema -input charts/api-gateway/values.yaml -output charts/api-gateway/values.schema.json
    helm schema -input charts/auditflow/values.yaml -output charts/auditflow/values.schema.json

# show helm releases
helm-ls:
    helm ls --all-namespaces

# install Labs64.IO :: API Gateway
helm-install-gw:
    helm dependencies update ./charts/api-gateway
    helm upgrade --install l64-local-gw ./charts/api-gateway \
      --namespace {{NAMESPACE_LABS64IO}} --create-namespace \
      --set image.repository=localhost:5005/api-gateway \
      --set image.tag=latest \
      --set application.rabbitmq.host=rabbitmq.{{NAMESPACE_TOOLS}}.svc.cluster.local
    echo "Run this command to tunnel API Gateway: kubectl -n {{NAMESPACE_LABS64IO}} port-forward svc/l64-local-gw-api-gateway 8080:8080"
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

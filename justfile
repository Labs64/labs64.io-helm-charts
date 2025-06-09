# add external helm repositories
repo-add:
    helm repo add labs64io-pub https://labs64.github.io/labs64.io-helm-charts
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts

# update helm repositories
repo-update:
    helm repo update

# show repositories versions
repo-search: repo-update
    helm search repo

# install RabbitMQ
install-rabbitmq:
    helm search repo bitnami/rabbitmq
    helm upgrade --install rabbitmq bitnami/rabbitmq -f charts/third-party/rabbitmq/values.yaml

# uninstall RabbitMQ
uninstall-rabbitmq:
    helm uninstall rabbitmq

# install Kafka
install-kafka:
    helm search repo bitnami/kafka
    helm upgrade --install kafka bitnami/kafka -f charts/third-party/kafka/values.yaml

# uninstall Kafka
uninstall-kafka:
    helm uninstall kafka

# install Open Telemetry
install-otel:
    helm search repo open-telemetry
    helm upgrade --install opentelemetry-collector open-telemetry/opentelemetry-collector -f charts/third-party/otel/values.yaml

# uninstall Open Telemetry
uninstall-otel:
    helm uninstall otel-collector

# Generate Helm chart docu
docu:
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
      --set image.repository=localhost:5005/api-gateway \
      --set image.tag=latest

# install Labs64.IO :: AuditFlow
helm-install-au:
    helm dependencies update ./charts/auditflow
    helm upgrade --install l64-local-au ./charts/auditflow \
      --set image.repository=localhost:5005/auditflow \
      --set image.tag=latest \
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

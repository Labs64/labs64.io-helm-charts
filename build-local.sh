# Install helm charts

## Add External Repos
helm repo add labs64io-pub https://labs64.github.io/labs64.io-helm-charts
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

## Install Kafka manually
#helm uninstall kafka
#helm search repo bitnami/kafka
#helm show values bitnami/kafka > charts/third-party/kafka/kafka-values.orig.yaml
#helm upgrade --install kafka bitnami/kafka -f charts/third-party/kafka/values.yaml

## Install RabbitMQ manually
#helm uninstall rabbitmq
helm search repo bitnami/rabbitmq
#helm show values bitnami/rabbitmq > charts/third-party/rabbitmq/rabbitmq-values.orig.yaml
helm upgrade --install rabbitmq bitnami/rabbitmq -f charts/third-party/rabbitmq/values.yaml

## Install Open Telemetry manually
#helm uninstall otel-collector
#helm search repo open-telemetry
#helm show values open-telemetry/opentelemetry-collector > charts/third-party/otel/opentelemetry-collector-values.orig.yaml
#helm upgrade --install opentelemetry-collector open-telemetry/opentelemetry-collector -f charts/third-party/otel/values.yaml

## Labs64.IO

# Generate Helm chart docu
docker run --rm --volume "$(pwd):/helm-docs" -u $(id -u) jnorwood/helm-docs:latest

# Generate Helm values schema ( https://github.com/losisin/helm-values-schema-json ; alternative: https://github.com/dadav/helm-schema )
helm schema -input charts/api-gateway/values.yaml -output charts/api-gateway/values.schema.json
helm schema -input charts/auditflow/values.yaml -output charts/auditflow/values.schema.json

# Install Labs64.IO helm packages

#helm uninstall l64-local-gw
helm dependencies update ./charts/api-gateway
#helm dependency build ./charts/api-gateway
helm upgrade --install l64-local-gw ./charts/api-gateway \
  --set image.repository=localhost:5005/api-gateway \
  --set image.tag=latest

#helm uninstall l64-local-au
helm dependencies update ./charts/auditflow
#helm dependency build ./charts/auditflow
helm upgrade --install l64-local-au ./charts/auditflow \
  --set image.repository=localhost:5005/auditflow \
  --set image.tag=latest \
  --set transformer.image.repository=localhost:5005/auditflow-transformer \
  --set transformer.image.tag=latest

helm ls

# k8s
kubectl get pods


## Cheatsheet

# kubectl port-forward service/l64-local-gw-api-gateway 8080:8080
# => http://localhost:8080/swagger-ui/index.html
# => curl -X POST "http://localhost:8080/audit/publish" -H "Content-Type: application/json" -d '{"message":"msg"}'
# kubectl port-forward service/labs64io-rabbitmq 15672:15672
# => http://localhost:15672

# kubectl scale deployment l64-local-gw-api-gateway --replicas=0/1/2

# kubectl logs -l app.kubernetes.io/name=api-gateway -f
# kubectl logs -l app.kubernetes.io/name=auditflow -f

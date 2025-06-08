## Toolset
# Local: k8s, kubectl, helm

# Install helm charts

## Bitnami Repo
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

## Inslatt Kafka manually
#helm uninstall kafka
#helm search repo bitnami/kafka
#helm show values bitnami/kafka > charts/third-party/kafka/kafka-values.orig.yaml
#helm upgrade --install kafka bitnami/kafka -f charts/third-party/kafka/values.yaml

## Install RabbitMQ manually
#helm uninstall rabbitmq
#helm search repo bitnami/rabbitmq
#helm show values bitnami/rabbitmq > charts/third-party/rabbitmq/rabbitmq-values.orig.yaml
#helm upgrade --install rabbitmq bitnami/rabbitmq -f charts/third-party/rabbitmq/values.yaml

## Add Open Telemetry Repo
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

## Install Open Telemetry manually
#helm uninstall otel-collector
#helm search repo open-telemetry
#helm show values open-telemetry/opentelemetry-collector > charts/third-party/otel/opentelemetry-collector-values.orig.yaml
#helm upgrade --install opentelemetry-collector open-telemetry/opentelemetry-collector -f charts/third-party/otel/values.yaml

## Labs64.IO

# Generate Helm chart docu
docker run --rm --volume "$(pwd):/helm-docs" -u $(id -u) jnorwood/helm-docs:latest

# Generate Helm values schema
helm schema -input charts/api-gateway/values.yaml -output charts/api-gateway/values.schema.json

# Install helm package
#helm uninstall labs64io
helm dependencies update ./charts/api-gateway
#helm dependency build ./charts/api-gateway
helm upgrade --install labs64io ./charts/api-gateway --set image.repository=localhost:5005/api-gateway

helm ls

# k8s
kubectl get pods


## Cheatsheet

# kubectl port-forward service/labs64io-api-gateway 8080:8080
# => http://localhost:8080/swagger-ui/index.html
# => curl -X POST "http://localhost:8080/audit/publish" -H "Content-Type: application/json" -d '{"message":"msg"}'
# kubectl port-forward service/labs64io-rabbitmq 15672:15672
# => http://localhost:15672

# kubectl scale deployment labs64io-api-gateway --replicas=0/1/2

# kubectl logs -l app.kubernetes.io/name=api-gateway -f


## Links
# - Kubernetes – https://kubernetes.io  Open-source container orchestration platform for automating deployment, scaling, and management of containerized applications
# - Helm – https://helm.sh  Package manager for Kubernetes that uses charts to define, install, and manage applications in a Kubernetes cluster
# - Spring Cloud Stream – https://spring.io/projects/spring-cloud-stream  Framework for building event-driven microservices connected to messaging systems like Kafka or RabbitMQ using binders
# - Kafka – https://kafka.apache.org  Distributed streaming platform for building real-time data pipelines and event-driven applications with scalable publish-subscribe messaging
# - RabbitMQ – https://www.rabbitmq.com  Message broker implementing AMQP and other protocols, enabling reliable inter-service communication in distributed systems
# - OpenAPI – https://www.openapis.org  Standard for describing RESTful APIs in a machine-readable format to support documentation, validation, and code generation
# - Logfmt – https://brandur.org/logfmt  Documentation for parsing logfmt log lines into structured fields, used with Grafana Loki for log aggregation
# - FastAPI – https://fastapi.tiangolo.com  High-performance Python web framework for building APIs with automatic docs, type validation, and async support

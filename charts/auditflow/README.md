# auditflow

![Version: 0.0.1](https://img.shields.io/badge/Version-0.0.1-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.0.1](https://img.shields.io/badge/AppVersion-0.0.1-informational?style=flat-square)

Labs64.IO :: AuditFlow - A Scalable & Searchable Microservices-based Auditing Solution

**Homepage:** <https://labs64.io>

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| labs64 | <info@labs64.com> |  |

## Source Code

* <https://github.com/Labs64/labs64.io-helm-charts>
* <https://github.com/Labs64/labs64.io-auditflow>

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| file://../chart-libs | chart-libs | 0.0.1 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` |  |
| application | object | `{"audit":{"topicName":"labs64-audit-topic"},"auditflow":{"pipelines":[{"enabled":true,"name":"logs","processor":{"clazz":"io.labs64.audit.processors.LoggingProcessor","name":"logging_processor","properties":{"log-level":"DEBUG"}},"transformer":{"name":"zero"}},{"enabled":true,"name":"opensearch-raw","processor":{"clazz":"io.labs64.audit.processors.WebClientPostProcessor","name":"opensearch_processor","properties":{"password":"Labs64pw+","service-path":"/auditflow_raw_index/_doc","service-url":"https://opensearch-cluster-master.monitoring.svc.cluster.local:9200","username":"admin"}},"transformer":{"name":"zero"}},{"enabled":true,"name":"opensearch-transformed","processor":{"clazz":"io.labs64.audit.processors.WebClientPostProcessor","name":"opensearch_processor","properties":{"password":"Labs64pw+","service-path":"/auditflow_index/_doc","service-url":"https://opensearch-cluster-master.monitoring.svc.cluster.local:9200","username":"admin"}},"transformer":{"name":"audit_opensearch"}},{"enabled":false,"name":"loki","processor":{"clazz":"io.labs64.audit.processors.WebClientPostProcessor","name":"loki_processor","properties":{"service-path":"/loki/api/v1/push","service-url":"http://loki-write.monitoring.svc.cluster.local:3100"}},"transformer":{"name":"audit_loki"}}]},"defaultBroker":"rabbit","otel":{"exporter":{"otlp":{"endpoint":"http://otel-collector.observability.svc.cluster.local:4317"}}},"rabbitmq":{"enabled":true,"host":"rabbitmq.default.svc.cluster.local","port":5672},"transformer":{"container":{"enabled":true}}}` | Application properties |
| application.audit | object | `{"topicName":"labs64-audit-topic"}` | Audit properties |
| application.audit.topicName | string | `"labs64-audit-topic"` | Audit topic name; default: labs64-audit-topic |
| application.defaultBroker | string | `"rabbit"` | Message broker; e.g. rabbit, kafka, etc. |
| application.otel | object | `{"exporter":{"otlp":{"endpoint":"http://otel-collector.observability.svc.cluster.local:4317"}}}` | Open Telemetry params |
| application.rabbitmq | object | `{"enabled":true,"host":"rabbitmq.default.svc.cluster.local","port":5672}` | RabbitMQ connection params |
| application.rabbitmq.enabled | bool | `true` | Use RabbitMQ message broker |
| application.rabbitmq.host | string | `"rabbitmq.default.svc.cluster.local"` | RabbitMQ host name; default: rabbitmq.<namespace>.svc.cluster.local |
| application.rabbitmq.port | int | `5672` | RabbitMQ port; default: 5672 |
| application.transformer.container.enabled | bool | `true` | Enable the transformer sidecar container |
| autoscaling | object | `{"enabled":true,"maxReplicas":3,"minReplicas":1,"targetCPUUtilizationPercentage":80}` | This section is for setting up autoscaling more information can be found here: https://kubernetes.io/docs/concepts/workloads/autoscaling/ |
| env[0].name | string | `"SPRING_CONFIG_IMPORT"` |  |
| env[0].value | string | `"optional:file:/etc/auditflow/pipelines.yaml"` |  |
| env[1].name | string | `"JAVA_OPTS"` |  |
| env[1].value | string | `"-Djavax.net.ssl.trustStore=/etc/auditflow/certs/truststore.jks -Djavax.net.ssl.trustStorePassword=changeit"` |  |
| fullnameOverride | string | `""` |  |
| image | object | `{"pullPolicy":"IfNotPresent","repository":"labs64/auditflow","tag":""}` | This sets the container image more information can be found here: https://kubernetes.io/docs/concepts/containers/images/ |
| image.pullPolicy | string | `"IfNotPresent"` | This sets the pull policy for images. |
| image.tag | string | `""` | Overrides the image tag whose default is the chart appVersion. |
| imagePullSecrets | list | `[]` | This is for the secrets for pulling an image from a private repository more information can be found here: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/ |
| ingress | object | `{"annotations":{},"className":"","enabled":false,"hosts":[{"host":"chart-example.local","paths":[{"path":"/","pathType":"ImplementationSpecific"}]}],"tls":[]}` | This block is for setting up the ingress for more information can be found here: https://kubernetes.io/docs/concepts/services-networking/ingress/ |
| livenessProbe | object | `{"failureThreshold":3,"httpGet":{"path":"/actuator/health/liveness","port":8080},"initialDelaySeconds":30,"periodSeconds":10,"timeoutSeconds":2}` | This is to setup the liveness probes more information can be found here: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/ |
| nameOverride | string | `""` | This is to override the chart name. |
| nodeSelector | object | `{}` |  |
| podAnnotations | object | `{}` | This is for setting Kubernetes Annotations to a Pod. For more information checkout: https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/ |
| podLabels | object | `{}` | This is for setting Kubernetes Labels to a Pod. For more information checkout: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/ |
| podSecurityContext | object | `{}` |  |
| rabbitmq | object | `{"auth":{"password":"labs64pw","username":"labs64"},"persistence":{"enabled":true,"size":"1Gi"},"replicaCount":2}` | RabbitMQ properties |
| rabbitmq.auth.password | string | `"labs64pw"` | RabbitMQ password; default: labs64pw |
| rabbitmq.auth.username | string | `"labs64"` | RabbitMQ username; default: labs64 |
| rbac.create | bool | `true` |  |
| readinessProbe | object | `{"failureThreshold":3,"httpGet":{"path":"/actuator/health/readiness","port":8080},"initialDelaySeconds":10,"periodSeconds":5,"timeoutSeconds":2}` | This is to setup the readiness probes more information can be found here: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/ |
| replicaCount | int | `1` | This will set the replicaset count more information can be found here: https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/ |
| resources.requests.cpu | string | `"100m"` |  |
| resources.requests.memory | string | `"512Mi"` |  |
| securityContext | object | `{}` |  |
| service | object | `{"port":8080,"type":"ClusterIP"}` | This is for setting up a service more information can be found here: https://kubernetes.io/docs/concepts/services-networking/service/ |
| service.port | int | `8080` | This sets the ports more information can be found here: https://kubernetes.io/docs/concepts/services-networking/service/#field-spec-ports |
| service.type | string | `"ClusterIP"` | This sets the service type more information can be found here: https://kubernetes.io/docs/concepts/services-networking/service/#publishing-services-service-types |
| serviceAccount | object | `{"annotations":{},"automount":true,"create":true,"name":""}` | This section builds out the service account more information can be found here: https://kubernetes.io/docs/concepts/security/service-accounts/ |
| serviceAccount.annotations | object | `{}` | Annotations to add to the service account |
| serviceAccount.automount | bool | `true` | Automatically mount a ServiceAccount's API credentials? |
| serviceAccount.create | bool | `true` | Specifies whether a service account should be created |
| serviceAccount.name | string | `""` | The name of the service account to use. If not set and create is true, a name is generated using the fullname template |
| tolerations | list | `[]` |  |
| transformer.image.pullPolicy | string | `"IfNotPresent"` |  |
| transformer.image.repository | string | `"labs64/auditflow-transformer"` |  |
| transformer.image.tag | string | `""` |  |
| transformer.service | object | `{"port":8081}` | This is for setting up a service more information can be found here: https://kubernetes.io/docs/concepts/services-networking/service/ |
| transformer.service.port | int | `8081` | This sets the ports more information can be found here: https://kubernetes.io/docs/concepts/services-networking/service/#field-spec-ports |
| volumeMounts | list | `[{"mountPath":"/etc/auditflow","name":"auditflow-pipelines","readOnly":true},{"mountPath":"/etc/auditflow/certs","name":"opensearch-truststore","readOnly":true}]` | Additional volumeMounts on the output Deployment definition. |
| volumes | list | `[{"configMap":{"name":"l64-local-au-auditflow-pipelines"},"name":"auditflow-pipelines"},{"name":"opensearch-truststore","secret":{"items":[{"key":"truststore.jks","path":"truststore.jks"}],"secretName":"opensearch-truststore-secret"}}]` | Additional volumes on the output Deployment definition. |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)

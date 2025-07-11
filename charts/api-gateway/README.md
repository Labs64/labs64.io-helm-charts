# api-gateway

![Version: 0.0.1](https://img.shields.io/badge/Version-0.0.1-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.0.1](https://img.shields.io/badge/AppVersion-0.0.1-informational?style=flat-square)

Labs64.IO :: API Gateway - A secure, high-performance entry point for managing and routing API traffic across Labs64.IO microservices

**Homepage:** <https://labs64.io>

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| labs64 | <info@labs64.com> |  |

## Source Code

* <https://github.com/Labs64/labs64.io-helm-charts>
* <https://github.com/Labs64/labs64.io-api-gateway>

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| file://../chart-libs | chart-libs | 0.0.1 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` |  |
| application | object | `{"audit":{"topicName":"labs64-audit-topic"},"defaultBroker":"rabbit","otel":{"exporter":{"otlp":{"endpoint":"http://otel-collector.observability.svc.cluster.local:4317"}}},"rabbitmq":{"enabled":true,"host":"rabbitmq.default.svc.cluster.local","port":5672}}` | Application properties |
| application.audit | object | `{"topicName":"labs64-audit-topic"}` | Audit gateway properties |
| application.audit.topicName | string | `"labs64-audit-topic"` | Audit topic name; default: labs64-audit-topic |
| application.defaultBroker | string | `"rabbit"` | Message broker; e.g. rabbit, kafka, etc. |
| application.otel | object | `{"exporter":{"otlp":{"endpoint":"http://otel-collector.observability.svc.cluster.local:4317"}}}` | Open Telemetry params |
| application.rabbitmq | object | `{"enabled":true,"host":"rabbitmq.default.svc.cluster.local","port":5672}` | RabbitMQ connection params |
| application.rabbitmq.enabled | bool | `true` | Use RabbitMQ message broker |
| application.rabbitmq.host | string | `"rabbitmq.default.svc.cluster.local"` | RabbitMQ host name; default: rabbitmq.<namespace>.svc.cluster.local |
| application.rabbitmq.port | int | `5672` | RabbitMQ port; default: 5672 |
| autoscaling | object | `{"enabled":true,"maxReplicas":3,"minReplicas":1,"targetCPUUtilizationPercentage":80}` | This section is for setting up autoscaling more information can be found here: https://kubernetes.io/docs/concepts/workloads/autoscaling/ |
| env | list | `[]` |  |
| fullnameOverride | string | `""` |  |
| image | object | `{"pullPolicy":"IfNotPresent","repository":"labs64/api-gateway","tag":""}` | This sets the container image more information can be found here: https://kubernetes.io/docs/concepts/containers/images/ |
| image.pullPolicy | string | `"IfNotPresent"` | This sets the pull policy for images. |
| image.tag | string | `""` | Overrides the image tag whose default is the chart appVersion. |
| imagePullSecrets | list | `[]` | This is for the secrets for pulling an image from a private repository more information can be found here: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/ |
| ingress | object | `{"annotations":{},"className":"nginx","enabled":false,"hosts":[{"host":"localhost","paths":[{"path":"/","pathType":"Prefix"}]}],"tls":[]}` | This block is for setting up the ingress for more information can be found here: https://kubernetes.io/docs/concepts/services-networking/ingress/ |
| livenessProbe | object | `{"failureThreshold":3,"httpGet":{"path":"/actuator/health/liveness","port":8080},"initialDelaySeconds":30,"periodSeconds":10,"timeoutSeconds":2}` | This is to setup the liveness probes more information can be found here: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/ |
| nameOverride | string | `""` | This is to override the chart name. |
| nodeSelector | object | `{}` |  |
| podAnnotations | object | `{}` | This is for setting Kubernetes Annotations to a Pod. For more information checkout: https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/ |
| podLabels | object | `{}` | This is for setting Kubernetes Labels to a Pod. For more information checkout: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/ |
| podSecurityContext | object | `{}` |  |
| rabbitmq | object | `{"auth":{"password":"labs64pw","username":"labs64"},"persistence":{"enabled":true,"size":"1Gi"},"replicaCount":2}` | RabbitMQ properties |
| rabbitmq.auth.password | string | `"labs64pw"` | RabbitMQ password; default: labs64pw |
| rabbitmq.auth.username | string | `"labs64"` | RabbitMQ username; default: labs64 |
| readinessProbe | object | `{"failureThreshold":3,"httpGet":{"path":"/actuator/health/readiness","port":8080},"initialDelaySeconds":10,"periodSeconds":5,"timeoutSeconds":2}` | This is to setup the readiness probes more information can be found here: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/ |
| replicaCount | int | `1` | This will set the replicaset count more information can be found here: https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/ |
| resources.requests.cpu | string | `"100m"` |  |
| resources.requests.memory | string | `"512Mi"` |  |
| securityContext | object | `{}` |  |
| service | object | `{"port":8080,"type":"LoadBalancer"}` | This is for setting up a service more information can be found here: https://kubernetes.io/docs/concepts/services-networking/service/ |
| service.port | int | `8080` | This sets the ports more information can be found here: https://kubernetes.io/docs/concepts/services-networking/service/#field-spec-ports |
| service.type | string | `"LoadBalancer"` | This sets the service type more information can be found here: https://kubernetes.io/docs/concepts/services-networking/service/#publishing-services-service-types |
| serviceAccount | object | `{"annotations":{},"automount":true,"create":true,"name":""}` | This section builds out the service account more information can be found here: https://kubernetes.io/docs/concepts/security/service-accounts/ |
| serviceAccount.annotations | object | `{}` | Annotations to add to the service account |
| serviceAccount.automount | bool | `true` | Automatically mount a ServiceAccount's API credentials? |
| serviceAccount.create | bool | `true` | Specifies whether a service account should be created |
| serviceAccount.name | string | `""` | The name of the service account to use. If not set and create is true, a name is generated using the fullname template |
| tolerations | list | `[]` |  |
| volumeMounts | list | `[]` | Additional volumeMounts on the output Deployment definition. |
| volumes | list | `[]` | Additional volumes on the output Deployment definition. |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)

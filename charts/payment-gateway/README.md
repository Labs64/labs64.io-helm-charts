# payment-gateway

![Version: 0.0.1](https://img.shields.io/badge/Version-0.0.1-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.0.1](https://img.shields.io/badge/AppVersion-0.0.1-informational?style=flat-square)

Labs64.IO :: Payment Gateway - Universal Payment Gateway for PSP Integration

**Homepage:** <https://labs64.io>

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| labs64 | <info@labs64.com> |  |

## Source Code

* <https://github.com/Labs64/labs64.io-helm-charts>
* <https://github.com/Labs64/labs64.io-payment-gateway>

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| file://../chart-libs | chart-libs | 0.0.1 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` |  |
| applicationYaml | object | `{"spring":{"data":{"redis":{"host":"redis-master.default.svc.cluster.local","password":"<TODO>","port":6379}},"datasource":{"password":"<TODO>","url":"jdbc:postgresql://postgresql-primary.default.svc.cluster.local:5432/payment_gateway","username":"<TODO>"},"rabbitmq":{"host":"rabbitmq.default.svc.cluster.local","password":"<TODO>","port":5672,"username":"<TODO>"}}}` | Additional application properties |
| applicationYaml.spring | object | `{"data":{"redis":{"host":"redis-master.default.svc.cluster.local","password":"<TODO>","port":6379}},"datasource":{"password":"<TODO>","url":"jdbc:postgresql://postgresql-primary.default.svc.cluster.local:5432/payment_gateway","username":"<TODO>"},"rabbitmq":{"host":"rabbitmq.default.svc.cluster.local","password":"<TODO>","port":5672,"username":"<TODO>"}}` | Spring configuration |
| applicationYaml.spring.data | object | `{"redis":{"host":"redis-master.default.svc.cluster.local","password":"<TODO>","port":6379}}` | Redis connection params |
| applicationYaml.spring.data.redis.host | string | `"redis-master.default.svc.cluster.local"` | Redis host; default: redis-master.<namespace>.svc.cluster.local |
| applicationYaml.spring.data.redis.password | string | `"<TODO>"` | Redis password |
| applicationYaml.spring.data.redis.port | int | `6379` | Redis port; default: 6379 |
| applicationYaml.spring.datasource | object | `{"password":"<TODO>","url":"jdbc:postgresql://postgresql-primary.default.svc.cluster.local:5432/payment_gateway","username":"<TODO>"}` | PostgreSQL connection params |
| applicationYaml.spring.datasource.password | string | `"<TODO>"` | PostgreSQL password |
| applicationYaml.spring.datasource.url | string | `"jdbc:postgresql://postgresql-primary.default.svc.cluster.local:5432/payment_gateway"` | JDBC connection URL to PostgreSQL |
| applicationYaml.spring.datasource.username | string | `"<TODO>"` | PostgreSQL username |
| applicationYaml.spring.rabbitmq | object | `{"host":"rabbitmq.default.svc.cluster.local","password":"<TODO>","port":5672,"username":"<TODO>"}` | RabbitMQ connection params |
| applicationYaml.spring.rabbitmq.host | string | `"rabbitmq.default.svc.cluster.local"` | RabbitMQ host name; default: rabbitmq.<namespace>.svc.cluster.local |
| applicationYaml.spring.rabbitmq.password | string | `"<TODO>"` | RabbitMQ password |
| applicationYaml.spring.rabbitmq.port | int | `5672` | RabbitMQ port; default: 5672 |
| applicationYaml.spring.rabbitmq.username | string | `"<TODO>"` | RabbitMQ username |
| autoscaling | object | `{"enabled":false,"maxReplicas":3,"minReplicas":1,"targetCPUUtilizationPercentage":80}` | This section is for setting up autoscaling more information can be found here: https://kubernetes.io/docs/concepts/workloads/autoscaling/ |
| chart-libs | object | `{}` | Values passed to the chart-libs library dependency (present so the generated schema accepts the key Helm injects for the dependency) @schema type: object additionalProperties: true @schema |
| env | list | `[]` |  |
| fullnameOverride | string | `""` |  |
| gateway | object | `{"enabled":false,"entryPoints":["web","websecure"],"prefix":"","routes":[{"path":"/api","port":8080,"roles":["admin-role","ecommerce-role","default-roles-labs64io"]},{"path":"/v3/api-docs","port":8080,"public":true,"stripPrefix":true}],"sharedMiddlewares":{"auth":"gateway-common-auth","rateLimit":"gateway-common-ratelimit","securityHeaders":"gateway-common-security-headers"}}` | Gateway routes published by this module (rendered by chart-libs.gateway-routes) |
| gateway.enabled | bool | `false` | Publish this module's routes on the Traefik gateway |
| gateway.entryPoints | list | `["web","websecure"]` | Traefik entry points |
| gateway.prefix | string | `""` | External path prefix; defaults to /<chart-name> |
| gateway.routes | list | `[{"path":"/api","port":8080,"roles":["admin-role","ecommerce-role","default-roles-labs64io"]},{"path":"/v3/api-docs","port":8080,"public":true,"stripPrefix":true}]` | Routes exposed by this module |
| gateway.routes[0] | object | `{"path":"/api","port":8080,"roles":["admin-role","ecommerce-role","default-roles-labs64io"]}` | Payment Gateway API (protected) |
| gateway.routes[1] | object | `{"path":"/v3/api-docs","port":8080,"public":true,"stripPrefix":true}` | OpenAPI docs (public, prefix stripped before forwarding) |
| gateway.sharedMiddlewares | object | `{"auth":"gateway-common-auth","rateLimit":"gateway-common-ratelimit","securityHeaders":"gateway-common-security-headers"}` | Names of the shared middlewares provided by the gateway-common chart |
| image | object | `{"pullPolicy":"IfNotPresent","repository":"labs64/payment-gateway","tag":""}` | This sets the container image more information can be found here: https://kubernetes.io/docs/concepts/containers/images/ |
| image.pullPolicy | string | `"IfNotPresent"` | This sets the pull policy for images. |
| image.tag | string | `""` | Overrides the image tag whose default is the chart appVersion. |
| imagePullSecrets | list | `[]` | This is for the secrets for pulling an image from a private repository more information can be found here: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/ |
| ingress | object | `{"annotations":{},"className":"nginx","enabled":false,"hosts":[{"host":"localhost","paths":[{"path":"/","pathType":"Prefix"}]}],"tls":[]}` | This block is for setting up the ingress for more information can be found here: https://kubernetes.io/docs/concepts/services-networking/ingress/ |
| ingressroute | object | `{"enabled":false,"entryPoints":["web","websecure"],"host":"localhost"}` | IngressRoute configuration for Traefik more information can be found here: https://doc.traefik.io/traefik/routing/providers/kubernetes-crd/ |
| ingressroute.enabled | bool | `false` | This sets whether the IngressRoute is enabled or not |
| ingressroute.entryPoints | list | `["web","websecure"]` | Entry points for the IngressRoute |
| ingressroute.host | string | `"localhost"` | Host for the IngressRoute |
| livenessProbe | object | `{"failureThreshold":3,"httpGet":{"path":"/actuator/health/liveness","port":8080},"initialDelaySeconds":30,"periodSeconds":10,"timeoutSeconds":2}` | This is to setup the liveness probes more information can be found here: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/ |
| nameOverride | string | `""` | This is to override the chart name. |
| networkPolicy | object | `{"enabled":false,"extraIngress":[],"gatewayNamespace":"tools"}` | NetworkPolicy: allow ingress from Traefik and same-namespace pods only (rendered by chart-libs.networkpolicy) |
| networkPolicy.extraIngress | list | `[]` | Additional raw ingress rules |
| networkPolicy.gatewayNamespace | string | `"tools"` | Namespace where Traefik runs |
| nodeSelector | object | `{}` |  |
| podAnnotations | object | `{}` | This is for setting Kubernetes Annotations to a Pod. For more information checkout: https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/ |
| podDisruptionBudget | object | `{"enabled":false,"minAvailable":1}` | PodDisruptionBudget (rendered by chart-libs.pdb) |
| podLabels | object | `{}` | This is for setting Kubernetes Labels to a Pod. For more information checkout: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/ |
| podSecurityContext | object | `{}` |  |
| rbac.create | bool | `false` |  |
| rbac.rules | list | `[]` |  |
| readinessProbe | object | `{"failureThreshold":3,"httpGet":{"path":"/actuator/health/readiness","port":8080},"initialDelaySeconds":10,"periodSeconds":5,"timeoutSeconds":2}` | This is to setup the readiness probes more information can be found here: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/ |
| replicaCount | int | `1` | This will set the replicaset count more information can be found here: https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/ |
| resources.requests.cpu | string | `"100m"` |  |
| resources.requests.memory | string | `"512Mi"` |  |
| secrets | object | `{"data":{}}` | Secret data to be used as environment variables |
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
| volumeMounts | list | `[]` | Additional volumeMounts on the output Deployment definition. |
| volumes | list | `[]` | Additional volumes on the output Deployment definition. |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)

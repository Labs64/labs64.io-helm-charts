# checkout

![Version: 0.2.0](https://img.shields.io/badge/Version-0.2.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.0.1](https://img.shields.io/badge/AppVersion-0.0.1-informational?style=flat-square)

Labs64.IO :: Checkout - Commerce-Ready Platform for Digital Sales Enablement

**Homepage:** <https://labs64.io>

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| labs64 | <info@labs64.com> |  |

## Source Code

* <https://github.com/Labs64/labs64.io-helm-charts>
* <https://github.com/Labs64/labs64.io-checkout>

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| file://../chart-libs | chart-libs | 0.1.0 |
| https://charts.bitnami.com/bitnami | postgresql | ^18.0.0 |
| https://charts.bitnami.com/bitnami | rabbitmq | ^16.0.0 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` |  |
| applicationYaml | object | `{"spring":{"datasource":{"url":"{{ ternary (printf \"jdbc:postgresql://%s-postgresql.%s.svc.cluster.local:5432/checkout\" .Release.Name .Release.Namespace) \"jdbc:postgresql://postgresql.tools.svc.cluster.local:5432/checkout\" .Values.postgresql.enabled }}"},"rabbitmq":{"host":"{{ ternary (printf \"%s-rabbitmq\" .Release.Name) \"rabbitmq.tools.svc.cluster.local\" .Values.rabbitmq.enabled }}","port":5672}}}` | Additional application properties |
| applicationYaml.spring | object | `{"datasource":{"url":"{{ ternary (printf \"jdbc:postgresql://%s-postgresql.%s.svc.cluster.local:5432/checkout\" .Release.Name .Release.Namespace) \"jdbc:postgresql://postgresql.tools.svc.cluster.local:5432/checkout\" .Values.postgresql.enabled }}"},"rabbitmq":{"host":"{{ ternary (printf \"%s-rabbitmq\" .Release.Name) \"rabbitmq.tools.svc.cluster.local\" .Values.rabbitmq.enabled }}","port":5672}}` | Spring configuration |
| applicationYaml.spring.datasource | object | `{"url":"{{ ternary (printf \"jdbc:postgresql://%s-postgresql.%s.svc.cluster.local:5432/checkout\" .Release.Name .Release.Namespace) \"jdbc:postgresql://postgresql.tools.svc.cluster.local:5432/checkout\" .Values.postgresql.enabled }}"}` | PostgreSQL connection params |
| applicationYaml.spring.datasource.url | string | `"{{ ternary (printf \"jdbc:postgresql://%s-postgresql.%s.svc.cluster.local:5432/checkout\" .Release.Name .Release.Namespace) \"jdbc:postgresql://postgresql.tools.svc.cluster.local:5432/checkout\" .Values.postgresql.enabled }}"` | JDBC URL; resolves to the bundled subchart when postgresql.enabled, else set your database URL |
| applicationYaml.spring.rabbitmq | object | `{"host":"{{ ternary (printf \"%s-rabbitmq\" .Release.Name) \"rabbitmq.tools.svc.cluster.local\" .Values.rabbitmq.enabled }}","port":5672}` | RabbitMQ connection params |
| applicationYaml.spring.rabbitmq.host | string | `"{{ ternary (printf \"%s-rabbitmq\" .Release.Name) \"rabbitmq.tools.svc.cluster.local\" .Values.rabbitmq.enabled }}"` | RabbitMQ host; resolves to the bundled subchart service when rabbitmq.enabled, else set your broker host |
| applicationYaml.spring.rabbitmq.port | int | `5672` | RabbitMQ port; default: 5672 |
| autoscaling | object | `{"enabled":false,"maxReplicas":3,"minReplicas":1,"targetCPUUtilizationPercentage":80}` | This section is for setting up autoscaling more information can be found here: https://kubernetes.io/docs/concepts/workloads/autoscaling/ |
| chart-libs | object | `{}` | Values passed to the chart-libs library dependency (present so the generated schema accepts the key Helm injects for the dependency) @schema type: object additionalProperties: true @schema |
| env | list | `[]` |  |
| fullnameOverride | string | `""` |  |
| gateway | object | `{"authPolicy":{"basePath":"","enabled":true},"enabled":false,"parentRefs":[{"name":"labs64io-gateway","namespace":"tools"}],"prefix":"","routes":[{"path":"/api/v1","port":8080,"stripPath":true},{"path":"/v3/api-docs","port":8080,"public":true,"stripPrefix":true}],"sharedMiddlewares":{"auth":"gateway-common-auth","compress":"gateway-common-compress","rateLimit":"gateway-common-ratelimit"}}` | Gateway routes published by this module (rendered by chart-libs.gateway-routes) |
| gateway.authPolicy | object | `{"basePath":"","enabled":true}` | Auth-policy discovery: label+annotations on the Service so the gateway's traefik-authproxy fetches this module's /.well-known/auth-policy and enforces the OpenAPI-declared per-operation policy at the edge. |
| gateway.authPolicy.basePath | string | `""` | External base path prepended to the module's OpenAPI paths; defaults to <prefix>/api/v1 |
| gateway.authPolicy.enabled | bool | `true` | Publish this module's auth policy to the gateway ACS |
| gateway.enabled | bool | `false` | Publish this module's routes on the Traefik gateway |
| gateway.parentRefs | list | `[{"name":"labs64io-gateway","namespace":"tools"}]` | Gateway API parent Gateway(s) this module's HTTPRoute attaches to |
| gateway.prefix | string | `""` | External path prefix; defaults to /<chart-name> |
| gateway.routes | list | `[{"path":"/api/v1","port":8080,"stripPath":true},{"path":"/v3/api-docs","port":8080,"public":true,"stripPrefix":true}]` | Routes exposed by this module |
| gateway.routes[0] | object | `{"path":"/api/v1","port":8080,"stripPath":true}` | Checkout API (protected; strips '<prefix>/api/v1' — backend is root-mapped) |
| gateway.routes[1] | object | `{"path":"/v3/api-docs","port":8080,"public":true,"stripPrefix":true}` | OpenAPI docs (public, prefix stripped before forwarding) |
| gateway.sharedMiddlewares | object | `{"auth":"gateway-common-auth","compress":"gateway-common-compress","rateLimit":"gateway-common-ratelimit"}` | Names of the shared middlewares provided by the gateway-common chart |
| global | object | `{"security":{"allowInsecureImages":true}}` | Global values shared across Labs64.IO charts and Bitnami subcharts @schema type: object additionalProperties: true @schema |
| global.security.allowInsecureImages | bool | `true` | Required by Bitnami subcharts when images are pulled from bitnamilegacy (image substitution guard) |
| gracefulShutdown.timeout | string | `"30s"` | Max time Spring Boot waits for in-flight requests before forced shutdown |
| image | object | `{"pullPolicy":"IfNotPresent","repository":"labs64/checkout","tag":""}` | This sets the container image more information can be found here: https://kubernetes.io/docs/concepts/containers/images/ |
| image.pullPolicy | string | `"IfNotPresent"` | This sets the pull policy for images. |
| image.tag | string | `""` | Overrides the image tag whose default is the chart appVersion. |
| imagePullSecrets | list | `[]` | This is for the secrets for pulling an image from a private repository more information can be found here: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/ |
| ingress | object | `{"annotations":{},"className":"nginx","enabled":false,"hosts":[{"host":"localhost","paths":[{"path":"/","pathType":"Prefix"}]}],"tls":[]}` | This block is for setting up the ingress for more information can be found here: https://kubernetes.io/docs/concepts/services-networking/ingress/ |
| lifecycle.preStopDrainSeconds | int | `5` | preStop sleep (seconds) so Traefik/kube-proxy deregister the pod before shutdown; 0 disables |
| livenessProbe | object | `{"failureThreshold":3,"httpGet":{"path":"/actuator/health/liveness","port":8080},"initialDelaySeconds":30,"periodSeconds":10,"timeoutSeconds":2}` | This is to setup the liveness probes more information can be found here: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/ |
| nameOverride | string | `""` | This is to override the chart name. |
| networkPolicy | object | `{"egress":[{"ports":[{"port":5672,"protocol":"TCP"}],"to":[{"namespaceSelector":{"matchLabels":{"kubernetes.io/metadata.name":"tools"}},"podSelector":{"matchLabels":{"app.kubernetes.io/name":"rabbitmq"}}}]},{"ports":[{"port":5432,"protocol":"TCP"}],"to":[{"namespaceSelector":{"matchLabels":{"kubernetes.io/metadata.name":"tools"}},"podSelector":{"matchLabels":{"app.kubernetes.io/name":"postgresql"}}}]}],"enabled":false,"extraIngress":[],"gatewayNamespace":"tools"}` | NetworkPolicy: allow ingress from Traefik and same-namespace pods only (rendered by chart-libs.networkpolicy) |
| networkPolicy.egress | list | `[{"ports":[{"port":5672,"protocol":"TCP"}],"to":[{"namespaceSelector":{"matchLabels":{"kubernetes.io/metadata.name":"tools"}},"podSelector":{"matchLabels":{"app.kubernetes.io/name":"rabbitmq"}}}]},{"ports":[{"port":5432,"protocol":"TCP"}],"to":[{"namespaceSelector":{"matchLabels":{"kubernetes.io/metadata.name":"tools"}},"podSelector":{"matchLabels":{"app.kubernetes.io/name":"postgresql"}}}]}]` | Egress rules enforcing database-per-service isolation. |
| networkPolicy.extraIngress | list | `[]` | Additional raw ingress rules |
| networkPolicy.gatewayNamespace | string | `"tools"` | Namespace where Traefik runs |
| nodeSelector | object | `{}` |  |
| observability | object | `{"enabled":false,"metricsPath":"/actuator/prometheus","otlpEndpoint":"http://$(NODE_IP):4318"}` | Observability is infrastructure-owned: the same image runs with or without it. When enabled, the bundled OTel Java Agent is activated via JAVA_TOOL_OPTIONS and Prometheus scrape annotations (Micrometer /actuator/prometheus) are added. |
| observability.enabled | bool | `false` | Enable runtime instrumentation (traces + logs via OTLP; metrics via Prometheus scrape) |
| observability.metricsPath | string | `"/actuator/prometheus"` | Prometheus metrics path scraped from the pod |
| observability.otlpEndpoint | string | `"http://$(NODE_IP):4318"` | OTLP endpoint of the OpenTelemetry Collector |
| podAnnotations | object | `{}` | This is for setting Kubernetes Annotations to a Pod. For more information checkout: https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/ |
| podDisruptionBudget | object | `{"enabled":false,"minAvailable":1}` | PodDisruptionBudget (rendered by chart-libs.pdb) |
| podLabels | object | `{}` | This is for setting Kubernetes Labels to a Pod. For more information checkout: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/ |
| podSecurityContext | object | `{}` |  |
| postgresql | object | `{"auth":{"database":"checkout","password":"labs64pw","username":"labs64"},"enabled":false,"image":{"repository":"bitnamilegacy/postgresql"}}` | Optional bundled PostgreSQL (Bitnami subchart) for standalone/local installs. Dev-grade credentials - NOT for production; point applicationYaml at your own database instead. @schema type: object additionalProperties: true @schema |
| postgresql.image | object | `{"repository":"bitnamilegacy/postgresql"}` | docker.io/bitnami versioned tags were moved to bitnamilegacy; keep in sync with the subchart's default tag @schema type: object additionalProperties: true @schema |
| rabbitmq | object | `{"auth":{"password":"labs64pw","username":"labs64"},"enabled":false,"image":{"repository":"bitnamilegacy/rabbitmq"}}` | Optional bundled RabbitMQ (Bitnami subchart) for standalone/local installs. Dev-grade credentials - NOT for production; point applicationYaml at your own broker instead. @schema type: object additionalProperties: true @schema |
| rabbitmq.image | object | `{"repository":"bitnamilegacy/rabbitmq"}` | docker.io/bitnami versioned tags were moved to bitnamilegacy; keep in sync with the subchart's default tag @schema type: object additionalProperties: true @schema |
| rbac.create | bool | `false` |  |
| rbac.rules | list | `[]` |  |
| readinessProbe | object | `{"failureThreshold":3,"httpGet":{"path":"/actuator/health/readiness","port":8080},"initialDelaySeconds":10,"periodSeconds":5,"timeoutSeconds":2}` | This is to setup the readiness probes more information can be found here: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/ |
| replicaCount | int | `1` | This will set the replicaset count more information can be found here: https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/ |
| resources.limits.cpu | string | `"500m"` |  |
| resources.limits.memory | string | `"1Gi"` |  |
| resources.requests.cpu | string | `"100m"` |  |
| resources.requests.memory | string | `"512Mi"` |  |
| secrets | object | `{"data":{}}` | Secret data to be used as environment variables (delivered via envFrom). External installs supply broker/database credentials here, e.g.   SPRING_RABBITMQ_USERNAME / SPRING_RABBITMQ_PASSWORD, SPRING_DATASOURCE_USERNAME / SPRING_DATASOURCE_PASSWORD. When rabbitmq.enabled=true / postgresql.enabled=true the chart adds these keys automatically from rabbitmq.auth / postgresql.auth. Keys you set here take precedence over the bundled-dep keys. On helm upgrade the Secret is deleted and recreated (hook-managed). Note: the Secret is hook-managed (pre-install) and survives helm uninstall. @schema type: object properties:   data:     type: object     additionalProperties: true @schema |
| securityContext.capabilities.drop[0] | string | `"ALL"` |  |
| securityContext.runAsGroup | int | `1064` |  |
| securityContext.runAsNonRoot | bool | `true` |  |
| securityContext.runAsUser | int | `1064` |  |
| securityContext.seccompProfile.type | string | `"RuntimeDefault"` |  |
| service | object | `{"port":8080,"type":"ClusterIP"}` | This is for setting up a service more information can be found here: https://kubernetes.io/docs/concepts/services-networking/service/ |
| service.port | int | `8080` | This sets the ports more information can be found here: https://kubernetes.io/docs/concepts/services-networking/service/#field-spec-ports |
| service.type | string | `"ClusterIP"` | This sets the service type more information can be found here: https://kubernetes.io/docs/concepts/services-networking/service/#publishing-services-service-types |
| serviceAccount | object | `{"annotations":{},"automount":true,"create":true,"name":""}` | This section builds out the service account more information can be found here: https://kubernetes.io/docs/concepts/security/service-accounts/ |
| serviceAccount.annotations | object | `{}` | Annotations to add to the service account |
| serviceAccount.automount | bool | `true` | Automatically mount a ServiceAccount's API credentials? |
| serviceAccount.create | bool | `true` | Specifies whether a service account should be created |
| serviceAccount.name | string | `""` | The name of the service account to use. If not set and create is true, a name is generated using the fullname template |
| slo | object | `{"availability":{"targetRatio":0.999},"enabled":true,"latency":{"targetRatio":0.99,"thresholdSeconds":0.5}}` | SLO recording rules and dashboards (rendered by chart-libs.slo.*) |
| startupProbe | object | `{"failureThreshold":30,"httpGet":{"path":"/actuator/health/liveness","port":8080},"periodSeconds":5,"timeoutSeconds":2}` | Startup probe (rendered by chart-libs.startupProbe): guards slow cold starts (Spring Boot + OTel Java Agent) so the liveness probe never kills a still-booting pod. Max boot budget = failureThreshold * periodSeconds. |
| terminationGracePeriodSeconds | int | `45` | Graceful shutdown: drain in-flight requests on rolling updates / scale-in. Keep terminationGracePeriodSeconds > lifecycle.preStopDrainSeconds + gracefulShutdown.timeout. |
| tests | object | `{"enabled":true,"healthPath":"/actuator/health"}` | helm test hook (rendered by chart-libs.test-connection) |
| tests.healthPath | string | `"/actuator/health"` | Health endpoint probed by `helm test` |
| tolerations | list | `[]` |  |
| volumeMounts | list | `[]` | Additional volumeMounts on the output Deployment definition. |
| volumes | list | `[]` | Additional volumes on the output Deployment definition. |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)

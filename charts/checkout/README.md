# checkout

![Version: 0.4.0](https://img.shields.io/badge/Version-0.4.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.0.1](https://img.shields.io/badge/AppVersion-0.0.1-informational?style=flat-square)

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
| file://../chart-libs | chart-libs | 0.2.0 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` |  |
| applicationType | string | `"java"` |  |
| applicationYaml | object | `{"spring":{"data":{"redis":{"host":"{{ if and .Values.global .Values.global.redis }}{{ .Values.global.redis.host | default \"redis.tools.svc.cluster.local\" }}{{ else }}redis.tools.svc.cluster.local{{ end }}","port":"{{ if and .Values.global .Values.global.redis }}{{ .Values.global.redis.port | default 6379 }}{{ else }}6379{{ end }}"}},"datasource":{"url":"jdbc:postgresql://{{ if and .Values.global .Values.global.postgresql }}{{ .Values.global.postgresql.host | default \"postgresql.tools.svc.cluster.local\" }}:{{ .Values.global.postgresql.port | default 5432 }}{{ else }}postgresql.tools.svc.cluster.local:5432{{ end }}/checkout"},"rabbitmq":{"host":"{{ if and .Values.global .Values.global.rabbitmq }}{{ .Values.global.rabbitmq.host | default \"rabbitmq.tools.svc.cluster.local\" }}{{ else }}rabbitmq.tools.svc.cluster.local{{ end }}","port":"{{ if and .Values.global .Values.global.rabbitmq }}{{ .Values.global.rabbitmq.port | default 5672 }}{{ else }}5672{{ end }}"}}}` | Additional application properties |
| applicationYaml.spring | object | `{"data":{"redis":{"host":"{{ if and .Values.global .Values.global.redis }}{{ .Values.global.redis.host | default \"redis.tools.svc.cluster.local\" }}{{ else }}redis.tools.svc.cluster.local{{ end }}","port":"{{ if and .Values.global .Values.global.redis }}{{ .Values.global.redis.port | default 6379 }}{{ else }}6379{{ end }}"}},"datasource":{"url":"jdbc:postgresql://{{ if and .Values.global .Values.global.postgresql }}{{ .Values.global.postgresql.host | default \"postgresql.tools.svc.cluster.local\" }}:{{ .Values.global.postgresql.port | default 5432 }}{{ else }}postgresql.tools.svc.cluster.local:5432{{ end }}/checkout"},"rabbitmq":{"host":"{{ if and .Values.global .Values.global.rabbitmq }}{{ .Values.global.rabbitmq.host | default \"rabbitmq.tools.svc.cluster.local\" }}{{ else }}rabbitmq.tools.svc.cluster.local{{ end }}","port":"{{ if and .Values.global .Values.global.rabbitmq }}{{ .Values.global.rabbitmq.port | default 5672 }}{{ else }}5672{{ end }}"}}` | Spring configuration |
| applicationYaml.spring.data.redis.host | string | `"{{ if and .Values.global .Values.global.redis }}{{ .Values.global.redis.host | default \"redis.tools.svc.cluster.local\" }}{{ else }}redis.tools.svc.cluster.local{{ end }}"` | Redis host |
| applicationYaml.spring.data.redis.port | string | `"{{ if and .Values.global .Values.global.redis }}{{ .Values.global.redis.port | default 6379 }}{{ else }}6379{{ end }}"` | Redis port |
| applicationYaml.spring.datasource.url | string | `"jdbc:postgresql://{{ if and .Values.global .Values.global.postgresql }}{{ .Values.global.postgresql.host | default \"postgresql.tools.svc.cluster.local\" }}:{{ .Values.global.postgresql.port | default 5432 }}{{ else }}postgresql.tools.svc.cluster.local:5432{{ end }}/checkout"` | JDBC URL; resolves to the bundled subchart when postgresql.enabled, else set your database URL Username/password are NOT set here — this block renders into a plain ConfigMap. Set credentials via `secrets.data.SPRING_DATASOURCE_USERNAME`/`SPRING_DATASOURCE_PASSWORD` (a Secret, injected via envFrom) instead — see `secrets.data` below. |
| applicationYaml.spring.rabbitmq.host | string | `"{{ if and .Values.global .Values.global.rabbitmq }}{{ .Values.global.rabbitmq.host | default \"rabbitmq.tools.svc.cluster.local\" }}{{ else }}rabbitmq.tools.svc.cluster.local{{ end }}"` | RabbitMQ host |
| applicationYaml.spring.rabbitmq.port | string | `"{{ if and .Values.global .Values.global.rabbitmq }}{{ .Values.global.rabbitmq.port | default 5672 }}{{ else }}5672{{ end }}"` | RabbitMQ port |
| autoscaling | object | `{"enabled":false,"maxReplicas":3,"minReplicas":1,"targetCPUUtilizationPercentage":80}` | This section is for setting up autoscaling more information can be found here: https://kubernetes.io/docs/concepts/workloads/autoscaling/ |
| chart-libs | object | `{}` | Values passed to the chart-libs library dependency (present so the generated schema accepts the key Helm injects for the dependency) @schema type: object additionalProperties: true @schema |
| enabled | bool | `true` |  |
| env | list | `[]` |  |
| envFrom | list | `[]` |  |
| externalSecrets.enabled | bool | `false` |  |
| externalSecrets.storeName | string | `"local-kubernetes-store"` |  |
| fullnameOverride | string | `""` |  |
| gateway | object | `{"annotations":{},"authPolicy":{"basePath":"","enabled":true},"enabled":false,"ingressClassName":"","parentRefs":[{"name":"labs64io-gateway","namespace":"tools"}],"prefix":"","routes":[{"path":"/api/v1","port":8080,"stripPath":true},{"path":"/v3/api-docs","port":8080,"public":true,"stripPrefix":true}],"sharedMiddlewares":{"auth":"gateway-common-auth","compress":"gateway-common-compress","rateLimit":"gateway-common-ratelimit"}}` | Gateway routes published by this module (rendered by chart-libs.gateway-routes) |
| gateway.annotations | object | `{}` | Annotations for fallback Ingress |
| gateway.authPolicy | object | `{"basePath":"","enabled":true}` | Auth-policy publication. NOTE: the traefik-authproxy no longer live-discovers per-module policies via /.well-known/auth-policy — it loads a generated routes manifest (charts/api-gateway/routes/) and asks the central Cerbos PDP for every decision. This block is retained for backward compatibility and is a no-op for edge enforcement. |
| gateway.authPolicy.basePath | string | `""` | External base path prepended to the module's OpenAPI paths; defaults to <prefix>/api/v1 |
| gateway.authPolicy.enabled | bool | `true` | Publish this module's auth policy to the gateway ACS |
| gateway.enabled | bool | `false` | Publish this module's routes on the Traefik gateway |
| gateway.ingressClassName | string | `""` | Ingress Class Name for fallback Ingress |
| gateway.parentRefs | list | `[{"name":"labs64io-gateway","namespace":"tools"}]` | Gateway API parent Gateway(s) this module's HTTPRoute attaches to |
| gateway.prefix | string | `""` | External path prefix; defaults to /<chart-name> |
| gateway.routes | list | `[{"path":"/api/v1","port":8080,"stripPath":true},{"path":"/v3/api-docs","port":8080,"public":true,"stripPrefix":true}]` | Routes exposed by this module |
| gateway.routes[0] | object | `{"path":"/api/v1","port":8080,"stripPath":true}` | Checkout API (protected; strips '<prefix>/api/v1' — backend is root-mapped) |
| gateway.routes[1] | object | `{"path":"/v3/api-docs","port":8080,"public":true,"stripPrefix":true}` | OpenAPI docs (public, prefix stripped before forwarding) |
| gateway.sharedMiddlewares | object | `{"auth":"gateway-common-auth","compress":"gateway-common-compress","rateLimit":"gateway-common-ratelimit"}` | Names of the shared middlewares provided by the api-gateway chart (fullnameOverride: gateway-common) |
| global | object | `{"security":{"allowInsecureImages":true}}` | Global values shared across Labs64.IO charts and Bitnami subcharts @schema type: object additionalProperties: true @schema |
| global.security.allowInsecureImages | bool | `true` | Required by Bitnami subcharts when images are pulled from bitnamilegacy (image substitution guard) |
| gracefulShutdown.timeout | string | `"30s"` | Max time Spring Boot waits for in-flight requests before forced shutdown |
| image | object | `{"pullPolicy":"IfNotPresent","repository":"labs64/checkout","tag":""}` | This sets the container image more information can be found here: https://kubernetes.io/docs/concepts/containers/images/ |
| image.pullPolicy | string | `"IfNotPresent"` | This sets the pull policy for images. |
| image.tag | string | `""` | Overrides the image tag whose default is the chart appVersion. |
| imagePullSecrets | list | `[]` | This is for the secrets for pulling an image from a private repository more information can be found here: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/ |
| lifecycle.preStopDrainSeconds | int | `5` | preStop sleep (seconds) so Traefik/kube-proxy deregister the pod before shutdown; 0 disables |
| livenessProbe | object | `{"failureThreshold":3,"httpGet":{"path":"/actuator/health/liveness","port":8080},"initialDelaySeconds":30,"periodSeconds":10,"timeoutSeconds":2}` | This is to setup the liveness probes more information can be found here: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/ |
| nameOverride | string | `""` | This is to override the chart name. |
| networkPolicy | object | `{"egress":[{"ports":[{"port":3593,"protocol":"TCP"}],"to":[{"podSelector":{"matchLabels":{"app.kubernetes.io/name":"authz-pdp"}}}]}],"enabled":false,"extraIngress":[],"gatewayNamespace":"tools","ingressControllerLabels":{},"observabilityNamespace":"monitoring","toolsEgress":[{"name":"rabbitmq","port":5672},{"name":"postgresql","port":5432}]}` | NetworkPolicy: allow ingress from Traefik and same-namespace pods only (rendered by chart-libs.networkpolicy) |
| networkPolicy.egress | list | `[{"ports":[{"port":3593,"protocol":"TCP"}],"to":[{"podSelector":{"matchLabels":{"app.kubernetes.io/name":"authz-pdp"}}}]}]` | Egress rules enforcing database-per-service isolation. |
| networkPolicy.extraIngress | list | `[]` | Additional raw ingress rules |
| networkPolicy.gatewayNamespace | string | `"tools"` | Namespace where Traefik runs |
| networkPolicy.ingressControllerLabels | object | `{}` | Ingress controller pod-selector labels; defaults to the internal Traefik standard (app.kubernetes.io/name: traefik) when empty @schema type: object additionalProperties: true @schema |
| networkPolicy.observabilityNamespace | string | `"monitoring"` | Namespace the observability/OTel collector runs in |
| networkPolicy.toolsEgress | list | `[{"name":"rabbitmq","port":5672},{"name":"postgresql","port":5432}]` | Tools-namespace destinations this service needs (name + port pairs); rendered as scoped egress rules — NOT a blanket allow to the whole tools namespace — to preserve database-per-service isolation. |
| nodeSelector | object | `{}` |  |
| observability | object | `{"enabled":false,"metricsPath":"/actuator/prometheus","otlpEndpoint":"http://$(NODE_IP):4318"}` | Observability is infrastructure-owned: the same image runs with or without it. When enabled, the bundled OTel Java Agent is activated via JAVA_TOOL_OPTIONS and Prometheus scrape annotations (Micrometer /actuator/prometheus) are added. |
| observability.enabled | bool | `false` | Enable runtime instrumentation (traces + logs via OTLP; metrics via Prometheus scrape) |
| observability.metricsPath | string | `"/actuator/prometheus"` | Prometheus metrics path scraped from the pod |
| observability.otlpEndpoint | string | `"http://$(NODE_IP):4318"` | OTLP endpoint of the OpenTelemetry Collector |
| podAnnotations | object | `{}` | This is for setting Kubernetes Annotations to a Pod. For more information checkout: https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/ |
| podDisruptionBudget | object | `{"enabled":false,"minAvailable":1}` | PodDisruptionBudget (rendered by chart-libs.pdb) |
| podLabels | object | `{}` | This is for setting Kubernetes Labels to a Pod. For more information checkout: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/ |
| podSecurityContext | object | `{}` |  |
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
| ui.application.runtimeEnv.enabled | bool | `true` | Enable loading a runtime config file (env.json). |
| ui.application.runtimeEnv.env | object | `{"VITE_API_URL":"https://<HOST>/checkout/api/v1"}` | Key-value pairs written into env.json. Keys should match variables your UI reads (for Vite, use the VITE_* prefix). |
| ui.application.runtimeEnv.env.VITE_API_URL | string | `"https://<HOST>/checkout/api/v1"` | Primary API base URL — replace <HOST> with your domain/host. |
| ui.application.runtimeEnv.path | string | `"/usr/share/nginx/html/config/env.json"` | Absolute path in the container where env.json is mounted and served from (must match Nginx/Ingress config). |
| ui.application.runtimeEnv.strict | bool | `true` | Strict mode: if true, the container must not start when env.json is missing/invalid (e.g., ConfigMap not mounted). |
| ui.chart-libs | object | `{}` | Values passed to the chart-libs library dependency (present so the generated schema accepts the key Helm injects for the dependency) @schema type: object additionalProperties: true @schema |
| ui.enabled | bool | `true` |  |
| ui.fullnameOverride | string | `""` |  |
| ui.gateway | object | `{"annotations":{},"enabled":false,"ingressClassName":"","parentRefs":[{"name":"labs64io-gateway","namespace":"tools"}],"prefix":"/checkout","routes":[{"path":"","port":8080,"public":true}],"sharedMiddlewares":{"auth":"gateway-common-auth","compress":"gateway-common-compress","rateLimit":"gateway-common-ratelimit"}}` | Gateway routes published by this module (rendered by chart-libs.ui-gateway-routes) |
| ui.gateway.annotations | object | `{}` | Annotations for fallback Ingress |
| ui.gateway.enabled | bool | `false` | Publish this module's routes on the Traefik gateway |
| ui.gateway.ingressClassName | string | `""` | Ingress Class Name for fallback Ingress |
| ui.gateway.parentRefs | list | `[{"name":"labs64io-gateway","namespace":"tools"}]` | Gateway API parent Gateway(s) this module's HTTPRoute attaches to |
| ui.gateway.prefix | string | `"/checkout"` | External path prefix; checkout-ui serves under /checkout |
| ui.gateway.routes | list | `[{"path":"","port":8080,"public":true}]` | Routes exposed by this module |
| ui.gateway.routes[0] | object | `{"path":"","port":8080,"public":true}` | Checkout UI static assets. Public: a plain browser navigation can't attach a Bearer token, and the auth-proxy's ForwardAuth policy set is generated from module OpenAPI specs, so it has no entry for a bare UI path anyway (would 403 regardless). The actual protected surface is the checkout-be API the SPA calls afterward. |
| ui.gateway.sharedMiddlewares | object | `{"auth":"gateway-common-auth","compress":"gateway-common-compress","rateLimit":"gateway-common-ratelimit"}` | Names of the shared middlewares provided by the api-gateway chart (fullnameOverride: gateway-common) |
| ui.image | object | `{"pullPolicy":"IfNotPresent","repository":"labs64/checkout-ui","tag":""}` | This sets the container image more information can be found here: https://kubernetes.io/docs/concepts/containers/images/ |
| ui.image.pullPolicy | string | `"IfNotPresent"` | This sets the pull policy for images. |
| ui.image.tag | string | `""` | Overrides the image tag whose default is the chart appVersion. |
| ui.imagePullSecrets | list | `[]` | This is for the secrets for pulling an image from a private repository more information can be found here: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/ |
| ui.nameOverride | string | `""` | This is to override the chart name. |
| ui.networkPolicy | object | `{"enabled":false,"extraIngress":[],"gatewayNamespace":"tools","ingressControllerLabels":{},"observabilityNamespace":"monitoring"}` | NetworkPolicy: allow ingress from Traefik and same-namespace pods only (rendered by chart-libs.networkpolicy) |
| ui.networkPolicy.extraIngress | list | `[]` | Additional raw ingress rules |
| ui.networkPolicy.gatewayNamespace | string | `"tools"` | Namespace where Traefik runs |
| ui.networkPolicy.ingressControllerLabels | object | `{}` | Ingress controller pod-selector labels; defaults to the internal Traefik standard (app.kubernetes.io/name: traefik) when empty @schema type: object additionalProperties: true @schema |
| ui.networkPolicy.observabilityNamespace | string | `"monitoring"` | Namespace the observability/OTel collector runs in |
| ui.podAnnotations | object | `{}` | This is for setting Kubernetes Annotations to a Pod. For more information checkout: https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/ |
| ui.podDisruptionBudget | object | `{"enabled":false,"minAvailable":1}` | PodDisruptionBudget (rendered by chart-libs.pdb) |
| ui.podLabels | object | `{}` | This is for setting Kubernetes Labels to a Pod. For more information checkout: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/ |
| ui.podSecurityContext | object | `{"fsGroup":101,"runAsGroup":101,"runAsNonRoot":true,"runAsUser":101,"seccompProfile":{"type":"RuntimeDefault"}}` | Non-root pod security context. The image is nginx-unprivileged (UID 101), so the whole pod runs unprivileged and listens on 8080. |
| ui.rbac.create | bool | `false` |  |
| ui.rbac.rules | list | `[]` |  |
| ui.replicaCount | int | `1` | This will set the replicaset count more information can be found here: https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/ |
| ui.securityContext.allowPrivilegeEscalation | bool | `false` |  |
| ui.securityContext.capabilities.drop[0] | string | `"ALL"` |  |
| ui.securityContext.readOnlyRootFilesystem | bool | `false` |  |
| ui.service | object | `{"port":8080,"type":"ClusterIP"}` | This is for setting up a service more information can be found here: https://kubernetes.io/docs/concepts/services-networking/service/ |
| ui.service.port | int | `8080` | This sets the ports more information can be found here: https://kubernetes.io/docs/concepts/services-networking/service/#field-spec-ports Non-privileged port served by nginx-unprivileged. |
| ui.service.type | string | `"ClusterIP"` | This sets the service type more information can be found here: https://kubernetes.io/docs/concepts/services-networking/service/#publishing-services-service-types |
| ui.serviceAccount | object | `{"annotations":{},"automount":true,"create":false,"name":""}` | This section builds out the service account more information can be found here: https://kubernetes.io/docs/concepts/security/service-accounts/ |
| ui.serviceAccount.annotations | object | `{}` | Annotations to add to the service account |
| ui.serviceAccount.automount | bool | `true` | Automatically mount a ServiceAccount's API credentials? |
| ui.serviceAccount.create | bool | `false` | Specifies whether a service account should be created |
| ui.serviceAccount.name | string | `""` | The name of the service account to use. If not set and create is true, a name is generated using the fullname template |
| ui.tests | object | `{"enabled":true,"healthPath":"/"}` | helm test hook (rendered by chart-libs.test-connection) |
| ui.tests.healthPath | string | `"/"` | Health endpoint probed by `helm test` |
| volumeMounts | list | `[]` | Additional volumeMounts on the output Deployment definition. |
| volumes | list | `[]` | Additional volumes on the output Deployment definition. |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)

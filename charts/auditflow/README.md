# auditflow

![Version: 0.5.0](https://img.shields.io/badge/Version-0.5.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.0.2](https://img.shields.io/badge/AppVersion-0.0.2-informational?style=flat-square)

Labs64.IO :: AuditFlow - Scalable Audit Logging for Modern Microservices

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
| file://../chart-libs | chart-libs | 0.1.0 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` | Affinity for pod assignment For more information: https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#affinity-and-anti-affinity |
| applicationType | string | `"java"` |  |
| applicationYaml | object | `{"auditflow":{"pipelines":[]},"secretRef":{"resolver":"k8s-secret"},"sink":{"discovery":{"mode":"local"},"local":{"url":"http://localhost:8082"},"service":{"name":"auditflow-sink","namespace":"default"}},"spring":{"data":{"redis":{"host":"{{ if and .Values.global .Values.global.redis }}{{ tpl (.Values.global.redis.host | default \"redis.tools.svc.cluster.local\") . }}{{ else }}redis.tools.svc.cluster.local{{ end }}","port":"{{ if and .Values.global .Values.global.redis }}{{ .Values.global.redis.port | default 6379 }}{{ else }}6379{{ end }}"}},"datasource":{"url":"jdbc:postgresql://{{ if and .Values.global .Values.global.postgresql }}{{ tpl (.Values.global.postgresql.host | default \"postgresql.tools.svc.cluster.local\") . }}:{{ .Values.global.postgresql.port | default 5432 }}{{ else }}postgresql.tools.svc.cluster.local:5432{{ end }}/auditflow"},"rabbitmq":{"host":"{{ if and .Values.global .Values.global.rabbitmq }}{{ tpl (.Values.global.rabbitmq.host | default \"rabbitmq.tools.svc.cluster.local\") . }}{{ else }}rabbitmq.tools.svc.cluster.local{{ end }}","port":"{{ if and .Values.global .Values.global.rabbitmq }}{{ .Values.global.rabbitmq.port | default 5672 }}{{ else }}5672{{ end }}"}},"tenants":{"consumer":{"max-in-flight-per-tenant":4},"ratelimit":{"backend":"redis"},"source":{"mode":"gitops-configmap"}},"transformer":{"discovery":{"mode":"local"},"local":{"url":"http://localhost:8081"},"service":{"name":"auditflow-transformer","namespace":"default"}}}` | Additional application properties |
| applicationYaml.auditflow | object | `{"pipelines":[]}` | AuditFlow application properties (bound by @ConfigurationProperties(prefix = "auditflow")) |
| applicationYaml.auditflow.pipelines | list | `[]` | Legacy global pipelines — MUST stay empty: pipelines are per-tenant now (see `tenants.platform.pipelines` below and the tenant ConfigMaps), and a non-empty list fails application startup by design. |
| applicationYaml.secretRef | object | `{"resolver":"k8s-secret"}` | Resolver for `${secretRef:<key>}` sink-credential indirection; "k8s-secret" reads the tenant's own Secret `auditflow-tenant-<tenantId>-creds` (requires rbac.create), "env" reads `AUDITFLOW_TENANT_<TENANTID>_<KEY>` environment variables |
| applicationYaml.sink | object | `{"discovery":{"mode":"local"},"local":{"url":"http://localhost:8082"},"service":{"name":"auditflow-sink","namespace":"default"}}` | Sink configuration |
| applicationYaml.sink.discovery | object | `{"mode":"local"}` | Discovery mode; "local" or "kubernetes" |
| applicationYaml.sink.local | object | `{"url":"http://localhost:8082"}` | Local URL for the sink service |
| applicationYaml.sink.service | object | `{"name":"auditflow-sink","namespace":"default"}` | Service name and namespace for the sink |
| applicationYaml.spring | object | `{"data":{"redis":{"host":"{{ if and .Values.global .Values.global.redis }}{{ tpl (.Values.global.redis.host | default \"redis.tools.svc.cluster.local\") . }}{{ else }}redis.tools.svc.cluster.local{{ end }}","port":"{{ if and .Values.global .Values.global.redis }}{{ .Values.global.redis.port | default 6379 }}{{ else }}6379{{ end }}"}},"datasource":{"url":"jdbc:postgresql://{{ if and .Values.global .Values.global.postgresql }}{{ tpl (.Values.global.postgresql.host | default \"postgresql.tools.svc.cluster.local\") . }}:{{ .Values.global.postgresql.port | default 5432 }}{{ else }}postgresql.tools.svc.cluster.local:5432{{ end }}/auditflow"},"rabbitmq":{"host":"{{ if and .Values.global .Values.global.rabbitmq }}{{ tpl (.Values.global.rabbitmq.host | default \"rabbitmq.tools.svc.cluster.local\") . }}{{ else }}rabbitmq.tools.svc.cluster.local{{ end }}","port":"{{ if and .Values.global .Values.global.rabbitmq }}{{ .Values.global.rabbitmq.port | default 5672 }}{{ else }}5672{{ end }}"}}` | Spring configuration |
| applicationYaml.spring.data.redis.host | string | `"{{ if and .Values.global .Values.global.redis }}{{ tpl (.Values.global.redis.host | default \"redis.tools.svc.cluster.local\") . }}{{ else }}redis.tools.svc.cluster.local{{ end }}"` | Redis host |
| applicationYaml.spring.data.redis.port | string | `"{{ if and .Values.global .Values.global.redis }}{{ .Values.global.redis.port | default 6379 }}{{ else }}6379{{ end }}"` | Redis port |
| applicationYaml.spring.datasource.url | string | `"jdbc:postgresql://{{ if and .Values.global .Values.global.postgresql }}{{ tpl (.Values.global.postgresql.host | default \"postgresql.tools.svc.cluster.local\") . }}:{{ .Values.global.postgresql.port | default 5432 }}{{ else }}postgresql.tools.svc.cluster.local:5432{{ end }}/auditflow"` | JDBC URL; resolves to the bundled subchart when postgresql.enabled, else set your database URL Username/password are NOT set here — this block renders into a plain ConfigMap. Set credentials via `secrets.data.SPRING_DATASOURCE_USERNAME`/`SPRING_DATASOURCE_PASSWORD` (a Secret, injected via envFrom) instead — see `secrets.data` below. |
| applicationYaml.spring.rabbitmq.host | string | `"{{ if and .Values.global .Values.global.rabbitmq }}{{ tpl (.Values.global.rabbitmq.host | default \"rabbitmq.tools.svc.cluster.local\") . }}{{ else }}rabbitmq.tools.svc.cluster.local{{ end }}"` | RabbitMQ host |
| applicationYaml.spring.rabbitmq.port | string | `"{{ if and .Values.global .Values.global.rabbitmq }}{{ .Values.global.rabbitmq.port | default 5672 }}{{ else }}5672{{ end }}"` | RabbitMQ port |
| applicationYaml.tenants | object | `{"consumer":{"max-in-flight-per-tenant":4},"ratelimit":{"backend":"redis"},"source":{"mode":"gitops-configmap"}}` | Tenant model (silo isolation) — the chart pins the Kubernetes-native modes; the application's built-in defaults are the cluster-free ones (local-dir / in-memory / env). Keys below are exact Spring property paths (@Value binding, no relaxed naming) — keep kebab-case. |
| applicationYaml.tenants.consumer.max-in-flight-per-tenant | int | `4` | Max concurrently-processed events per tenant on the consumer side (fairness layer 2) |
| applicationYaml.tenants.ratelimit.backend | string | `"redis"` | Per-tenant ingest rate-limit backend; "redis" is correct with >1 replica (the application default "in-memory" is single-replica only) |
| applicationYaml.tenants.source.mode | string | `"gitops-configmap"` | Tenant config source; "gitops-configmap" watches ConfigMaps labelled `auditflow.io/tenant` in the release namespace (requires rbac.create), "local-dir" polls a mounted directory |
| applicationYaml.transformer | object | `{"discovery":{"mode":"local"},"local":{"url":"http://localhost:8081"},"service":{"name":"auditflow-transformer","namespace":"default"}}` | Transformer configuration |
| applicationYaml.transformer.discovery | object | `{"mode":"local"}` | Discovery mode; "local" or "kubernetes" |
| applicationYaml.transformer.local | object | `{"url":"http://localhost:8081"}` | Local URL for the transformer service |
| applicationYaml.transformer.service | object | `{"name":"auditflow-transformer","namespace":"default"}` | Service name and namespace for the transformer |
| autoscaling | object | `{"enabled":false,"maxReplicas":3,"minReplicas":1,"targetCPUUtilizationPercentage":80}` | This section is for setting up autoscaling more information can be found here: https://kubernetes.io/docs/concepts/workloads/autoscaling/ |
| chart-libs | object | `{}` | Values passed to the chart-libs library dependency (present so the generated schema accepts the key Helm injects for the dependency) @schema type: object additionalProperties: true @schema |
| enabled | bool | `true` |  |
| env | list | `[]` | Environment variables to add to the container |
| envFrom | list | `[]` |  |
| externalSecrets.enabled | bool | `false` |  |
| externalSecrets.storeName | string | `"local-kubernetes-store"` |  |
| extraContainers | string | `"- name: auditflow-transformer\n  image: '{{ .Values.transformer.image.repository }}:{{ .Values.transformer.image.tag | default .Chart.AppVersion }}'\n  imagePullPolicy: '{{ .Values.transformer.image.pullPolicy }}'\n  ports:\n    - name: http-trn\n      containerPort: {{ .Values.transformer.service.port }}\n      protocol: TCP\n  env:\n    - name: APP_NAME\n      value: \"auditflow-transformer\"\n    - name: HOSTNAME\n      valueFrom:\n        fieldRef:\n          fieldPath: status.podIP\n  {{- if $.Values.observability.enabled }}\n    - name: NODE_IP\n      valueFrom:\n        fieldRef:\n          fieldPath: status.hostIP\n    - name: OTEL_SERVICE_NAME\n      value: \"auditflow-transformer\"\n    - name: OTEL_EXPORTER_OTLP_ENDPOINT\n      value: '{{ $.Values.observability.otlpEndpoint | quote }}'\n    - name: OTEL_EXPORTER_OTLP_PROTOCOL\n      value: \"http/protobuf\"\n    - name: OTEL_PYTHON_LOG_CORRELATION\n      value: \"true\"\n    - name: OTEL_PYTHON_LOGGING_AUTO_INSTRUMENTATION_ENABLED\n      value: \"true\"\n    - name: OTEL_LOGS_EXPORTER\n      value: \"otlp\"\n    - name: OTEL_METRICS_EXPORTER\n      value: \"otlp\"\n  {{- end }}\n  livenessProbe:\n    httpGet:\n      path: /live\n      port: http-trn\n    initialDelaySeconds: 10\n    periodSeconds: 10\n    failureThreshold: 3\n    timeoutSeconds: 2\n  readinessProbe:\n    httpGet:\n      path: /ready\n      port: http-trn\n    initialDelaySeconds: 5\n    periodSeconds: 5\n    failureThreshold: 3\n    timeoutSeconds: 2\n  volumeMounts:\n    - name: tmp\n      mountPath: /tmp\n\n- name: auditflow-sink\n  image: '{{ .Values.sink.image.repository }}:{{ .Values.sink.image.tag | default .Chart.AppVersion }}'\n  imagePullPolicy: '{{ .Values.sink.image.pullPolicy }}'\n  ports:\n    - name: http-snk\n      containerPort: {{ .Values.sink.service.port }}\n      protocol: TCP\n  env:\n    - name: APP_NAME\n      value: \"auditflow-sink\"\n    - name: HOSTNAME\n      valueFrom:\n        fieldRef:\n          fieldPath: status.podIP\n  {{- if $.Values.observability.enabled }}\n    - name: NODE_IP\n      valueFrom:\n        fieldRef:\n          fieldPath: status.hostIP\n    - name: OTEL_SERVICE_NAME\n      value: \"auditflow-sink\"\n    - name: OTEL_EXPORTER_OTLP_ENDPOINT\n      value: '{{ $.Values.observability.otlpEndpoint | quote }}'\n    - name: OTEL_EXPORTER_OTLP_PROTOCOL\n      value: \"http/protobuf\"\n    - name: OTEL_PYTHON_LOG_CORRELATION\n      value: \"true\"\n    - name: OTEL_PYTHON_LOGGING_AUTO_INSTRUMENTATION_ENABLED\n      value: \"true\"\n    - name: OTEL_LOGS_EXPORTER\n      value: \"otlp\"\n    - name: OTEL_METRICS_EXPORTER\n      value: \"otlp\"\n  {{- end }}\n  livenessProbe:\n    httpGet:\n      path: /live\n      port: http-snk\n    initialDelaySeconds: 10\n    periodSeconds: 10\n    failureThreshold: 3\n    timeoutSeconds: 2\n  readinessProbe:\n    httpGet:\n      path: /ready\n      port: http-snk\n    initialDelaySeconds: 5\n    periodSeconds: 5\n    failureThreshold: 3\n    timeoutSeconds: 2\n  volumeMounts:\n    - name: tmp\n      mountPath: /tmp\n"` |  |
| fullnameOverride | string | `""` |  |
| gateway | object | `{"annotations":{},"authPolicy":{"basePath":"","enabled":true},"enabled":false,"ingressClassName":"","parentRefs":[{"name":"labs64io-gateway","namespace":"tools"}],"prefix":"","routes":[{"path":"/api/v1","port":8080,"stripPath":true},{"path":"/v3/api-docs","port":8080,"public":true,"stripPrefix":true}],"sharedMiddlewares":{"auth":"gateway-common-auth","buffering":"gateway-common-buffering","compress":"gateway-common-compress","rateLimit":"gateway-common-ratelimit"}}` | Gateway routes published by this module (rendered by chart-libs.gateway-routes) |
| gateway.annotations | object | `{}` | Annotations for fallback Ingress |
| gateway.authPolicy | object | `{"basePath":"","enabled":true}` | Auth-policy publication. NOTE: the traefik-authproxy no longer live-discovers per-module policies via /.well-known/auth-policy — it loads a generated routes manifest (charts/api-gateway/routes/) and asks the central Cerbos PDP for every decision. This block is retained for backward compatibility and is a no-op for edge enforcement. |
| gateway.authPolicy.basePath | string | `""` | External base path prepended to the module's OpenAPI paths; defaults to <prefix>/api/v1 |
| gateway.authPolicy.enabled | bool | `true` | Publish this module's auth policy to the gateway ACS |
| gateway.enabled | bool | `false` | Publish this module's routes on the Traefik gateway |
| gateway.ingressClassName | string | `""` | Ingress Class Name for fallback Ingress |
| gateway.parentRefs | list | `[{"name":"labs64io-gateway","namespace":"tools"}]` | Gateway API parent Gateway(s) this module's HTTPRoute attaches to |
| gateway.prefix | string | `""` | External path prefix; defaults to /<chart-name> |
| gateway.routes | list | `[{"path":"/api/v1","port":8080,"stripPath":true},{"path":"/v3/api-docs","port":8080,"public":true,"stripPrefix":true}]` | Routes exposed by this module |
| gateway.routes[0] | object | `{"path":"/api/v1","port":8080,"stripPath":true}` | AuditFlow API (protected; strips '<prefix>/api/v1' — backend is root-mapped) |
| gateway.routes[1] | object | `{"path":"/v3/api-docs","port":8080,"public":true,"stripPrefix":true}` | OpenAPI docs (public, prefix stripped before forwarding) |
| gateway.sharedMiddlewares | object | `{"auth":"gateway-common-auth","buffering":"gateway-common-buffering","compress":"gateway-common-compress","rateLimit":"gateway-common-ratelimit"}` | Names of the shared middlewares provided by the api-gateway chart (fullnameOverride: gateway-common) |
| global | object | `{"security":{"allowInsecureImages":true}}` | Global values shared across Labs64.IO charts and Bitnami subcharts @schema type: object additionalProperties: true @schema |
| global.security.allowInsecureImages | bool | `true` | Required by Bitnami subcharts when images are pulled from bitnamilegacy (image substitution guard) |
| gracefulShutdown.timeout | string | `"30s"` | Max time Spring Boot waits for in-flight work before forced shutdown |
| image | object | `{"pullPolicy":"IfNotPresent","repository":"labs64/auditflow","tag":""}` | This sets the container image more information can be found here: https://kubernetes.io/docs/concepts/containers/images/ |
| image.pullPolicy | string | `"IfNotPresent"` | This sets the pull policy for images. |
| image.tag | string | `""` | Overrides the image tag whose default is the chart appVersion. |
| imagePullSecrets | list | `[]` | This is for the secrets for pulling an image from a private repository more information can be found here: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/ |
| lifecycle.preStopDrainSeconds | int | `5` | preStop sleep (seconds) so Traefik/kube-proxy deregister the pod before shutdown; 0 disables |
| livenessProbe | object | `{"failureThreshold":3,"httpGet":{"path":"/actuator/health/liveness","port":8080},"initialDelaySeconds":30,"periodSeconds":10,"timeoutSeconds":2}` | This is to setup the liveness probes more information can be found here: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/ |
| nameOverride | string | `""` | This is to override the chart name. |
| networkPolicy | object | `{"egress":[{"ports":[{"port":3593,"protocol":"TCP"}],"to":[{"podSelector":{"matchLabels":{"app.kubernetes.io/name":"authz-pdp"}}}]},{"ports":[{"port":443,"protocol":"TCP"},{"port":6443,"protocol":"TCP"}],"to":[{"ipBlock":{"cidr":"0.0.0.0/0"}}]}],"enabled":false,"extraIngress":[],"gatewayNamespace":"tools","ingressControllerLabels":{},"observabilityNamespace":"monitoring","toolsEgress":[{"name":"rabbitmq","port":5672},{"name":"redis","port":6379}]}` | NetworkPolicy: allow ingress from Traefik and same-namespace pods only (rendered by chart-libs.networkpolicy) |
| networkPolicy.egress | list | `[{"ports":[{"port":3593,"protocol":"TCP"}],"to":[{"podSelector":{"matchLabels":{"app.kubernetes.io/name":"authz-pdp"}}}]},{"ports":[{"port":443,"protocol":"TCP"},{"port":6443,"protocol":"TCP"}],"to":[{"ipBlock":{"cidr":"0.0.0.0/0"}}]}]` | Egress rules enforcing database-per-service isolation. |
| networkPolicy.extraIngress | list | `[]` | Additional raw ingress rules |
| networkPolicy.gatewayNamespace | string | `"tools"` | Namespace where Traefik runs |
| networkPolicy.ingressControllerLabels | object | `{}` | Ingress controller pod-selector labels; defaults to the internal Traefik standard (app.kubernetes.io/name: traefik) when empty @schema type: object additionalProperties: true @schema |
| networkPolicy.observabilityNamespace | string | `"monitoring"` | Namespace the observability/OTel collector runs in |
| networkPolicy.toolsEgress | list | `[{"name":"rabbitmq","port":5672},{"name":"redis","port":6379}]` | Tools-namespace destinations this service needs (name + port pairs); rendered as scoped egress rules — NOT a blanket allow to the whole tools namespace — to preserve database-per-service isolation. |
| nodeSelector | object | `{}` | Node labels for pod assignment For more information: https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/ |
| observability | object | `{"enabled":false,"otlpEndpoint":"http://$(NODE_IP):4318"}` | Observability is an infrastructure concern: the same images run with or without it. When enabled, the backend's bundled OTel Java Agent is activated via JAVA_TOOL_OPTIONS and the Python sidecars start under opentelemetry-instrument (triggered by the OTLP endpoint env). Java metrics stay on Micrometer via /actuator/prometheus (prometheus.io/* pod annotations are added automatically when enabled). |
| observability.enabled | bool | `false` | Enable runtime instrumentation (traces + logs OTLP, Prometheus-annotation metrics scrape) |
| observability.otlpEndpoint | string | `"http://$(NODE_IP):4318"` | OTLP endpoint of the OpenTelemetry Collector |
| podAnnotations | object | `{}` | This is for setting Kubernetes Annotations to a Pod. For more information checkout: https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/ |
| podDisruptionBudget | object | `{"enabled":false,"minAvailable":1}` | PodDisruptionBudget (rendered by chart-libs.pdb) |
| podLabels | object | `{}` | This is for setting Kubernetes Labels to a Pod. For more information checkout: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/ |
| podSecurityContext.fsGroup | int | `1064` |  |
| podSecurityContext.runAsGroup | int | `1064` |  |
| podSecurityContext.runAsNonRoot | bool | `true` |  |
| podSecurityContext.runAsUser | int | `1064` |  |
| podSecurityContext.seccompProfile.type | string | `"RuntimeDefault"` |  |
| rbac.create | bool | `true` |  |
| rbac.rules[0].apiGroups[0] | string | `""` |  |
| rbac.rules[0].resources[0] | string | `"configmaps"` |  |
| rbac.rules[0].verbs[0] | string | `"get"` |  |
| rbac.rules[0].verbs[1] | string | `"list"` |  |
| rbac.rules[0].verbs[2] | string | `"watch"` |  |
| rbac.rules[1].apiGroups[0] | string | `""` |  |
| rbac.rules[1].resources[0] | string | `"secrets"` |  |
| rbac.rules[1].verbs[0] | string | `"get"` |  |
| rbac.rules[2].apiGroups[0] | string | `""` |  |
| rbac.rules[2].resources[0] | string | `"services"` |  |
| rbac.rules[2].verbs[0] | string | `"get"` |  |
| readinessProbe | object | `{"failureThreshold":3,"httpGet":{"path":"/actuator/health/readiness","port":8080},"initialDelaySeconds":10,"periodSeconds":5,"timeoutSeconds":2}` | This is to setup the readiness probes more information can be found here: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/ |
| replicaCount | int | `1` | This will set the replicaset count more information can be found here: https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/ |
| resources | object | `{"limits":{"cpu":"500m","memory":"1Gi"},"requests":{"cpu":"100m","memory":"512Mi"}}` | Resource limits and requests for the container For production, it's recommended to set both requests and limits |
| secrets | object | `{"data":{}}` | Secret data to be used as environment variables (delivered via envFrom). External installs supply broker credentials here, e.g.   SPRING_RABBITMQ_USERNAME / SPRING_RABBITMQ_PASSWORD. When rabbitmq.enabled=true the chart adds these keys automatically from rabbitmq.auth. Keys you set here take precedence over the bundled-dep keys. On helm upgrade the Secret is deleted and recreated (hook-managed). Note: the Secret is hook-managed (pre-install) and survives helm uninstall. @schema type: object properties:   data:     type: object     additionalProperties: true @schema |
| securityContext.allowPrivilegeEscalation | bool | `false` |  |
| securityContext.capabilities.drop[0] | string | `"ALL"` |  |
| securityContext.readOnlyRootFilesystem | bool | `true` |  |
| service | object | `{"port":8080,"type":"ClusterIP"}` | This is for setting up a service more information can be found here: https://kubernetes.io/docs/concepts/services-networking/service/ |
| service.port | int | `8080` | This sets the ports more information can be found here: https://kubernetes.io/docs/concepts/services-networking/service/#field-spec-ports |
| service.type | string | `"ClusterIP"` | This sets the service type more information can be found here: https://kubernetes.io/docs/concepts/services-networking/service/#publishing-services-service-types |
| serviceAccount | object | `{"annotations":{},"automount":true,"create":true,"name":""}` | This section builds out the service account more information can be found here: https://kubernetes.io/docs/concepts/security/service-accounts/ |
| serviceAccount.annotations | object | `{}` | Annotations to add to the service account |
| serviceAccount.automount | bool | `true` | Automatically mount a ServiceAccount's API credentials? |
| serviceAccount.create | bool | `true` | Specifies whether a service account should be created |
| serviceAccount.name | string | `""` | The name of the service account to use. If not set and create is true, a name is generated using the fullname template |
| sink.image.pullPolicy | string | `"IfNotPresent"` |  |
| sink.image.repository | string | `"labs64/auditflow-sink"` |  |
| sink.image.tag | string | `""` |  |
| sink.resources | object | `{"limits":{"cpu":"200m","memory":"256Mi"},"requests":{"cpu":"50m","memory":"128Mi"}}` | Resource requests/limits for the sink sidecar (lightweight Python/FastAPI service). |
| sink.service | object | `{"port":8082}` | This is for setting up a service more information can be found here: https://kubernetes.io/docs/concepts/services-networking/service/ |
| sink.service.port | int | `8082` | This sets the ports more information can be found here: https://kubernetes.io/docs/concepts/services-networking/service/#field-spec-ports |
| slo | object | `{"availability":{"targetRatio":0.999},"enabled":true,"latency":{"targetRatio":0.99,"thresholdSeconds":0.5}}` | SLO recording rules and dashboards (rendered by chart-libs.slo.*) |
| startupProbe | object | `{"failureThreshold":30,"httpGet":{"path":"/actuator/health/liveness","port":8080},"periodSeconds":5,"timeoutSeconds":2}` | Startup probe (rendered by chart-libs.startupProbe): guards slow cold starts (Spring Boot + OTel Java Agent) so the liveness probe never kills a still-booting pod. Max boot budget = failureThreshold * periodSeconds. |
| tenants | object | `{"additional":[],"platform":{"burst":400,"pipelines":[{"enabled":true,"name":"platform-logging","sink":{"name":"logging_sink","properties":{"log-level":"INFO"}}}],"rateLimitPerSec":200}}` | Tenant provisioning shipped by the chart (rendered as `auditflow.io/tenant`-labelled ConfigMaps consumed live by the gitops-configmap source — see templates/tenant-configmaps.yaml). |
| tenants.additional | list | `[]` | Additional tenants to provision with the release: a list of full tenant documents ({tenantId, enabled, quota, pipelines}); each renders as its own labelled ConfigMap. Tenants can also be onboarded at any time by applying such a ConfigMap out-of-band (GitOps). @schema type: array items:   type: object   additionalProperties: true @schema |
| tenants.platform | object | `{"burst":400,"pipelines":[{"enabled":true,"name":"platform-logging","sink":{"name":"logging_sink","properties":{"log-level":"INFO"}}}],"rateLimitPerSec":200}` | The reserved `_platform` pseudo-tenant for tenantless/platform events. Shipped by default so platform events flow out of the box; K8s object name/label use the sanitized `platform`, the body keeps the canonical `_platform`. |
| tenants.platform.burst | int | `400` | Per-tenant ingest rate limit: burst capacity |
| tenants.platform.pipelines | list | `[{"enabled":true,"name":"platform-logging","sink":{"name":"logging_sink","properties":{"log-level":"INFO"}}}]` | The platform tenant's pipelines (same shape as the former global auditflow.pipelines) @schema type: array items:   type: object   additionalProperties: true @schema |
| tenants.platform.rateLimitPerSec | int | `200` | Per-tenant ingest rate limit (token bucket): sustained events/second |
| terminationGracePeriodSeconds | int | `45` | Graceful shutdown: drain in-flight requests / message handlers on rolling updates and scale-in. Keep terminationGracePeriodSeconds > preStop + gracefulShutdown.timeout. |
| tests | object | `{"enabled":true,"healthPath":"/actuator/health"}` | helm test hook (rendered by chart-libs.test-connection) |
| tests.healthPath | string | `"/actuator/health"` | Health endpoint probed by `helm test` |
| tolerations | list | `[]` | Tolerations for pod assignment For more information: https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/ |
| transformer.image.pullPolicy | string | `"IfNotPresent"` |  |
| transformer.image.repository | string | `"labs64/auditflow-transformer"` |  |
| transformer.image.tag | string | `""` |  |
| transformer.resources | object | `{"limits":{"cpu":"200m","memory":"256Mi"},"requests":{"cpu":"50m","memory":"128Mi"}}` | Resource requests/limits for the transformer sidecar (lightweight Python/FastAPI service). |
| transformer.service | object | `{"port":8081}` | This is for setting up a service more information can be found here: https://kubernetes.io/docs/concepts/services-networking/service/ |
| transformer.service.port | int | `8081` | This sets the ports more information can be found here: https://kubernetes.io/docs/concepts/services-networking/service/#field-spec-ports |
| volumeMounts | list | `[]` | Additional volumeMounts on the output Deployment definition. |
| volumes | list | `[]` | Additional volumes on the output Deployment definition. |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)

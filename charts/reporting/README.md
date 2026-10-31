# reporting

![Version: 0.1.1](https://img.shields.io/badge/Version-0.1.1-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.0.1](https://img.shields.io/badge/AppVersion-0.0.1-informational?style=flat-square)

Labs64.IO :: Reporting - read-only reports over the events stored by AuditFlow sinks

**Homepage:** <https://labs64.io>

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| Labs64 | <info@labs64.com> | <https://labs64.io> |

## Source Code

* <https://github.com/Labs64/labs64.io-helm-charts>
* <https://github.com/Labs64/labs64.io-reporting>

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| file://../chart-libs | chart-libs | 0.8.8 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` |  |
| applicationType | string | `"java"` |  |
| applicationYaml | object | `{"labs64":{"reporting":{"clickhouse":{"url":"http://labs64io-clickhouse:8123","username":"reporting"}}}}` | Additional application properties, including top-level prefixes owned by provider JARs @schema type: object additionalProperties: true @schema |
| applicationYaml.labs64.reporting.clickhouse.url | string | `"http://labs64io-clickhouse:8123"` | The umbrella chart's pinned ClickHouse Service. The password is a Secret: CLICKHOUSE_PASSWORD. |
| autoscaling | object | `{"enabled":false,"maxReplicas":3,"minReplicas":1,"targetCPUUtilizationPercentage":80}` | This section is for setting up autoscaling more information can be found here: https://kubernetes.io/docs/concepts/workloads/autoscaling/ |
| chart-libs | object | `{}` | Values passed to the chart-libs library dependency (present so the generated schema accepts the key Helm injects for the dependency) @schema type: object additionalProperties: true @schema |
| enabled | bool | `true` |  |
| env | list | `[]` |  |
| envFrom | list | `[]` |  |
| externalSecrets.enabled | bool | `false` |  |
| externalSecrets.secretKey | string | `""` | Key/path of this module's secret in the external backend; every key becomes an env var. Defaults to the release fullname. |
| externalSecrets.storeName | string | `"local-kubernetes-store"` |  |
| fastStartup | bool | `false` | Optimize for container startup time (-XX:TieredStopAtLevel=1, C1-only JIT) instead of sustained throughput. Local dev wants it on; prod wants it off (the default). |
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
| gateway.routes | list | `[{"path":"/api/v1","port":8080,"stripPath":true},{"path":"/v3/api-docs","port":8080,"public":true,"stripPrefix":true}]` | Routes exposed by this module. The whole API surface is ONE route through ForwardAuth: the authproxy is the PEP and derives public-vs-protected per operation from OpenAPI OAuth security plus x-labs64.auth (generated into the authproxy routes manifest + the central Cerbos PDP). Public operations. |
| gateway.routes[0] | object | `{"path":"/api/v1","port":8080,"stripPath":true}` | Whole Reporting API (ForwardAuth PEP decides per-op from OpenAPI; strips '<prefix>/api/v1' — backend is root-mapped) |
| gateway.routes[1] | object | `{"path":"/v3/api-docs","port":8080,"public":true,"stripPrefix":true}` | OpenAPI docs (springdoc endpoint — NOT an OpenAPI operation, so it has no generated OpenAPI auth policy at the authproxy; public at the edge, prefix stripped) |
| gateway.sharedMiddlewares | object | `{"auth":"gateway-common-auth","compress":"gateway-common-compress","rateLimit":"gateway-common-ratelimit"}` | Names of the shared middlewares provided by the api-gateway chart (fullnameOverride: gateway-common) |
| global | object | `{"security":{"allowInsecureImages":true}}` | Global values shared across Labs64.IO charts and Bitnami subcharts @schema type: object additionalProperties: true @schema |
| global.security.allowInsecureImages | bool | `true` | Required by Bitnami subcharts when images are pulled from bitnamilegacy (image substitution guard) |
| gracefulShutdown.timeout | string | `"30s"` | Max time Spring Boot waits for in-flight requests before forced shutdown |
| image | object | `{"digest":"sha256:f98b452d495cd7fd4c670922f93bfcf725b85e70fbe6ac1f65637ca9ca2ac318","pullPolicy":"IfNotPresent","repository":"labs64/reporting","tag":""}` | This sets the container image more information can be found here: https://kubernetes.io/docs/concepts/containers/images/ |
| image.digest | string | `"sha256:f98b452d495cd7fd4c670922f93bfcf725b85e70fbe6ac1f65637ca9ca2ac318"` | Pin the image by digest (`sha256:<64 hex>`). Takes precedence over `tag` — the release pipeline sets it so a deployment cannot follow a moved tag. |
| image.pullPolicy | string | `"IfNotPresent"` | This sets the pull policy for images. |
| image.tag | string | `""` | Overrides the image tag whose default is the chart appVersion. |
| imagePullSecrets | list | `[]` | This is for the secrets for pulling an image from a private repository more information can be found here: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/ |
| lifecycle.preStopDrainSeconds | int | `5` | preStop sleep (seconds) so Traefik/kube-proxy deregister the pod before shutdown; 0 disables |
| livenessProbe | object | `{"failureThreshold":3,"httpGet":{"path":"/actuator/health/liveness","port":8080},"initialDelaySeconds":0,"periodSeconds":10,"timeoutSeconds":2}` | This is to setup the liveness probes more information can be found here: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/ |
| nameOverride | string | `""` | This is to override the chart name. |
| networkPolicy | object | `{"egress":[],"enabled":false,"extraEgress":[],"extraIngress":[],"gatewayNamespace":"tools","ingressControllerLabels":{},"observabilityNamespace":"monitoring","toolsEgress":[]}` | NetworkPolicy: allow ingress from Traefik and same-namespace pods only (rendered by chart-libs.networkpolicy) |
| networkPolicy.egress | list | `[]` | ClickHouse and S3 are added per environment under extraEgress. |
| networkPolicy.extraEgress | list | `[]` | Additional raw egress rules |
| networkPolicy.extraIngress | list | `[]` | Additional raw ingress rules |
| networkPolicy.gatewayNamespace | string | `"tools"` | Namespace where Traefik runs |
| networkPolicy.ingressControllerLabels | object | `{}` | Ingress controller pod-selector labels; defaults to the internal Traefik standard (app.kubernetes.io/name: traefik) when empty @schema type: object additionalProperties: true @schema |
| networkPolicy.observabilityNamespace | string | `"monitoring"` | Namespace the observability/OTel collector runs in |
| networkPolicy.toolsEgress | list | `[]` | Tools-namespace destinations this service needs (name + port pairs); rendered as scoped egress rules — NOT a blanket allow to the whole tools namespace — to preserve isolation. |
| nodeSelector | object | `{}` |  |
| observability | object | `{"enabled":false,"metricsPath":"/actuator/prometheus","otlpEndpoint":"http://$(NODE_IP):4318"}` | Observability is infrastructure-owned: the same image runs with or without it. When enabled, the bundled OTel Java Agent is activated via JAVA_TOOL_OPTIONS and Prometheus scrape annotations (Micrometer /actuator/prometheus) are added. |
| observability.enabled | bool | `false` | Enable runtime instrumentation (traces + logs via OTLP; metrics via Prometheus scrape) |
| observability.metricsPath | string | `"/actuator/prometheus"` | Prometheus metrics path scraped from the pod |
| observability.otlpEndpoint | string | `"http://$(NODE_IP):4318"` | OTLP endpoint of the OpenTelemetry Collector |
| podAnnotations | object | `{}` | This is for setting Kubernetes Annotations to a Pod. For more information checkout: https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/ @schema type: object additionalProperties: true @schema |
| podDisruptionBudget | object | `{"enabled":false,"minAvailable":1}` | PodDisruptionBudget (rendered by chart-libs.pdb) |
| podLabels | object | `{}` | This is for setting Kubernetes Labels to a Pod. For more information checkout: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/ |
| podSecurityContext | object | `{}` |  |
| rbac.create | bool | `false` |  |
| rbac.rules | list | `[]` |  |
| readinessProbe | object | `{"failureThreshold":3,"httpGet":{"path":"/actuator/health/readiness","port":8080},"initialDelaySeconds":0,"periodSeconds":5,"timeoutSeconds":2}` | This is to setup the readiness probes more information can be found here: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/ |
| replicaCount | int | `1` | This will set the replicaset count more information can be found here: https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/ |
| resources.limits.cpu | string | `"500m"` |  |
| resources.limits.memory | string | `"768Mi"` |  |
| resources.requests.cpu | string | `"100m"` |  |
| resources.requests.memory | string | `"384Mi"` |  |
| secrets | object | `{"data":{}}` | Secret data to be used as environment variables (delivered via envFrom). The ClickHouse reader's password, as CLICKHOUSE_PASSWORD. |
| securityContext.allowPrivilegeEscalation | bool | `false` |  |
| securityContext.capabilities.drop[0] | string | `"ALL"` |  |
| securityContext.readOnlyRootFilesystem | bool | `true` |  |
| securityContext.runAsGroup | int | `1064` |  |
| securityContext.runAsNonRoot | bool | `true` |  |
| securityContext.runAsUser | int | `1064` |  |
| securityContext.seccompProfile.type | string | `"RuntimeDefault"` |  |
| service | object | `{"port":8080,"type":"ClusterIP"}` | This is for setting up a service more information can be found here: https://kubernetes.io/docs/concepts/services-networking/service/ |
| service.port | int | `8080` | This sets the ports more information can be found here: https://kubernetes.io/docs/concepts/services-networking/service/#field-spec-ports |
| service.type | string | `"ClusterIP"` | This sets the service type more information can be found here: https://kubernetes.io/docs/concepts/services-networking/service/#publishing-services-service-types |
| serviceAccount | object | `{"annotations":{},"automount":false,"create":true,"name":""}` | This section builds out the service account more information can be found here: https://kubernetes.io/docs/concepts/security/service-accounts/ |
| serviceAccount.annotations | object | `{}` | Annotations to add to the service account (e.g. `eks.amazonaws.com/role-arn` for IRSA) @schema type: object additionalProperties: true @schema |
| serviceAccount.automount | bool | `false` | Automatically mount a ServiceAccount's API credentials? This workload never calls the Kubernetes API — a mounted token is pure attack surface. |
| serviceAccount.create | bool | `true` | Specifies whether a service account should be created |
| serviceAccount.name | string | `""` | The name of the service account to use. If not set and create is true, a name is generated using the fullname template |
| slo | object | `{"availability":{"targetRatio":0.999},"enabled":true,"latency":{"targetRatio":0.99,"thresholdSeconds":0.5}}` | SLO recording rules and dashboards (rendered by chart-libs.slo.*) |
| startupProbe | object | `{"failureThreshold":60,"httpGet":{"path":"/actuator/health/liveness","port":8080},"periodSeconds":2,"timeoutSeconds":2}` | Startup probe (rendered by chart-libs.startupProbe): guards slow cold starts (Spring Boot + OTel Java Agent) so the liveness probe never kills a still-booting pod. Max boot budget = failureThreshold * periodSeconds. |
| terminationGracePeriodSeconds | int | `45` | Graceful shutdown: drain in-flight requests on rolling updates / scale-in. Keep terminationGracePeriodSeconds > lifecycle.preStopDrainSeconds + gracefulShutdown.timeout. |
| tests | object | `{"enabled":true,"healthPath":"/actuator/health"}` | helm test hook (rendered by chart-libs.test-connection) |
| tests.healthPath | string | `"/actuator/health"` | Health endpoint probed by `helm test` |
| tolerations | list | `[]` |  |
| topologySpreadConstraints | list | `[]` | Constrain how replicas spread across nodes/zones (e.g. maxSkew/topologyKey/whenUnsatisfiable). labelSelector defaults to this chart's own selector labels when a constraint omits one. |
| volumeMounts | list | `[]` | Additional volumeMounts on the output Deployment definition. |
| volumes | list | `[]` | Additional volumes on the output Deployment definition. No manual tmp entry needed here (unlike api-gateway): chart-libs auto-provisions a tmp emptyDir + mount for applicationType: java below, which readOnlyRootFilesystem (below) now relies on. |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)

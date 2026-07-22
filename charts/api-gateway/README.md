# api-gateway

![Version: 0.5.0](https://img.shields.io/badge/Version-0.5.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.0.1](https://img.shields.io/badge/AppVersion-0.0.1-informational?style=flat-square)

Labs64.IO :: API Gateway (AuthProxy + Middlewares)

**Homepage:** <https://labs64.io>

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| labs64 | <info@labs64.com> |  |

## Source Code

* <https://github.com/Labs64/labs64.io-helm-charts>
* <https://github.com/Labs64/labs64.io-authproxy/tree/master/traefik-authproxy>

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| file://../chart-libs | chart-libs | 0.1.0 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` |  |
| authProxy | object | `{"address":"","authResponseHeaders":["X-Auth-User","X-Auth-Scopes","X-Auth-Tenant","X-Request-ID"],"port":8081,"serviceName":"gateway-common","trustForwardHeader":true}` | ForwardAuth middleware configuration (OIDC/JWT validation via this chart's own authproxy container) |
| authProxy.address | string | `""` | Full URL override for the /auth endpoint; when empty the address is derived as http://<serviceName>.<release-namespace>.svc.cluster.local:<port>/auth |
| authProxy.authResponseHeaders | list | `["X-Auth-User","X-Auth-Scopes","X-Auth-Tenant","X-Request-ID"]` | Identity headers copied from the authproxy response onto the upstream request (the authproxy emits every one on each 2xx, so client values can never pass through) |
| authProxy.port | int | `8081` | Service port of the authproxy container |
| authProxy.serviceName | string | `"gateway-common"` | Service name backing the ForwardAuth address. Must match fullnameOverride above since the authproxy Service is rendered by this same chart. |
| authProxy.trustForwardHeader | bool | `true` | Trust X-Forwarded-* headers from the proxy |
| autoscaling | object | `{"enabled":false,"maxReplicas":3,"minReplicas":1,"targetCPUUtilizationPercentage":80}` | This section is for setting up autoscaling more information can be found here: https://kubernetes.io/docs/concepts/workloads/autoscaling/ |
| buffering | object | `{"enabled":true,"maxRequestBodyBytes":2621440}` | Buffering middleware configuration (limits payload sizes to prevent OOM / large event attacks) |
| buffering.enabled | bool | `true` | Enable the shared buffering middleware |
| buffering.maxRequestBodyBytes | int | `2621440` | Maximum allowed request body size in bytes (default 2.5MB) |
| chart-libs | object | `{}` | Values passed to the chart-libs library dependency (present so the generated schema accepts the key Helm injects for the dependency) @schema type: object additionalProperties: true @schema |
| compress | object | `{"enabled":true,"excludedContentTypes":["image/png","image/jpeg","image/gif","image/webp","application/grpc"],"minResponseBodyBytes":1024}` | Response-compression middleware (edge optimization for all modules routed through Traefik) |
| compress.enabled | bool | `true` | Enable the shared compress middleware |
| compress.excludedContentTypes | list | `["image/png","image/jpeg","image/gif","image/webp","application/grpc"]` | Content types excluded from compression (already-compressed formats) |
| compress.minResponseBodyBytes | int | `1024` | Do not compress responses below this size (bytes) |
| env[0] | object | `{"name":"OIDC_DISCOVERY_URL","value":"http://keycloak.tools.svc.cluster.local/realms/labs64io/.well-known/openid-configuration"}` | OIDC discovery URL. Override per environment:   production: http://keycloak.tools.svc.cluster.local/realms/labs64io/.well-known/openid-configuration   local dev:  http://mock-oidc.tools.svc.cluster.local:8080/labs64io/.well-known/openid-configuration |
| env[1] | object | `{"name":"OIDC_AUDIENCE","value":"account"}` | Audience for the auth proxy. |
| env[2] | object | `{"name":"LOG_LEVEL","value":"INFO"}` | Log level for the auth proxy. |
| env[3] | object | `{"name":"TOKEN_SCOPES_CLAIM_PATHS","value":"scope,realm_access.roles,resource_access.{audience}.roles"}` | Dot-paths (comma-separated) to collect scopes from the JWT; "{audience}" expands to OIDC_AUDIENCE. Default: scope,realm_access.roles,resource_access.{audience}.roles. |
| env[4] | object | `{"name":"TOKEN_TENANT_CLAIM_PATH","value":"tenant"}` | Dot-path to the tenant claim for X-Auth-Tenant; "-" is emitted when absent. |
| env[5] | object | `{"name":"CERBOS_URL","value":"http://labs64io-authz-pdp:3592"}` | Central Cerbos PDP HTTP endpoint (the authorization decision). |
| env[6] | object | `{"name":"ROUTES_DIR","value":"/app/routes"}` | Directory of generated <module>.routes.yaml manifests (mounted ConfigMap). |
| env[7] | object | `{"name":"STATIC_ROUTES_FILE","value":"/opt/application-config/static_routes.yaml"}` | Static prefix policies file (rendered from .Values.staticPolicies). |
| externalSecrets.enabled | bool | `false` |  |
| externalSecrets.storeName | string | `"local-kubernetes-store"` |  |
| fullnameOverride | string | `"gateway-common"` | Fixed resource-name prefix (instead of the default "<release>-api-gateway") so module charts can reference the shared middlewares by a stable name regardless of release name. Also fixes the name of this chart's own Deployment/Service, which is why authProxy.serviceName below must match this value. |
| image | object | `{"pullPolicy":"IfNotPresent","repository":"labs64/traefik-authproxy","tag":""}` | This sets the container image more information can be found here: https://kubernetes.io/docs/concepts/containers/images/ |
| image.pullPolicy | string | `"IfNotPresent"` | This sets the pull policy for images. |
| image.tag | string | `""` | Overrides the image tag whose default is the chart appVersion. |
| imagePullSecrets | list | `[]` | This is for the secrets for pulling an image from a private repository more information can be found here: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/ |
| lifecycle.preStopDrainSeconds | int | `5` | preStop sleep (seconds) so Traefik/kube-proxy deregister the pod before shutdown; 0 disables |
| livenessProbe | object | `{"failureThreshold":3,"httpGet":{"path":"/health","port":8081},"initialDelaySeconds":30,"periodSeconds":10,"timeoutSeconds":2}` | This is to setup the liveness probes more information can be found here: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/ |
| nameOverride | string | `""` | This is to override the chart name. |
| networkPolicy | object | `{"egress":[{"ports":[{"port":3592,"protocol":"TCP"}],"to":[{"podSelector":{"matchLabels":{"app.kubernetes.io/name":"authz-pdp"}}}]}],"enabled":false,"extraIngress":[],"gatewayNamespace":"tools","toolsEgress":[{"name":"mock-oidc","port":8080}]}` | NetworkPolicy: allow ingress from Traefik and same-namespace pods only (rendered by chart-libs.networkpolicy) |
| networkPolicy.egress | list | `[{"ports":[{"port":3592,"protocol":"TCP"}],"to":[{"podSelector":{"matchLabels":{"app.kubernetes.io/name":"authz-pdp"}}}]}]` | Egress rules enforcing database-per-service isolation. |
| networkPolicy.extraIngress | list | `[]` | Additional raw ingress rules |
| networkPolicy.gatewayNamespace | string | `"tools"` | Namespace where Traefik runs |
| networkPolicy.toolsEgress | list | `[{"name":"mock-oidc","port":8080}]` | Tools-namespace destinations this service needs (name + port pairs); rendered as scoped egress rules — NOT a blanket allow to the whole tools namespace — to preserve database-per-service isolation. |
| nodeSelector | object | `{}` |  |
| observability | object | `{"enabled":false,"otlpEndpoint":"http://$(NODE_IP):4318"}` | Observability is infrastructure-owned: the same image runs with or without it. When enabled, the image's opentelemetry-instrument entrypoint auto-instruments FastAPI (traces + correlated logs + metrics via OTLP). |
| observability.enabled | bool | `false` | Enable runtime auto-instrumentation (traces + logs + metrics via OTLP) |
| observability.otlpEndpoint | string | `"http://$(NODE_IP):4318"` | OTLP endpoint of the OpenTelemetry Collector |
| podAnnotations | object | `{}` | This is for setting Kubernetes Annotations to a Pod. For more information checkout: https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/ |
| podDisruptionBudget | object | `{"enabled":true,"minAvailable":1}` | PodDisruptionBudget (rendered by chart-libs.pdb) |
| podLabels | object | `{}` | This is for setting Kubernetes Labels to a Pod. For more information checkout: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/ |
| podSecurityContext | object | `{}` |  |
| rateLimit | object | `{"average":100,"burst":50,"perUser":true}` | Rate limit middleware configuration |
| rateLimit.average | int | `100` | Average requests per second |
| rateLimit.burst | int | `50` | Burst size |
| rateLimit.perUser | bool | `true` | Rate-limit per authenticated user (X-Auth-User header set by the auth middleware); falls back to per-IP when absent |
| readinessProbe | object | `{"failureThreshold":3,"httpGet":{"path":"/health/ready","port":8081},"initialDelaySeconds":10,"periodSeconds":5,"timeoutSeconds":2}` | This is to setup the readiness probes more information can be found here: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/ |
| replicaCount | int | `2` | This will set the replicaset count more information can be found here: https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/ The authproxy sits on the hot path of every protected request - keep at least 2 replicas. |
| resources.limits.cpu | string | `"200m"` |  |
| resources.limits.memory | string | `"512Mi"` |  |
| resources.requests.cpu | string | `"100m"` |  |
| resources.requests.memory | string | `"512Mi"` |  |
| secrets | object | `{"data":{}}` | Secret data to be used as environment variables (delivered via envFrom) |
| securityContext.capabilities.drop[0] | string | `"ALL"` |  |
| securityContext.runAsGroup | int | `1064` |  |
| securityContext.runAsNonRoot | bool | `true` |  |
| securityContext.runAsUser | int | `1064` |  |
| securityContext.seccompProfile.type | string | `"RuntimeDefault"` |  |
| service | object | `{"port":8081,"type":"ClusterIP"}` | This is for setting up a service more information can be found here: https://kubernetes.io/docs/concepts/services-networking/service/ |
| service.port | int | `8081` | This sets the ports more information can be found here: https://kubernetes.io/docs/concepts/services-networking/service/#field-spec-ports |
| service.type | string | `"ClusterIP"` | This sets the service type more information can be found here: https://kubernetes.io/docs/concepts/services-networking/service/#publishing-services-service-types |
| serviceAccount | object | `{"annotations":{},"automount":true,"create":true,"name":""}` | This section builds out the service account more information can be found here: https://kubernetes.io/docs/concepts/security/service-accounts/ |
| serviceAccount.annotations | object | `{}` | Annotations to add to the service account |
| serviceAccount.automount | bool | `true` | Automatically mount a ServiceAccount's API credentials? |
| serviceAccount.create | bool | `true` | Specifies whether a service account should be created |
| serviceAccount.name | string | `""` | The name of the service account to use. If not set and create is true, a name is generated using the fullname template |
| startupProbe | object | `{"failureThreshold":20,"httpGet":{"path":"/health/ready","port":8081},"periodSeconds":3,"timeoutSeconds":2}` | Startup probe (rendered by chart-libs.startupProbe): guards cold start so the liveness probe never kills a still-booting pod. Max boot budget = failureThreshold * periodSeconds. |
| staticPolicies | list | `[{"id":"checkout-ui","prefix":"/checkout-ui","public":false,"scopes":["admin-role","ecommerce-role"]},{"id":"customer-portal-ui","prefix":"/customer-portal-ui","public":false,"scopes":["admin-role","default-roles-labs64io"]}]` | Static prefix policies for gateway surfaces without an OpenAPI spec (UI bundles). Rendered into static_routes.yaml; `id` MUST match an action in the Cerbos static_api policy (charts/authz-pdp/policies/static_api.yaml) — that policy makes the decision, this only carries the routing prefix. Longest prefix wins; consulted only when no module route matches. TODO: remove after the corresponding modules will be using OpenAPI |
| terminationGracePeriodSeconds | int | `45` | Graceful shutdown: drain on rolling updates / scale-in (uvicorn handles SIGTERM; preStop gives Traefik/kube-proxy time to deregister the pod first). |
| tolerations | list | `[]` |  |
| volumeMounts | list | `[]` | Additional volumeMounts on the output Deployment definition. |
| volumes | list | `[]` | Additional volumes on the output Deployment definition. |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)

# traefik-authproxy

![Version: 0.0.3](https://img.shields.io/badge/Version-0.0.3-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.0.1](https://img.shields.io/badge/AppVersion-0.0.1-informational?style=flat-square)

Labs64.IO :: Traefik Auth (M2M) Middleware

**Homepage:** <https://labs64.io>

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| labs64 | <info@labs64.com> |  |

## Source Code

* <https://github.com/Labs64/labs64.io-helm-charts>
* <https://github.com/Labs64/labs64.io-gateway/tree/master/traefik-authproxy>

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| file://../chart-libs | chart-libs | 0.0.4 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` |  |
| autoscaling | object | `{"enabled":false,"maxReplicas":3,"minReplicas":1,"targetCPUUtilizationPercentage":80}` | This section is for setting up autoscaling more information can be found here: https://kubernetes.io/docs/concepts/workloads/autoscaling/ |
| chart-libs | object | `{}` | Values passed to the chart-libs library dependency (present so the generated schema accepts the key Helm injects for the dependency) @schema type: object additionalProperties: true @schema |
| env[0] | object | `{"name":"OIDC_DISCOVERY_URL","value":"http://keycloak.tools.svc.cluster.local/realms/labs64io/.well-known/openid-configuration"}` | OIDC discovery URL. Override per environment:   production: http://keycloak.tools.svc.cluster.local/realms/labs64io/.well-known/openid-configuration   local dev:  http://mock-oidc.tools.svc.cluster.local:8080/labs64io/.well-known/openid-configuration |
| env[1] | object | `{"name":"OIDC_AUDIENCE","value":"account"}` | Audience for the auth proxy. |
| env[2] | object | `{"name":"ROLE_MAPPING_FILE","value":"/opt/application-config/role_mapping.yaml"}` | Path to the role mapping file for the auth proxy. |
| env[3] | object | `{"name":"LOG_LEVEL","value":"INFO"}` | Log level for the auth proxy. |
| env[4] | object | `{"name":"ROLE_MAPPING_DIR","value":"/opt/role-mappings"}` | Directory with per-module role-mapping fragments (populated by the k8s-sidecar) |
| env[5] | object | `{"name":"TOKEN_ROLES_CLAIM_PATHS","value":"realm_access.roles,resource_access.{audience}.roles"}` | Dot-paths (comma-separated) to collect roles from the JWT; "{audience}" expands to OIDC_AUDIENCE. Default: realm_access.roles,resource_access.{audience}.roles. |
| env[6] | object | `{"name":"TOKEN_TENANT_CLAIM_PATH","value":"tenant"}` | Dot-path to the tenant claim for X-Auth-Tenant (RFC-03); "-" is emitted when absent. |
| fullnameOverride | string | `""` |  |
| image | object | `{"pullPolicy":"IfNotPresent","repository":"labs64/traefik-authproxy","tag":""}` | This sets the container image more information can be found here: https://kubernetes.io/docs/concepts/containers/images/ |
| image.pullPolicy | string | `"IfNotPresent"` | This sets the pull policy for images. |
| image.tag | string | `""` | Overrides the image tag whose default is the chart appVersion. |
| imagePullSecrets | list | `[]` | This is for the secrets for pulling an image from a private repository more information can be found here: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/ |
| ingress | object | `{"annotations":{},"className":"nginx","enabled":false,"hosts":[{"host":"localhost","paths":[{"path":"/","pathType":"Prefix"}]}],"tls":[]}` | This block is for setting up the ingress for more information can be found here: https://kubernetes.io/docs/concepts/services-networking/ingress/ |
| ingressroute | object | `{"enabled":false,"entryPoints":["web","websecure"],"host":"localhost"}` | IngressRoute configuration for Traefik more information can be found here: https://doc.traefik.io/traefik/routing/providers/kubernetes-crd/ |
| ingressroute.enabled | bool | `false` | This sets whether the IngressRoute is enabled or not |
| ingressroute.entryPoints | list | `["web","websecure"]` | Entry points for the IngressRoute |
| ingressroute.host | string | `"localhost"` | Host for the IngressRoute |
| lifecycle.preStopDrainSeconds | int | `5` | preStop sleep (seconds) so Traefik/kube-proxy deregister the pod before shutdown; 0 disables |
| livenessProbe | object | `{"failureThreshold":3,"httpGet":{"path":"/docs","port":8081},"initialDelaySeconds":30,"periodSeconds":10,"timeoutSeconds":2}` | This is to setup the liveness probes more information can be found here: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/ |
| nameOverride | string | `""` | This is to override the chart name. |
| networkPolicy | object | `{"enabled":false,"extraIngress":[],"gatewayNamespace":"tools"}` | NetworkPolicy: allow ingress from Traefik and same-namespace pods only (rendered by chart-libs.networkpolicy) |
| networkPolicy.extraIngress | list | `[]` | Additional raw ingress rules |
| networkPolicy.gatewayNamespace | string | `"tools"` | Namespace where Traefik runs |
| nodeSelector | object | `{}` |  |
| observability | object | `{"enabled":false,"otlpEndpoint":"http://otel-collector:4318"}` | Observability is infrastructure-owned: the same image runs with or without it. When enabled, the image's opentelemetry-instrument entrypoint auto-instruments FastAPI (traces + correlated logs + metrics via OTLP). |
| observability.enabled | bool | `false` | Enable runtime auto-instrumentation (traces + logs + metrics via OTLP) |
| observability.otlpEndpoint | string | `"http://otel-collector:4318"` | OTLP endpoint of the OpenTelemetry Collector |
| podAnnotations | object | `{}` | This is for setting Kubernetes Annotations to a Pod. For more information checkout: https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/ |
| podDisruptionBudget | object | `{"enabled":true,"minAvailable":1}` | PodDisruptionBudget (rendered by chart-libs.pdb) |
| podLabels | object | `{}` | This is for setting Kubernetes Labels to a Pod. For more information checkout: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/ |
| podSecurityContext | object | `{}` |  |
| rbac.create | bool | `true` |  |
| rbac.rules[0].apiGroups[0] | string | `""` |  |
| rbac.rules[0].resources[0] | string | `"configmaps"` |  |
| rbac.rules[0].verbs[0] | string | `"get"` |  |
| rbac.rules[0].verbs[1] | string | `"list"` |  |
| rbac.rules[0].verbs[2] | string | `"watch"` |  |
| readinessProbe | object | `{"failureThreshold":3,"httpGet":{"path":"/docs","port":8081},"initialDelaySeconds":10,"periodSeconds":5,"timeoutSeconds":2}` | This is to setup the readiness probes more information can be found here: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/ |
| replicaCount | int | `2` | This will set the replicaset count more information can be found here: https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/ The authproxy sits on the hot path of every protected request - keep at least 2 replicas. |
| resources.limits.cpu | string | `"200m"` |  |
| resources.limits.memory | string | `"512Mi"` |  |
| resources.requests.cpu | string | `"100m"` |  |
| resources.requests.memory | string | `"512Mi"` |  |
| roleMapping | object | `{}` | Static base role mappings (rarely needed). Real path→role mappings are owned by the module charts: each publishes a role-mapping ConfigMap fragment (label labs64.io/role-mapping=true, rendered by chart-libs.gateway-routes) that the sidecar merges on top of this base. Forwarded URIs are always module-prefixed (e.g. /checkout/api/v1), so entries here must be too — unprefixed paths like /v3/api-docs never match and are dead configuration. Paths with no roles, an empty list, or ["public"] are treated as public. @schema type: object additionalProperties: true @schema |
| roleMappingSidecar | object | `{"enabled":true,"folder":"/opt/role-mappings","image":{"pullPolicy":"IfNotPresent","repository":"kiwigrid/k8s-sidecar","tag":"1.30.0"},"label":"labs64.io/role-mapping","labelValue":"true","resources":{"limits":{"cpu":"50m","memory":"128Mi"},"requests":{"cpu":"10m","memory":"32Mi"}}}` | Sidecar that collects per-module role-mapping ConfigMap fragments (label labs64.io/role-mapping=true) |
| roleMappingSidecar.folder | string | `"/opt/role-mappings"` | Directory (shared emptyDir) the fragments are written to |
| roleMappingSidecar.label | string | `"labs64.io/role-mapping"` | ConfigMap label to watch |
| securityContext | object | `{}` |  |
| service | object | `{"port":8081,"type":"ClusterIP"}` | This is for setting up a service more information can be found here: https://kubernetes.io/docs/concepts/services-networking/service/ |
| service.port | int | `8081` | This sets the ports more information can be found here: https://kubernetes.io/docs/concepts/services-networking/service/#field-spec-ports |
| service.type | string | `"ClusterIP"` | This sets the service type more information can be found here: https://kubernetes.io/docs/concepts/services-networking/service/#publishing-services-service-types |
| serviceAccount | object | `{"annotations":{},"automount":true,"create":true,"name":""}` | This section builds out the service account more information can be found here: https://kubernetes.io/docs/concepts/security/service-accounts/ |
| serviceAccount.annotations | object | `{}` | Annotations to add to the service account |
| serviceAccount.automount | bool | `true` | Automatically mount a ServiceAccount's API credentials? |
| serviceAccount.create | bool | `true` | Specifies whether a service account should be created |
| serviceAccount.name | string | `""` | The name of the service account to use. If not set and create is true, a name is generated using the fullname template |
| startupProbe | object | `{"failureThreshold":20,"httpGet":{"path":"/docs","port":8081},"periodSeconds":3,"timeoutSeconds":2}` | Startup probe (rendered by chart-libs.startupProbe): guards cold start so the liveness probe never kills a still-booting pod. Max boot budget = failureThreshold * periodSeconds. |
| terminationGracePeriodSeconds | int | `45` | Graceful shutdown: drain on rolling updates / scale-in (uvicorn handles SIGTERM; preStop gives Traefik/kube-proxy time to deregister the pod first). |
| tolerations | list | `[]` |  |
| volumeMounts | list | `[]` | Additional volumeMounts on the output Deployment definition. |
| volumes | list | `[]` | Additional volumes on the output Deployment definition. |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)

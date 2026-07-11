# checkout-ui

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.0.1](https://img.shields.io/badge/AppVersion-0.0.1-informational?style=flat-square)

Labs64.IO :: Checkout UI – Frontend Interface for the Labs64 Checkout Platform, built with Vite and Vue 3. Provides a responsive and customizable user experience for digital commerce workflows.

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

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` |  |
| application.runtimeEnv.enabled | bool | `true` | Enable loading a runtime config file (env.json). |
| application.runtimeEnv.env | object | `{"VITE_API_URL":"https://<HOST>/checkout/api/v1"}` | Key-value pairs written into env.json. Keys should match variables your UI reads (for Vite, use the VITE_* prefix). |
| application.runtimeEnv.env.VITE_API_URL | string | `"https://<HOST>/checkout/api/v1"` | Primary API base URL — replace <HOST> with your domain/host. |
| application.runtimeEnv.path | string | `"/usr/share/nginx/html/config/env.json"` | Absolute path in the container where env.json is mounted and served from (must match Nginx/Ingress config). |
| application.runtimeEnv.strict | bool | `true` | Strict mode: if true, the container must not start when env.json is missing/invalid (e.g., ConfigMap not mounted). |
| autoscaling | object | `{"enabled":false,"maxReplicas":3,"minReplicas":1,"targetCPUUtilizationPercentage":80}` | This section is for setting up autoscaling more information can be found here: https://kubernetes.io/docs/concepts/workloads/autoscaling/ |
| chart-libs | object | `{}` | Values passed to the chart-libs library dependency (present so the generated schema accepts the key Helm injects for the dependency) @schema type: object additionalProperties: true @schema |
| env | list | `[]` |  |
| fullnameOverride | string | `""` |  |
| gateway | object | `{"enabled":false,"entryPoints":["web","websecure"],"prefix":"/checkout","routes":[{"path":"","port":8080}],"sharedMiddlewares":{"auth":"gateway-common-auth","compress":"gateway-common-compress","rateLimit":"gateway-common-ratelimit","securityHeaders":"gateway-common-security-headers","stripAuthHeaders":"gateway-common-strip-auth-headers"}}` | Gateway routes published by this module (rendered by chart-libs.gateway-routes) |
| gateway.enabled | bool | `false` | Publish this module's routes on the Traefik gateway |
| gateway.entryPoints | list | `["web","websecure"]` | Traefik entry points |
| gateway.prefix | string | `"/checkout"` | External path prefix; checkout-ui serves under /checkout |
| gateway.routes | list | `[{"path":"","port":8080}]` | Routes exposed by this module |
| gateway.routes[0] | object | `{"path":"","port":8080}` | Checkout UI (protected) |
| gateway.sharedMiddlewares | object | `{"auth":"gateway-common-auth","compress":"gateway-common-compress","rateLimit":"gateway-common-ratelimit","securityHeaders":"gateway-common-security-headers","stripAuthHeaders":"gateway-common-strip-auth-headers"}` | Names of the shared middlewares provided by the gateway-common chart |
| image | object | `{"pullPolicy":"IfNotPresent","repository":"labs64/checkout-ui","tag":""}` | This sets the container image more information can be found here: https://kubernetes.io/docs/concepts/containers/images/ |
| image.pullPolicy | string | `"IfNotPresent"` | This sets the pull policy for images. |
| image.tag | string | `""` | Overrides the image tag whose default is the chart appVersion. |
| imagePullSecrets | list | `[]` | This is for the secrets for pulling an image from a private repository more information can be found here: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/ |
| ingress | object | `{"annotations":{},"className":"nginx","enabled":false,"hosts":[{"host":"localhost","paths":[{"path":"/","pathType":"Prefix"}]}],"tls":[]}` | This block is for setting up the ingress for more information can be found here: https://kubernetes.io/docs/concepts/services-networking/ingress/ |
| lifecycle.preStopDrainSeconds | int | `5` | preStop sleep (seconds) so the gateway deregisters the pod before shutdown; 0 disables |
| livenessProbe | object | `{"failureThreshold":3,"httpGet":{"path":"/","port":8080},"initialDelaySeconds":10,"periodSeconds":10,"timeoutSeconds":2}` | This is to setup the liveness and readiness probes more information can be found here: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/ |
| nameOverride | string | `""` | This is to override the chart name. |
| networkPolicy | object | `{"enabled":false,"extraIngress":[],"gatewayNamespace":"tools"}` | NetworkPolicy: allow ingress from Traefik and same-namespace pods only (rendered by chart-libs.networkpolicy) |
| networkPolicy.extraIngress | list | `[]` | Additional raw ingress rules |
| networkPolicy.gatewayNamespace | string | `"tools"` | Namespace where Traefik runs |
| nodeSelector | object | `{}` |  |
| podAnnotations | object | `{}` | This is for setting Kubernetes Annotations to a Pod. For more information checkout: https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/ |
| podDisruptionBudget | object | `{"enabled":false,"minAvailable":1}` | PodDisruptionBudget (rendered by chart-libs.pdb) |
| podLabels | object | `{}` | This is for setting Kubernetes Labels to a Pod. For more information checkout: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/ |
| podSecurityContext | object | `{"fsGroup":101,"runAsGroup":101,"runAsNonRoot":true,"runAsUser":101,"seccompProfile":{"type":"RuntimeDefault"}}` | Non-root pod security context. The image is nginx-unprivileged (UID 101), so the whole pod runs unprivileged and listens on 8080. |
| rbac.create | bool | `false` |  |
| rbac.rules | list | `[]` |  |
| readinessProbe | object | `{"failureThreshold":3,"httpGet":{"path":"/","port":8080},"initialDelaySeconds":5,"periodSeconds":5,"timeoutSeconds":2}` | This is to setup the readiness probes more information can be found here: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/ |
| replicaCount | int | `1` | This will set the replicaset count more information can be found here: https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/ |
| resources.limits.cpu | string | `"200m"` |  |
| resources.limits.memory | string | `"256Mi"` |  |
| resources.requests.cpu | string | `"50m"` |  |
| resources.requests.memory | string | `"128Mi"` |  |
| secrets | object | `{"data":{}}` | Secret data to be used as environment variables |
| securityContext.allowPrivilegeEscalation | bool | `false` |  |
| securityContext.capabilities.drop[0] | string | `"ALL"` |  |
| securityContext.readOnlyRootFilesystem | bool | `false` |  |
| service | object | `{"port":8080,"type":"ClusterIP"}` | This is for setting up a service more information can be found here: https://kubernetes.io/docs/concepts/services-networking/service/ |
| service.port | int | `8080` | This sets the ports more information can be found here: https://kubernetes.io/docs/concepts/services-networking/service/#field-spec-ports Non-privileged port served by nginx-unprivileged. |
| service.type | string | `"ClusterIP"` | This sets the service type more information can be found here: https://kubernetes.io/docs/concepts/services-networking/service/#publishing-services-service-types |
| serviceAccount | object | `{"annotations":{},"automount":true,"create":false,"name":""}` | This section builds out the service account more information can be found here: https://kubernetes.io/docs/concepts/security/service-accounts/ |
| serviceAccount.annotations | object | `{}` | Annotations to add to the service account |
| serviceAccount.automount | bool | `true` | Automatically mount a ServiceAccount's API credentials? |
| serviceAccount.create | bool | `false` | Specifies whether a service account should be created |
| serviceAccount.name | string | `""` | The name of the service account to use. If not set and create is true, a name is generated using the fullname template |
| startupProbe | object | `{"failureThreshold":10,"httpGet":{"path":"/","port":8080},"periodSeconds":3,"timeoutSeconds":2}` | Startup probe (rendered by chart-libs.startupProbe): nginx starts fast, but this keeps rollout semantics uniform across the ecosystem. |
| terminationGracePeriodSeconds | int | `30` | Graceful shutdown: let Traefik/kube-proxy deregister the pod before nginx stops. |
| tests | object | `{"enabled":true,"healthPath":"/"}` | helm test hook (rendered by chart-libs.test-connection) |
| tests.healthPath | string | `"/"` | Health endpoint probed by `helm test` |
| tolerations | list | `[]` |  |
| volumeMounts | list | `[]` | Additional volumeMounts on the output Deployment definition. |
| volumes | list | `[]` | Additional volumes on the output Deployment definition. |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)

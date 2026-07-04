# customer-portal-ui

![Version: 0.0.1](https://img.shields.io/badge/Version-0.0.1-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.0.1](https://img.shields.io/badge/AppVersion-0.0.1-informational?style=flat-square)

Labs64.IO :: Customer Portal UI – Frontend Interface for the Labs64 Customer Portal, built with Vite and Vue 3.

**Homepage:** <https://labs64.io>

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| labs64 | <info@labs64.com> |  |

## Source Code

* <https://github.com/Labs64/labs64.io-helm-charts>
* <https://github.com/Labs64/labs64.io-customer-portal>

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| file://../chart-libs | chart-libs | 0.0.2 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` |  |
| application.runtimeEnv.enabled | bool | `true` | Enable loading a runtime config file (env.json). |
| application.runtimeEnv.env | object | `{"VITE_API_URL":"https://<HOST>/api/v1/customer-portal"}` | Key-value pairs written into env.json. |
| application.runtimeEnv.env.VITE_API_URL | string | `"https://<HOST>/api/v1/customer-portal"` | Primary API base URL — replace <HOST> with your domain/host. |
| application.runtimeEnv.path | string | `"/usr/share/nginx/html/config/env.json"` | Absolute path in the container where env.json is mounted and served from. |
| application.runtimeEnv.strict | bool | `true` | Strict mode: if true, the container must not start when env.json is missing/invalid. |
| autoscaling | object | `{"enabled":false,"maxReplicas":3,"minReplicas":1,"targetCPUUtilizationPercentage":80}` | This section is for setting up autoscaling |
| chart-libs | object | `{}` | Values passed to the chart-libs library dependency (present so the generated schema accepts the key Helm injects for the dependency) @schema type: object additionalProperties: true @schema |
| env | list | `[]` |  |
| fullnameOverride | string | `""` |  |
| gateway | object | `{"enabled":false,"entryPoints":["web","websecure"],"prefix":"/customer-portal","routes":[{"path":"","port":80,"roles":["admin-role","default-roles-labs64io"]}],"sharedMiddlewares":{"auth":"gateway-common-auth","rateLimit":"gateway-common-ratelimit","securityHeaders":"gateway-common-security-headers"}}` | Gateway routes published by this module (rendered by chart-libs.gateway-routes) |
| gateway.enabled | bool | `false` | Publish this module's routes on the Traefik gateway |
| gateway.entryPoints | list | `["web","websecure"]` | Traefik entry points |
| gateway.prefix | string | `"/customer-portal"` | External path prefix; customer-portal-ui serves under /customer-portal |
| gateway.routes | list | `[{"path":"","port":80,"roles":["admin-role","default-roles-labs64io"]}]` | Routes exposed by this module |
| gateway.routes[0] | object | `{"path":"","port":80,"roles":["admin-role","default-roles-labs64io"]}` | Customer Portal UI (protected) |
| gateway.sharedMiddlewares | object | `{"auth":"gateway-common-auth","rateLimit":"gateway-common-ratelimit","securityHeaders":"gateway-common-security-headers"}` | Names of the shared middlewares provided by the gateway-common chart |
| image | object | `{"pullPolicy":"IfNotPresent","repository":"labs64/customer-portal-ui","tag":""}` | This sets the container image more information can be found here: https://kubernetes.io/docs/concepts/containers/images/ |
| image.pullPolicy | string | `"IfNotPresent"` | This sets the pull policy for images. |
| image.tag | string | `""` | Overrides the image tag whose default is the chart appVersion. |
| imagePullSecrets | list | `[]` | This is for the secrets for pulling an image from a private repository more information can be found here: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/ |
| ingress | object | `{"annotations":{},"className":"nginx","enabled":false,"hosts":[{"host":"localhost","paths":[{"path":"/","pathType":"Prefix"}]}],"tls":[]}` | This block is for setting up the ingress for more information can be found here: https://kubernetes.io/docs/concepts/services-networking/ingress/ |
| ingressroute | object | `{"enabled":false,"entryPoints":["web","websecure"],"host":"localhost"}` | IngressRoute configuration for Traefik more information can be found here: https://doc.traefik.io/traefik/routing/providers/kubernetes-crd/ |
| ingressroute.enabled | bool | `false` | This sets whether the IngressRoute is enabled or not |
| ingressroute.entryPoints | list | `["web","websecure"]` | Entry points for the IngressRoute |
| ingressroute.host | string | `"localhost"` | Host for the IngressRoute |
| livenessProbe | object | `{"failureThreshold":3,"httpGet":{"path":"/","port":80},"initialDelaySeconds":10,"periodSeconds":10,"timeoutSeconds":2}` | This is to setup the liveness probes |
| nameOverride | string | `""` | This is to override the chart name. |
| networkPolicy | object | `{"enabled":false,"extraIngress":[],"gatewayNamespace":"tools"}` | NetworkPolicy: allow ingress from Traefik and same-namespace pods only (rendered by chart-libs.networkpolicy) |
| networkPolicy.extraIngress | list | `[]` | Additional raw ingress rules |
| networkPolicy.gatewayNamespace | string | `"tools"` | Namespace where Traefik runs |
| nodeSelector | object | `{}` |  |
| podAnnotations | object | `{}` | This is for setting Kubernetes Annotations to a Pod. |
| podDisruptionBudget | object | `{"enabled":false,"minAvailable":1}` | PodDisruptionBudget (rendered by chart-libs.pdb) |
| podLabels | object | `{}` | This is for setting Kubernetes Labels to a Pod. |
| podSecurityContext | object | `{}` |  |
| rbac.create | bool | `false` |  |
| rbac.rules | list | `[]` |  |
| readinessProbe | object | `{"failureThreshold":3,"httpGet":{"path":"/","port":80},"initialDelaySeconds":5,"periodSeconds":5,"timeoutSeconds":2}` | This is to setup the readiness probes |
| replicaCount | int | `1` | This will set the replicaset count more information can be found here: https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/ |
| resources.limits.cpu | string | `"200m"` |  |
| resources.limits.memory | string | `"256Mi"` |  |
| resources.requests.cpu | string | `"50m"` |  |
| resources.requests.memory | string | `"128Mi"` |  |
| secrets | object | `{"data":{}}` | Secret data to be used as environment variables |
| securityContext | object | `{}` |  |
| service | object | `{"port":80,"type":"ClusterIP"}` | This is for setting up a service more information can be found here: https://kubernetes.io/docs/concepts/services-networking/service/ |
| service.port | int | `80` | This sets the ports |
| service.type | string | `"ClusterIP"` | This sets the service type |
| serviceAccount | object | `{"annotations":{},"automount":true,"create":false,"name":""}` | This section builds out the service account more information can be found here: https://kubernetes.io/docs/concepts/security/service-accounts/ |
| serviceAccount.annotations | object | `{}` | Annotations to add to the service account |
| serviceAccount.automount | bool | `true` | Automatically mount a ServiceAccount's API credentials? |
| serviceAccount.create | bool | `false` | Specifies whether a service account should be created |
| serviceAccount.name | string | `""` | The name of the service account to use. If not set and create is true, a name is generated using the fullname template |
| tests | object | `{"enabled":true,"healthPath":"/"}` | helm test hook (rendered by chart-libs.test-connection) |
| tests.healthPath | string | `"/"` | Health endpoint probed by `helm test` |
| tolerations | list | `[]` |  |
| volumeMounts | list | `[]` | Additional volumeMounts on the output Deployment definition. |
| volumes | list | `[]` | Additional volumes on the output Deployment definition. |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)

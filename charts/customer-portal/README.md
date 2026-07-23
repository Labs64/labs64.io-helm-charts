# customer-portal

![Version: 0.4.0](https://img.shields.io/badge/Version-0.4.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.0.1](https://img.shields.io/badge/AppVersion-0.0.1-informational?style=flat-square)

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
| file://../chart-libs | chart-libs | 0.2.0 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| chart-libs | object | `{}` |  |
| enabled | bool | `true` |  |
| ui.application.runtimeEnv.enabled | bool | `true` | Enable loading a runtime config file (env.json). |
| ui.application.runtimeEnv.env | object | `{"VITE_API_URL":"https://<HOST>/customer-portal/api/v1"}` | Key-value pairs written into env.json. |
| ui.application.runtimeEnv.env.VITE_API_URL | string | `"https://<HOST>/customer-portal/api/v1"` | Primary API base URL — replace <HOST> with your domain/host. |
| ui.application.runtimeEnv.path | string | `"/usr/share/nginx/html/config/env.json"` | Absolute path in the container where env.json is mounted and served from. |
| ui.application.runtimeEnv.strict | bool | `true` | Strict mode: if true, the container must not start when env.json is missing/invalid. |
| ui.enabled | bool | `true` |  |
| ui.fullnameOverride | string | `""` |  |
| ui.gateway.annotations | object | `{}` | Annotations for fallback Ingress |
| ui.gateway.enabled | bool | `false` | Publish this module's routes on the Traefik gateway |
| ui.gateway.ingressClassName | string | `""` | Ingress Class Name for fallback Ingress |
| ui.gateway.parentRefs | list | `[{"name":"labs64io-gateway","namespace":"tools"}]` | Gateway API parent Gateway(s) this module's HTTPRoute attaches to |
| ui.gateway.prefix | string | `"/customer-portal"` | External path prefix; customer-portal-ui serves under /customer-portal |
| ui.gateway.routes | list | `[{"path":"","port":8080,"public":true}]` | Routes exposed by this module |
| ui.gateway.routes[0] | object | `{"path":"","port":8080,"public":true}` | Customer Portal UI static assets. Public: a plain browser navigation can't attach a Bearer token, and the auth-proxy's ForwardAuth policy set is generated from module OpenAPI specs, so it has no entry for a bare UI path anyway (would 403 regardless). This module has no backend API of its own yet. |
| ui.gateway.sharedMiddlewares | object | `{"auth":"gateway-common-auth","compress":"gateway-common-compress","rateLimit":"gateway-common-ratelimit"}` | Names of the shared middlewares provided by the api-gateway chart (fullnameOverride: gateway-common) |
| ui.image | object | `{"pullPolicy":"IfNotPresent","repository":"labs64/customer-portal-ui","tag":""}` | This sets the container image more information can be found here: https://kubernetes.io/docs/concepts/containers/images/ |
| ui.image.pullPolicy | string | `"IfNotPresent"` | This sets the pull policy for images. |
| ui.image.tag | string | `""` | Overrides the image tag whose default is the chart appVersion. |
| ui.imagePullSecrets | list | `[]` | This is for the secrets for pulling an image from a private repository more information can be found here: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/ |
| ui.nameOverride | string | `""` | This is to override the chart name. |
| ui.networkPolicy.enabled | bool | `false` |  |
| ui.networkPolicy.extraIngress | list | `[]` | Additional raw ingress rules |
| ui.networkPolicy.gatewayNamespace | string | `"tools"` | Namespace where Traefik runs |
| ui.networkPolicy.ingressControllerLabels | object | `{}` | Ingress controller pod-selector labels; defaults to the internal Traefik standard (app.kubernetes.io/name: traefik) when empty @schema type: object additionalProperties: true @schema |
| ui.networkPolicy.observabilityNamespace | string | `"monitoring"` | Namespace the observability/OTel collector runs in |
| ui.podAnnotations | object | `{}` | This is for setting Kubernetes Annotations to a Pod. |
| ui.podDisruptionBudget.enabled | bool | `false` |  |
| ui.podDisruptionBudget.minAvailable | int | `1` |  |
| ui.podLabels | object | `{}` | This is for setting Kubernetes Labels to a Pod. |
| ui.podSecurityContext | object | `{"fsGroup":101,"runAsGroup":101,"runAsNonRoot":true,"runAsUser":101,"seccompProfile":{"type":"RuntimeDefault"}}` | Non-root pod security context. The image is nginx-unprivileged (UID 101), so the whole pod runs unprivileged and listens on 8080. |
| ui.rbac.create | bool | `false` |  |
| ui.rbac.rules | list | `[]` |  |
| ui.replicaCount | int | `1` | This will set the replicaset count more information can be found here: https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/ |
| ui.securityContext.allowPrivilegeEscalation | bool | `false` |  |
| ui.securityContext.capabilities.drop[0] | string | `"ALL"` |  |
| ui.securityContext.readOnlyRootFilesystem | bool | `false` |  |
| ui.service | object | `{"port":8080,"type":"ClusterIP"}` | This is for setting up a service more information can be found here: https://kubernetes.io/docs/concepts/services-networking/service/ |
| ui.service.port | int | `8080` | This sets the ports (non-privileged port served by nginx-unprivileged) |
| ui.service.type | string | `"ClusterIP"` | This sets the service type |
| ui.serviceAccount | object | `{"annotations":{},"automount":true,"create":false,"name":""}` | This section builds out the service account more information can be found here: https://kubernetes.io/docs/concepts/security/service-accounts/ |
| ui.serviceAccount.annotations | object | `{}` | Annotations to add to the service account |
| ui.serviceAccount.automount | bool | `true` | Automatically mount a ServiceAccount's API credentials? |
| ui.serviceAccount.create | bool | `false` | Specifies whether a service account should be created |
| ui.serviceAccount.name | string | `""` | The name of the service account to use. If not set and create is true, a name is generated using the fullname template |
| ui.tests.enabled | bool | `true` |  |
| ui.tests.healthPath | string | `"/"` | Health endpoint probed by `helm test` |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)

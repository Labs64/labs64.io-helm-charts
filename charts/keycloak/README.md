# keycloak

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 26.7.4](https://img.shields.io/badge/AppVersion-26.7.4-informational?style=flat-square)

Labs64.IO :: Keycloak identity provider

**Homepage:** <https://labs64.io>

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| labs64 | <info@labs64.com> |  |

## Source Code

* <https://github.com/Labs64/labs64.io-helm-charts>
* <https://github.com/keycloak/keycloak>
* <https://github.com/adorsys/keycloak-config-cli>

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| file://../chart-libs | chart-libs | 0.8.0 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` |  |
| chart-libs | object | `{}` | Values key injected for the library dependency. @schema type: object additionalProperties: true @schema |
| database.database | string | `"keycloak"` |  |
| database.existingSecret | string | `""` |  |
| database.host | string | `""` |  |
| database.port | int | `5432` |  |
| enabled | bool | `true` |  |
| env | list | `[]` |  |
| externalSecrets.enabled | bool | `false` |  |
| externalSecrets.secretKey | string | `""` |  |
| externalSecrets.storeName | string | `"local-kubernetes-store"` |  |
| fullnameOverride | string | `"keycloak"` | Stable service/workload name used by api-gateway discovery URLs. |
| gateway.enabled | bool | `true` |  |
| gateway.hostnames[0] | string | `"keycloak.localhost"` |  |
| gateway.parentRefs[0].name | string | `"gateway"` |  |
| gateway.parentRefs[0].namespace | string | `"tools"` |  |
| hostname.backchannelDynamic | bool | `true` |  |
| hostname.frontendUrl | string | `"http://keycloak.localhost"` | Canonical public base URL. This determines the realm issuer. |
| hostname.proxyHeaders | string | `"xforwarded"` |  |
| image.digest | string | `""` |  |
| image.pullPolicy | string | `"IfNotPresent"` |  |
| image.repository | string | `"quay.io/keycloak/keycloak"` |  |
| image.tag | string | `""` |  |
| imagePullSecrets | list | `[]` |  |
| livenessProbe.failureThreshold | int | `3` |  |
| livenessProbe.httpGet.path | string | `"/health/live"` |  |
| livenessProbe.httpGet.port | string | `"management"` |  |
| livenessProbe.periodSeconds | int | `10` |  |
| livenessProbe.timeoutSeconds | int | `2` |  |
| mode | string | `"development"` | Runtime profile. Development uses Keycloak's embedded dev database; production requires an external PostgreSQL database and HTTPS hostname. |
| nameOverride | string | `""` |  |
| networkPolicy.apiGatewayLabels."app.kubernetes.io/name" | string | `"api-gateway"` |  |
| networkPolicy.applicationNamespace | string | `""` | Namespace allowed to call Keycloak directly. Empty means the release namespace. |
| networkPolicy.enabled | bool | `true` |  |
| networkPolicy.extraEgress | list | `[]` | Production database egress must be explicitly scoped here. |
| networkPolicy.gatewayNamespace | string | `"tools"` |  |
| networkPolicy.ingressControllerLabels."app.kubernetes.io/name" | string | `"traefik"` |  |
| nodeSelector | object | `{}` |  |
| persistence | object | `{"accessModes":["ReadWriteOnce"],"annotations":{},"enabled":false,"size":"1Gi","storageClass":""}` | Persist Keycloak's embedded dev database across pod restarts. Enable only for the single-replica development mode; production uses an external database. |
| podAnnotations | object | `{}` |  |
| podDisruptionBudget.enabled | bool | `true` |  |
| podDisruptionBudget.minAvailable | int | `1` |  |
| podLabels | object | `{}` |  |
| podSecurityContext.fsGroup | int | `1000` |  |
| readinessProbe.failureThreshold | int | `6` |  |
| readinessProbe.httpGet.path | string | `"/health/ready"` |  |
| readinessProbe.httpGet.port | string | `"management"` |  |
| readinessProbe.periodSeconds | int | `5` |  |
| readinessProbe.timeoutSeconds | int | `2` |  |
| realmConfig | object | `{"backoffLimit":6,"config":"","existingConfigMap":"","image":{"digest":"","pullPolicy":"IfNotPresent","repository":"docker.io/adorsys/keycloak-config-cli","tag":"6.5.1-26"},"resources":{"limits":{"cpu":"250m","memory":"256Mi"},"requests":{"cpu":"25m","memory":"128Mi"}},"secretName":"","timeout":"180s"}` | Declarative realm reconciliation. Keep ecosystem-specific definitions outside this reusable chart and inject a file with --set-file realmConfig.config=realm.json. |
| realmConfig.config | string | `""` | Realm JSON or YAML consumed by keycloak-config-cli. |
| realmConfig.existingConfigMap | string | `""` | Use an externally managed ConfigMap instead of realmConfig.config. Every JSON/YAML file in it is reconciled, so this also supports multiple realms. |
| realmConfig.secretName | string | `""` | Secret exposed only to the reconciler for $(env:NAME) substitutions. Defaults to this release's Secret. |
| replicaCount | int | `1` |  |
| resources.limits.cpu | string | `"1"` |  |
| resources.limits.memory | string | `"1Gi"` |  |
| resources.requests.cpu | string | `"100m"` |  |
| resources.requests.memory | string | `"512Mi"` |  |
| secrets | object | `{"data":{"KC_BOOTSTRAP_ADMIN_PASSWORD":"change-me","KC_BOOTSTRAP_ADMIN_USERNAME":"admin","KC_DB_PASSWORD":"change-me","KC_DB_USERNAME":"keycloak"}}` | Credentials are always rendered into Secret/ExternalSecret, never ConfigMap. Replace these development placeholders through an ignored local override. |
| securityContext.allowPrivilegeEscalation | bool | `false` |  |
| securityContext.capabilities.drop[0] | string | `"ALL"` |  |
| securityContext.readOnlyRootFilesystem | bool | `false` |  |
| securityContext.runAsGroup | int | `1000` |  |
| securityContext.runAsNonRoot | bool | `true` |  |
| securityContext.runAsUser | int | `1000` |  |
| securityContext.seccompProfile.type | string | `"RuntimeDefault"` |  |
| service.managementPort | int | `9000` |  |
| service.port | int | `8080` |  |
| service.type | string | `"ClusterIP"` |  |
| serviceAccount.annotations | object | `{}` |  |
| serviceAccount.automount | bool | `false` |  |
| serviceAccount.create | bool | `true` |  |
| serviceAccount.name | string | `""` |  |
| startupProbe.failureThreshold | int | `60` |  |
| startupProbe.httpGet.path | string | `"/health/started"` |  |
| startupProbe.httpGet.port | string | `"management"` |  |
| startupProbe.periodSeconds | int | `5` |  |
| startupProbe.timeoutSeconds | int | `2` |  |
| terminationGracePeriodSeconds | int | `30` |  |
| tolerations | list | `[]` |  |
| volumeMounts | list | `[]` |  |
| volumes | list | `[]` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)

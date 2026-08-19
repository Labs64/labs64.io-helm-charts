# labs64io-ecosystem

![Version: 0.7.0](https://img.shields.io/badge/Version-0.7.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.0.1](https://img.shields.io/badge/AppVersion-0.0.1-informational?style=flat-square)

Labs64.IO :: Umbrella Chart for entire Ecosystem

**Homepage:** <https://labs64.io>

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| file://../api-docs | api-docs | >=0.1.0 |
| file://../api-gateway | api-gateway | >=0.1.0 |
| file://../auditflow | auditflow | >=0.1.0 |
| file://../authz-pdp | authz-pdp | >=0.1.0 |
| file://../checkout | checkout | >=0.1.0 |
| file://../customer-portal | customer-portal | >=0.1.0 |
| file://../mock-oidc | mock-oidc | >=0.1.0 |
| file://../payment-gateway | payment-gateway | >=0.1.0 |
| https://charts.bitnami.com/bitnami | postgresql | 18.7.11 |
| https://charts.bitnami.com/bitnami | rabbitmq | 16.0.14 |
| https://charts.bitnami.com/bitnami | redis | 27.0.13 |
| https://traefik.github.io/charts | traefik | 41.0.1 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| api-docs.enabled | bool | `true` |  |
| api-gateway.enabled | bool | `true` |  |
| auditflow.enabled | bool | `true` |  |
| authz-pdp.enabled | bool | `true` |  |
| checkout | object | `{"enabled":false}` | Not GA. The labs64/checkout and labs64/checkout-ui images have never been published (both repositories 404 on Docker Hub), so enabling this yields ImagePullBackOff. Toggle retained for when they are. |
| customer-portal | object | `{"enabled":false}` | Not GA. labs64/customer-portal-ui publishes no tags. Enable only once you have a published customer-portal-ui image. |
| demoMode | bool | `false` | Demo mode. Permits the dev-grade default passwords below and unlocks the dev-only mock-oidc subchart. MUST be false for any real deployment: with it false, the chart refuses to render while any password is still at its default. |
| global.postgresql.database | string | `"labs64io"` |  |
| global.postgresql.host | string | `"labs64io-postgresql"` |  |
| global.postgresql.port | int | `5432` |  |
| global.postgresql.username | string | `"labs64"` |  |
| global.rabbitmq.host | string | `"labs64io-rabbitmq"` |  |
| global.rabbitmq.port | int | `5672` |  |
| global.rabbitmq.username | string | `"labs64"` |  |
| global.redis.host | string | `"labs64io-redis-master"` |  |
| global.redis.port | int | `6379` |  |
| global.security | object | `{"allowInsecureImages":true}` | Required by the bitnamilegacy image override under `rabbitmq` below: the Bitnami charts refuse a repository they do not recognise as official unless this is set. |
| global.sharedConfig.enabled | bool | `true` |  |
| global.sharedConfig.name | string | `"labs64io-shared-config"` |  |
| global.sharedSecret.enabled | bool | `true` |  |
| global.sharedSecret.name | string | `"labs64io-shared-secret"` |  |
| mock-oidc | object | `{"enabled":false}` | Dev-only OIDC provider. Requires demoMode=true — the chart refuses to render otherwise. Issues tokens to anyone who asks and authenticates nobody; never enable it outside a throwaway demo. |
| payment-gateway.enabled | bool | `true` |  |
| postgresql.auth.database | string | `"labs64io"` |  |
| postgresql.auth.existingSecret | string | `"labs64io-shared-secret"` |  |
| postgresql.auth.secretKeys.adminPasswordKey | string | `"SPRING_DATASOURCE_PASSWORD"` |  |
| postgresql.auth.secretKeys.userPasswordKey | string | `"SPRING_DATASOURCE_PASSWORD"` |  |
| postgresql.auth.username | string | `"labs64"` |  |
| postgresql.enabled | bool | `true` |  |
| postgresql.fullnameOverride | string | `"labs64io-postgresql"` | Pinned so `global.postgresql.host` above can be a plain string (standalone architecture: no "-primary" suffix on the resulting service name) |
| rabbitmq.auth.existingPasswordSecret | string | `"labs64io-shared-secret"` |  |
| rabbitmq.auth.existingSecretPasswordKey | string | `"SPRING_RABBITMQ_PASSWORD"` |  |
| rabbitmq.auth.username | string | `"labs64"` |  |
| rabbitmq.enabled | bool | `true` |  |
| rabbitmq.fullnameOverride | string | `"labs64io-rabbitmq"` | Pinned so `global.rabbitmq.host` above can be a plain string |
| rabbitmq.image | object | `{"registry":"docker.io","repository":"bitnamilegacy/rabbitmq","tag":"4.1.3-debian-12-r1"}` | docker.io/bitnami/rabbitmq:4.1.3-debian-12-r1 (the subchart default) returns 404: since 2025-08-28 the Bitnami free tier carries only rolling tags, and this is the one bundled subchart that pins a versioned one. The versioned image lives in bitnamilegacy/*, which needs global.security.allowInsecureImages above. Same fix as overrides/rabbitmq/values.local.yaml and charts/preflight. @schema type: object additionalProperties: true @schema |
| redis.architecture | string | `"standalone"` |  |
| redis.auth.existingSecret | string | `"labs64io-shared-secret"` |  |
| redis.auth.existingSecretPasswordKey | string | `"SPRING_DATA_REDIS_PASSWORD"` |  |
| redis.enabled | bool | `true` |  |
| redis.fullnameOverride | string | `"labs64io-redis"` | Pinned so `global.redis.host` above can be a plain string (standalone architecture: the primary/master service is named "<fullnameOverride>-master") |
| secrets.data | object | `{}` | Additional key/value pairs merged into the shared Secret verbatim. Same shape as every module chart's `secrets.data`, so one caller code path covers both. Keys here win over the aliases above on collision. @schema type: object additionalProperties: true @schema |
| secrets.postgresqlPassword | string | `"labs64_dev_password"` | Convenience aliases for the three bundled-infra passwords, injected into labs64io-shared-secret. The shipped values are dev defaults — with `demoMode: false` (the default) the chart fails to render until they change. |
| secrets.rabbitmqPassword | string | `"labs64_dev_password"` | See `secrets.postgresqlPassword`. |
| secrets.redisPassword | string | `"labs64_dev_password"` | See `secrets.postgresqlPassword`. |
| traefik | object | `{"enabled":false,"gateway":{"enabled":true,"listeners":{"web":{"namespacePolicy":{"from":"All"},"port":8000,"protocol":"HTTP"}},"name":"labs64io-gateway","namespace":"tools"},"gatewayClass":{"enabled":true},"providers":{"kubernetesGateway":{"enabled":true}}}` | Opt-in Gateway. Without a GatewayClass and a Gateway named labs64io-gateway, every module's HTTPRoute renders but sits Accepted:False and receives no traffic — pods running, nothing to curl. Enable this, or provision an equivalent Gateway yourself (see "Gateway API setup" in the chart repo's README).  The Gateway API CRDs are deliberately NOT bundled: Helm never upgrades CRDs from a chart's crds/ after first install. Apply them separately (`just install-crds`, or install.sh, which does it with `kubectl apply --server-side`). |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)

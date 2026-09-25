# labs64io-ecosystem

![Version: 0.20.0](https://img.shields.io/badge/Version-0.20.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)

Labs64.IO :: Umbrella chart for deploying the Labs64.IO ecosystem and optional infrastructure

**Homepage:** <https://labs64.io>

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| Labs64 | <info@labs64.com> | <https://labs64.io> |

## Source Code

* <https://github.com/Labs64/labs64.io-helm-charts>

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
| https://charts.bitnami.com/bitnami | redis(valkey) | 6.3.0 |
| https://traefik.github.io/charts | traefik | 41.6.0 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| api-docs.enabled | bool | `true` |  |
| api-gateway.enabled | bool | `true` |  |
| auditflow.enabled | bool | `true` |  |
| authz-pdp.enabled | bool | `true` |  |
| checkout | object | `{"enabled":false,"migrationJob":{"enabled":false}}` | Not GA. The labs64/checkout and labs64/checkout-ui images have never been published (both repositories 404 on Docker Hub), so enabling this yields ImagePullBackOff. Toggle retained for when they are. |
| customer-portal | object | `{"enabled":false}` | Not GA. labs64/customer-portal-ui publishes no tags. Enable only once you have a published customer-portal-ui image. |
| demoMode | bool | `false` | Demo mode. Permits the dev-grade default passwords below and unlocks the dev-only mock-oidc subchart. MUST be false for any real deployment: with it false, the chart refuses to render while any password is still at its default. |
| global.postgresql.database | string | `"labs64io"` |  |
| global.postgresql.host | string | `"labs64io-postgresql"` |  |
| global.postgresql.port | int | `5432` |  |
| global.postgresql.username | string | `"labs64"` |  |
| global.rabbitmq.host | string | `"labs64io-rabbitmq"` |  |
| global.rabbitmq.port | int | `5672` |  |
| global.rabbitmq.username | string | `"labs64"` |  |
| global.redis.host | string | `"labs64io-redis-primary"` |  |
| global.redis.port | int | `6379` |  |
| global.security | object | `{"allowInsecureImages":true}` | Required by the bitnamilegacy image override under `rabbitmq` below: the Bitnami charts refuse a repository they do not recognise as official unless this is set. |
| global.sharedConfig.enabled | bool | `true` |  |
| global.sharedConfig.name | string | `"labs64io-shared-config"` |  |
| global.sharedSecret.enabled | bool | `true` |  |
| global.sharedSecret.name | string | `"labs64io-shared-secret"` |  |
| mock-oidc | object | `{"enabled":false}` | Dev-only OIDC provider. Requires demoMode=true — the chart refuses to render otherwise. Issues tokens to anyone who asks and authenticates nobody; never enable it outside a throwaway demo. |
| networkPolicy | object | `{"enabled":false}` | NetworkPolicy for this chart's own workload (templates/rabbitmq.yaml — the only long-running workload this chart declares itself; every module's own NetworkPolicy is configured under that module's own key, e.g. `auditflow.networkPolicy`). |
| payment-gateway.enabled | bool | `true` |  |
| payment-gateway.migrationJob.enabled | bool | `false` |  |
| postgresql.auth.database | string | `"labs64io"` |  |
| postgresql.auth.existingSecret | string | `"labs64io-shared-secret"` |  |
| postgresql.auth.secretKeys.adminPasswordKey | string | `"SPRING_DATASOURCE_PASSWORD"` |  |
| postgresql.auth.secretKeys.userPasswordKey | string | `"SPRING_DATASOURCE_PASSWORD"` |  |
| postgresql.auth.username | string | `"labs64"` |  |
| postgresql.enabled | bool | `true` |  |
| postgresql.fullnameOverride | string | `"labs64io-postgresql"` | Pinned so `global.postgresql.host` above can be a plain string (standalone architecture: no "-primary" suffix on the resulting service name) |
| postgresql.primary | object | `{"initdb":{"scripts":{"00-labs64io-databases.sql":"SELECT 'CREATE DATABASE payment_gateway'\n  WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'payment_gateway')\\gexec\nSELECT 'CREATE DATABASE checkout'\n  WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'checkout')\\gexec\n"}},"networkPolicy":{"allowExternalEgress":false}}` | Each module owns its own database (db-per-service isolation — see the note on global.postgresql above). The Bitnami chart creates only `auth.database`, and the modules' own pre-install migration Jobs cannot create the rest: they run before this server exists. Creating them here, at first initdb, is the only point in the release where the ordering works. Runs once, on an empty data directory only — enabling a module later needs the database created by hand. @schema type: object additionalProperties: true @schema |
| rabbitmq.auth.existingPasswordSecret | string | `"labs64io-shared-secret"` |  |
| rabbitmq.auth.existingSecretPasswordKey | string | `"SPRING_RABBITMQ_PASSWORD"` |  |
| rabbitmq.auth.username | string | `"labs64"` |  |
| rabbitmq.enabled | bool | `true` |  |
| rabbitmq.fullnameOverride | string | `"labs64io-rabbitmq"` | Pinned so `global.rabbitmq.host` above can be a plain string. Also used directly by templates/rabbitmq.yaml (this is not a chart dependency — see the Chart.yaml comment). |
| rabbitmq.image | object | `{"registry":"docker.io","repository":"library/rabbitmq","tag":"4.3-management"}` | The official image, not Bitnami: pinned to the 4.3.x track (matches Amazon MQ) rather than the floating `4-management` tag, which would silently jump to RabbitMQ 5.x on the next pull. @schema type: object additionalProperties: true @schema |
| rabbitmq.persistence | object | `{"size":"1Gi"}` | Size of the RabbitMQ data volume (StatefulSet volumeClaimTemplate). |
| redis.architecture | string | `"standalone"` |  |
| redis.auth.existingSecret | string | `"labs64io-shared-secret"` |  |
| redis.auth.existingSecretPasswordKey | string | `"SPRING_DATA_REDIS_PASSWORD"` |  |
| redis.enabled | bool | `true` |  |
| redis.fullnameOverride | string | `"labs64io-redis"` | Pinned so `global.redis.host` above can be a plain string (standalone architecture: the primary service is named "<fullnameOverride>-primary") |
| redis.networkPolicy.allowExternalEgress | bool | `false` |  |
| secrets.data | object | `{}` | Additional key/value pairs merged into the shared Secret verbatim. Same shape as every module chart's `secrets.data`, so one caller code path covers both. Keys here win over the aliases above on collision. @schema type: object additionalProperties: true @schema |
| secrets.postgresqlPassword | string | `"labs64_dev_password"` | Convenience aliases for the three bundled-infra passwords, injected into labs64io-shared-secret. The shipped values are dev defaults — with `demoMode: false` (the default) the chart fails to render until they change. |
| secrets.rabbitmqPassword | string | `"labs64_dev_password"` | See `secrets.postgresqlPassword`. |
| secrets.redisPassword | string | `"labs64_dev_password"` | See `secrets.postgresqlPassword`. |
| tests | object | `{"enabled":true,"image":"busybox:1.36","timeoutSeconds":10}` | `helm test` probes each enabled module's health endpoint through its Service. Paths and ports mirror each chart's own readinessProbe, so a passing test means the same thing Kubernetes means by "ready". |
| tests.image | string | `"busybox:1.36"` | Image used to run the probes. Needs only a shell and wget. |
| tests.timeoutSeconds | int | `10` | Per-probe timeout (seconds) |
| traefik | object | `{"enabled":false,"gateway":{"enabled":true,"listeners":{"web":{"namespacePolicy":{"from":"All"},"port":8000,"protocol":"HTTP"}},"name":"labs64io-gateway","namespace":"tools"},"gatewayClass":{"enabled":true},"providers":{"kubernetesGateway":{"enabled":true}}}` | Opt-in Gateway. Without a GatewayClass and a Gateway named labs64io-gateway, every module's HTTPRoute renders but sits Accepted:False and receives no traffic — pods running, nothing to curl. Enable this, or provision an equivalent Gateway yourself (see "Gateway API setup" in the chart repo's README).  The Gateway API CRDs are deliberately NOT bundled: Helm never upgrades CRDs from a chart's crds/ after first install. Apply them separately (`just install-crds`, or install.sh, which does it with `kubectl apply --server-side`). |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)

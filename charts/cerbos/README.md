# cerbos

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.51.0](https://img.shields.io/badge/AppVersion-0.51.0-informational?style=flat-square)

Labs64.IO :: Cerbos PDP — central authorization decision point

**Homepage:** <https://labs64.io>

## How it works

This chart runs the central [Cerbos](https://cerbos.dev) PDP that every
`@Authorize` domain check (Java SDK, gRPC `:3593`) and every edge decision
(traefik-authproxy HTTP client, `:3592`) consults. It is on the hot path of
every request — hence `replicaCount: 2` (HA) and a PodDisruptionBudget.

### Policy pipeline & provenance

Policies are **generated**, never hand-authored (one exception: `static_api.yaml`
for the UI-bundle prefixes). `policies/build-cerbos-policies.sh` runs the commons
`OpenApiAuthPreprocessor` over each module's OpenAPI `x-labs64-auth` and writes:

- `charts/cerbos/policies/*.yaml` — one edge resource policy per module
  (`<module>_api`) plus per-domain-type policies (`<module>_<Type>`), each with
  the structural cross-tenant guard.
- `charts/cerbos/schemas/*.json` — principal + per-type JSON schemas
  (`schema.enforcement: reject` → fail closed on malformed attributes).
- `charts/traefik-authproxy/routes/*.routes.yaml` — the authproxy routing table.

These generated files are **committed and ArgoCD-synced** — the review of the
generated diff is the provenance model (there is no signed OCI bundle anymore).
Regenerate with `just build-policies` after any module OpenAPI change; the script
runs `cerbos compile` as a local gate. OpenAPI stays the single source of truth.

The chart mounts `policies/*` (via `configmap-policies`) at `/policies` and
`schemas/*` at `/policies/_schemas`; checksum annotations roll the PDP whenever
either ConfigMap changes.

### Fail-closed outage drill

Every caller denies when the PDP is unreachable. To verify:

```bash
kubectl -n labs64io scale deploy cerbos --replicas=0
curl -si https://gateway.localhost/payment-gateway/api/v1/... -H "Authorization: Bearer <valid>"   # expect 403
kubectl -n labs64io scale deploy cerbos --replicas=2   # recovers
```

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| labs64 | <info@labs64.com> |  |

## Source Code

* <https://github.com/Labs64/labs64.io-helm-charts>
* <https://github.com/cerbos/cerbos>

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| file://../chart-libs | chart-libs | 0.1.0 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` |  |
| autoscaling.enabled | bool | `false` |  |
| config | object | `{"auditEnabled":false,"schemaEnforcement":"reject"}` | Cerbos server config (rendered into a ConfigMap). Policies are served from the disk store mounted from the policies/schemas ConfigMaps; schema enforcement rejects requests whose attributes violate the JSON schemas (fail closed). |
| env | list | `[]` |  |
| fullnameOverride | string | `""` |  |
| image | object | `{"pullPolicy":"IfNotPresent","repository":"ghcr.io/cerbos/cerbos","tag":""}` | Cerbos container image (third-party; keeps its own non-root user). |
| image.tag | string | `""` | Overrides the image tag whose default is the chart appVersion. |
| imagePullSecrets | list | `[]` |  |
| livenessProbe.httpGet.path | string | `"/_cerbos/health"` |  |
| livenessProbe.httpGet.port | int | `3592` |  |
| livenessProbe.initialDelaySeconds | int | `10` |  |
| livenessProbe.periodSeconds | int | `15` |  |
| nameOverride | string | `""` |  |
| networkPolicy | object | `{"enabled":true,"gatewayNamespace":"tools"}` | Restrict ingress to same-namespace callers (authproxy + module apps). The chart-libs helper allows all same-namespace pods on all ports; no egress needed. |
| nodeSelector | object | `{}` |  |
| podAnnotations | object | `{}` |  |
| podDisruptionBudget.enabled | bool | `true` |  |
| podDisruptionBudget.minAvailable | int | `1` |  |
| podLabels | object | `{}` |  |
| podSecurityContext | object | `{}` |  |
| readinessProbe.httpGet.path | string | `"/_cerbos/health"` |  |
| readinessProbe.httpGet.port | int | `3592` |  |
| readinessProbe.initialDelaySeconds | int | `5` |  |
| readinessProbe.periodSeconds | int | `10` |  |
| replicaCount | int | `2` | Cerbos PDP replicas. On the hot path of every @Authorize / edge decision — keep at least 2 for HA. |
| resources.limits.cpu | string | `"500m"` |  |
| resources.limits.memory | string | `"256Mi"` |  |
| resources.requests.cpu | string | `"50m"` |  |
| resources.requests.memory | string | `"64Mi"` |  |
| securityContext.allowPrivilegeEscalation | bool | `false` |  |
| securityContext.capabilities.drop[0] | string | `"ALL"` |  |
| securityContext.readOnlyRootFilesystem | bool | `true` |  |
| securityContext.runAsNonRoot | bool | `true` |  |
| securityContext.seccompProfile.type | string | `"RuntimeDefault"` |  |
| service.grpcPort | int | `3593` |  |
| service.httpPort | int | `3592` | HTTP API (authproxy edge client) and gRPC API (Java @Authorize SDK). |
| service.type | string | `"ClusterIP"` |  |
| serviceAccount.annotations | object | `{}` |  |
| serviceAccount.automount | bool | `true` |  |
| serviceAccount.create | bool | `true` |  |
| serviceAccount.name | string | `""` |  |
| terminationGracePeriodSeconds | int | `30` |  |
| tolerations | list | `[]` |  |
| volumeMounts | list | `[]` |  |
| volumes | list | `[]` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)

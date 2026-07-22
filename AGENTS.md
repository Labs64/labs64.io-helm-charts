# AGENTS.md — Labs64.IO :: Helm Charts

Public Helm charts for deploying all Labs64.IO modules to Kubernetes. Each module has a standalone chart; all depend on `chart-libs` (shared library).

## Repository layout

| Path | Purpose |
|------|---------|
| `charts/auditflow/` | AuditFlow backend + transformer + sink |
| `charts/checkout/` | Checkout backend + UI (`ui.enabled`, templates prefixed `ui-*`) |
| `charts/payment-gateway/` | Payment gateway backend |
| `charts/customer-portal/` | Customer portal UI (no backend yet; `ui.enabled`, templates prefixed `ui-*`) |
| `charts/api-docs/` | Swagger UI aggregator (formerly `swagger-ui`) |
| `charts/api-gateway/` | ForwardAuth OIDC/JWT verifier + shared Traefik middlewares (merged `traefik-authproxy` + `gateway-common`; `fullnameOverride: gateway-common` keeps the stable middleware-name prefix) |
| `charts/authz-pdp/` | Cerbos PDP — central authorization decision point (formerly `cerbos`) |
| `charts/preflight/` | Infrastructure readiness checks |
| `charts/chart-libs/` | Shared Helm library (all charts depend on this) |
| `helmfile.yaml.gotmpl` | Helmfile state — infra/monitoring/app releases for local + CI deployments |
| `overrides/` | Per-module values files for different profiles; `overrides/eso/` holds the local `ClusterSecretStore` + RBAC for External Secrets Operator |
| `DEVELOPERS.md` | Local development setup guide with architecture diagram |
| `OBSERVABILITY.md` | Canonical observability model for the whole ecosystem (infrastructure-owned instrumentation) |

## Critical guardrails

1. **Chart versions must match** between `Chart.yaml` and ArgoCD ApplicationSet pin.
2. **All module charts depend on `chart-libs`** — do not break this dependency.
3. **Credentials are Kubernetes Secrets** — never ConfigMaps for sensitive data.
4. **Observability is infrastructure-owned** — toggle it via `observability.enabled` (env/annotation injection only); never add OTel SDK deps to services. See [`OBSERVABILITY.md`](OBSERVABILITY.md).
5. **Local + CI deployments go through Helmfile** (`helmfile.yaml.gotmpl`, drives `just up`/`install-tools`/`install-all-apps`) — do not reintroduce raw per-tool `helm upgrade --install` calls into that path; ArgoCD (`labs64.io-devops`) remains the separate GitOps path for real environments.
6. **Secret management is unified via `externalSecrets.enabled`** on every chart with a `secret.yaml`: `false` (default) renders a plain `Secret` from `.Values.secrets.data`; `true` renders an `ExternalSecret` resolved through a `ClusterSecretStore` (local: `overrides/eso/cluster-secret-store.yaml`'s `kubernetes`-provider store; real environments: point `externalSecrets.storeName` at a real backend). Same object shape everywhere — only the backing store differs.

## Provisioning profiles

| Profile | File pattern | Use case |
|---------|-------------|----------|
| Local | `overrides/<module>/values.local.yaml` | Dev cluster with shared toolset |
| Production | `overrides/<module>/values.prod-example.yaml` | Copy & adapt for your infrastructure |

Infrastructure is decoupled from application charts — no module chart bundles RabbitMQ/PostgreSQL/Redis
as a dependency anymore; every app connects to externally-provisioned infra via `applicationYaml`
(defaults point at the shared `tools`-namespace services). There is no "standalone, bundled-infra"
profile — evaluate a single module against the shared local toolset (`just install-tools`) instead.

## Build, run, test

```bash
just up                      # k3d cluster + registry + all modules (Helmfile-driven)
just up-full                 # + monitoring stack, observability enabled
just reset                   # uninstall apps/monitoring/tools, keep the cluster
just cluster-down            # delete the k3d cluster
just install-app auditflow   # install/reinstall a single module
just generate-all            # regenerate chart README + values.schema.json
```

## Where to make common changes

| Goal | Where |
|------|-------|
| Module templates | `charts/<module>/templates/` |
| Shared Helm helpers | `charts/chart-libs/templates/` |
| Default values | `charts/<module>/values.yaml` |
| Local dev overrides | `overrides/<module>/values.local.yaml` |
| Pinned chart versions | `justfile` (version variables at top) |
| Observability wiring / collector pipelines | `OBSERVABILITY.md` + `overrides/opentelemetry/` |

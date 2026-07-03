# AGENTS.md — Labs64.IO :: Helm Charts

Guidance for AI agents working in this repository. Read this before making changes.

## What this project is

Public Helm charts for deploying all Labs64.IO modules to Kubernetes. Each module has a standalone chart; they share a common library chart (`chart-libs`). Published to Artifact Hub.

## Repository layout

| Path | Purpose |
|------|---------|
| `charts/auditflow/` | AuditFlow backend + transformer + sink |
| `charts/checkout/` | Checkout backend |
| `charts/checkout-ui/` | Checkout frontend |
| `charts/payment-gateway/` | Payment gateway backend |
| `charts/customer-portal/` | Customer portal backend |
| `charts/customer-portal-ui/` | Customer portal frontend |
| `charts/gateway/` | Swagger UI aggregator |
| `charts/gateway-common/` | Shared Traefik middlewares (auth, rate limit, headers) |
| `charts/traefik-authproxy/` | ForwardAuth OIDC/JWT verifier |
| `charts/preflight/` | Infrastructure readiness checks |
| `charts/chart-libs/` | Shared Helm library (all charts depend on this) |
| `overrides/` | Per-module values files for different profiles |
| `k3d/` | Local k3d cluster configuration |

## Critical guardrails

1. **Chart versions must match** between `Chart.yaml` and the ArgoCD ApplicationSet pin in `labs64.io-devops`.
2. **All module charts depend on `chart-libs`** — do not break this dependency.
3. **Credentials are stored as Kubernetes Secrets** — never ConfigMaps for sensitive data.
4. **Each repo has its own git history** — do not cross-commit between repositories.

## Chart structure

Each module chart follows a standard structure:
- `Chart.yaml` — chart metadata and dependencies
- `values.yaml` — default values
- `templates/` — Kubernetes manifests
- `templates/tests/` — Helm test definitions

All module charts depend on `chart-libs` for shared helpers and templates.

## Provisioning profiles

| Profile | File pattern | Use case |
|---------|-------------|----------|
| Shared local | `overrides/<module>/values.local.yaml` | Dev cluster with shared toolset (`just local-up`) |
| Standalone | `overrides/<module>/values.standalone.yaml` | Single-module eval with bundled infra |
| BYO / production | `overrides/<module>/values.prod-example.yaml` | Copy & adapt: your infrastructure, credentials via `secrets.data` |

## Module capabilities

| Module | Needs |
|--------|-------|
| auditflow | AMQP 0-9-1 broker |
| checkout | AMQP 0-9-1 broker; PostgreSQL (db `checkout`) |
| payment-gateway | AMQP 0-9-1 broker; PostgreSQL (db `payment_gateway`); Redis |
| gateway stack | Any OIDC provider supporting `client_credentials` |

## Build, run, test

```bash
just local-up                    # k3d cluster + all modules
just local-up-full               # + monitoring stack
just local-down                  # delete cluster

just labs64io-auditflow-install  # install single module
just labs64io-auditflow-uninstall
just labs64io-standalone-install checkout  # standalone with bundled infra

just generate-docu               # regenerate chart README.md files
just generate-schema             # regenerate values.schema.json
just generate-all                # both

just repo-update                 # helm repo update
just labs64io-show-errors        # grep for errors in logs
```

## Conventions

- Chart versions are pinned in the justfile (e.g., `RABBITMQ_CHART_VERSION`, `POSTGRESQL_CHART_VERSION`).
- Gateway integration (`gateway.enabled: true`) requires Traefik v3 CRDs plus `gateway-common` and `traefik-authproxy` charts.
- Local testing: `just mock-oidc-install` for dev-only M2M tokens, `just labs64io-e2e-auth` for end-to-end auth smoke test.

## Where to make common changes

| Goal | Where |
|------|-------|
| Change a module's templates | `charts/<module>/templates/` |
| Change shared Helm helpers | `charts/chart-libs/templates/` |
| Add a new module chart | `charts/<module>/` (copy pattern from existing) |
| Change default values | `charts/<module>/values.yaml` |
| Override for local dev | `overrides/<module>/values.local.yaml` |
| Override for standalone | `overrides/<module>/values.standalone.yaml` |
| Change pinned chart versions | `justfile` (version variables at top) |
| Update k3d config | `k3d/labs64io.yaml` |

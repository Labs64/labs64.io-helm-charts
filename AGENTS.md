# AGENTS.md — Labs64.IO :: Helm Charts

Public Helm charts for deploying all Labs64.IO modules to Kubernetes. Each module has a standalone chart; all depend on `chart-libs` (shared library).

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
| `charts/gateway-common/` | Shared Traefik middlewares |
| `charts/traefik-authproxy/` | ForwardAuth OIDC/JWT verifier |
| `charts/preflight/` | Infrastructure readiness checks |
| `charts/chart-libs/` | Shared Helm library (all charts depend on this) |
| `overrides/` | Per-module values files for different profiles |
| `DEVELOPERS.md` | Local development setup guide with architecture diagram |

## Critical guardrails

1. **Chart versions must match** between `Chart.yaml` and ArgoCD ApplicationSet pin.
2. **All module charts depend on `chart-libs`** — do not break this dependency.
3. **Credentials are Kubernetes Secrets** — never ConfigMaps for sensitive data.

## Provisioning profiles

| Profile | File pattern | Use case |
|---------|-------------|----------|
| Local | `overrides/<module>/values.local.yaml` | Dev cluster with shared toolset |
| Standalone | `overrides/<module>/values.standalone.yaml` | Single-module eval with bundled infra |
| Production | `overrides/<module>/values.prod-example.yaml` | Copy & adapt for your infrastructure |

## Build, run, test

```bash
just local-up                # k3d cluster + all modules
just local-up-full           # + monitoring stack
just local-down              # delete cluster
just labs64io-auditflow-install  # install single module
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

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
| `overrides/` | Per-module values files for the different [Deployment Modes](#deployment-modes) below; `overrides/eso/` holds the local `ClusterSecretStore` + RBAC for External Secrets Operator |
| `DEVELOPERS.md` | Local development setup guide with architecture diagram |
| `OBSERVABILITY.md` | Canonical observability model for the whole ecosystem (infrastructure-owned instrumentation) |

## Critical guardrails

1. **Chart versions must match** between `Chart.yaml` and ArgoCD ApplicationSet pin.
2. **All module charts depend on `chart-libs`** — do not break this dependency.
3. **Credentials are Kubernetes Secrets** — never ConfigMaps for sensitive data. Enforced by
   `just lint-secrets` (`scripts/lint-configmap-secrets.py`) in chart CI: it renders every chart
   against default values *and* each `overrides/<chart>/values.*.yaml`, then walks the rendered
   ConfigMaps — including trees nested inside `applicationYaml`, which a template-level grep cannot
   see. False positives go in `scripts/configmap-secrets-allowlist.yaml` **with a stated reason**.
4. **Observability is infrastructure-owned** — toggle it via `observability.enabled` (env/annotation injection only); never add OTel SDK deps to services. See [`OBSERVABILITY.md`](OBSERVABILITY.md).
5. **Local + CI deployments go through Helmfile** (`helmfile.yaml.gotmpl`, drives `just up`/`install-tools`/`install-all-apps`) — do not reintroduce raw per-tool `helm upgrade --install` calls into that path; ArgoCD (`labs64.io-devops`) remains the separate GitOps path for the AWS QA / Staging / Prod Environment (see [Deployment Modes](#deployment-modes) below).
6. **Secret management is unified via `externalSecrets.enabled`** on every chart with a `secret.yaml`: `false` (default) renders a plain `Secret` from `.Values.secrets.data`; `true` renders an `ExternalSecret` resolved through a `ClusterSecretStore` (local: `overrides/eso/cluster-secret-store.yaml`'s `kubernetes`-provider store; AWS QA / Staging / Prod Environment: point `externalSecrets.storeName` at a real backend like AWS Secrets Manager). Same object shape everywhere — only the backing store differs.
7. **Chart authoring checklist** (`just lint-authoring` / `scripts/lint-chart-authoring.py`, chart CI) — four rules, each a running gate, not prose:
   - No module chart may declare `kind: Ingress` directly — only `chart-libs.gateway-routes` may (it hard-fails the render if a non-public route would be served through it, since Ingress has no ForwardAuth/Cerbos equivalent).
   - Every `subPath` volume mount must be in `scripts/chart-authoring-allowlist.yaml` with a reason — a subPath mount does not receive live ConfigMap/Secret updates (no kubelet periodic sync).
   - Every container in a rendered Deployment needs both a `livenessProbe` and a `readinessProbe`, each with `periodSeconds > 0` and `failureThreshold > 0`.
   - Every chart with a long-running workload (backend and/or UI) must declare a `networkPolicy` (or `ui.networkPolicy`) key, and its egress rules must never be an allow-all — see guardrail 10 in the workspace `AGENTS.md`. Umbrella charts (no workload of their own) and one-shot Job charts (e.g. `preflight`, which needs broad connectivity by design) are exempt.
8. **Never render an image reference by hand** — always
   `{{ include "chart-libs.image" (dict "imageRoot" .Values.<path>.image "context" $) }}`, including
   inside `extraContainers` strings. Precedence is digest → explicit tag → `.Chart.AppVersion`, so
   setting `image.digest` (`sha256:<64 hex>`, validated at render) pins the deployment to exact
   content. Neither Docker Hub nor GHCR can enforce tag immutability, so the digest is the only
   deployment identity that cannot be moved out from under a running workload — shared environments
   should pin it in `overrides/<module>/values.<env>.yaml`; local dev keeps using tags.

## Deployment Modes

| Mode | File pattern | Use case |
|---------|-------------|----------|
| Local Development | `overrides/<module>/values.local.yaml` | Dev cluster with shared toolset via Helmfile (`just up`) |
| AWS QA / Staging / Prod Environment | ArgoCD + Terraform | GitOps-driven deployment connecting to Terraform-provisioned AWS infra |
| Users' Own Infrastructure (BYO Infra) | `overrides/<module>/values.prod-example.yaml` | Copy & adapt for your own infrastructure and external services |

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

## Release propagation

A module release does not update its chart by hand. The publish workflow reports each
image's digest, dispatches `module-released` to this repo, and
`.github/workflows/labs64io-chart-image-update.yml` opens a PR that pins the digests:

```
module release  →  docker-publish.yml (digest)  →  chart-update-dispatch.yml
                →  labs64io-chart-image-update.yml  →  scripts/update-chart-images.py  →  PR
```

What the updater guarantees, and why you should not hand-edit around it:

- **All-or-nothing.** Every first-party (`labs64/…`) image in the chart must be pinned in
  one go — a chart's images share one `appVersion`, so a partial pin deploys a mix no
  release ever validated. Third-party wrappers (swagger-ui, cerbos) are exempt.
- **Chart version always bumps** when anything changes, because `chart-releaser` runs with
  `skip_existing: true` and would silently not republish otherwise.
- **Idempotent.** Replaying a release event is a no-op, so a redelivered dispatch cannot
  inflate the chart version.
- **Comments survive.** Edits are line-level; a PyYAML round-trip would strip every `# --`
  helm-docs annotation in `values.yaml`.

Replay or pin by hand with `just update-chart-images <chart> <version> --image repo@sha256:…`
(repeat `--image` per image), or re-run the workflow via `workflow_dispatch`.

Requires `CHART_DISPATCH_TOKEN` (a PAT with `contents: write` here) on the module repo, and
`CHART_UPDATE_TOKEN` here so the generated PR triggers chart CI. Without the first, releases
still succeed and print the exact `gh api` command to run manually.

## Where to make common changes

| Goal | Where |
|------|-------|
| Module templates | `charts/<module>/templates/` |
| Shared Helm helpers | `charts/chart-libs/templates/` |
| Default values | `charts/<module>/values.yaml` |
| Local dev overrides | `overrides/<module>/values.local.yaml` |
| Pinned chart versions | `justfile` (version variables at top) |
| Release digest propagation | `scripts/update-chart-images.py` + `.github/workflows/labs64io-chart-image-update.yml` |
| Observability wiring / collector pipelines | `OBSERVABILITY.md` + `overrides/opentelemetry/` |

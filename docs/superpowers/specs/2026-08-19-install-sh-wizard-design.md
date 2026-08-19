# `install.sh` setup wizard — design

Status: approved (design phase) · Date: 2026-08-19

## Purpose

A single, `curl | bash`-able wizard script that takes a user from a
bare Kubernetes cluster (with `kubectl`/`helm` configured) to a running
labs64.io deployment: collect configuration interactively, generate
Helm values files, invoke `helm`. Targets the "Users' Own
Infrastructure (BYO Infra)" deployment mode documented in the repo
README — it does not replace the Helmfile/k3d local-dev flow (`just
up`) or the ArgoCD/Terraform GitOps flow, both of which remain
untouched.

## Prerequisites (checked by the script, not assumed)

- A reachable Kubernetes cluster, `kubectl` configured against it
- `helm` installed
- Network access to `https://labs64.github.io/labs64.io-helm-charts`
  and (if BYO infra is chosen) to the user's PostgreSQL/RabbitMQ/Redis

## Top-level flow

```
1. check prerequisites (kubectl, helm, cluster reachable) — fail fast with remediation
2. if ./labs64io-install/ already exists: offer [reuse saved answers] or [redo wizard]
3. choose install shape: [full ecosystem] or [pick modules]
4. module selection (per-module mode only; full-ecosystem enables all)
5. infra mode per dependency (postgres/rabbitmq/redis): [bundled] or [BYO — collect host/port/user/db]
6. detect Gateway API CRDs in-cluster:
     found    → collect Gateway name/namespace (default labs64io-gateway/tools)
     missing  → fall back to plain Ingress, collect ingressClassName
7. OIDC: discovery URL + client id/secret — skipped if no protected routes are in scope
8. secrets: auto-generate anything not supplied; echo generated values back for the
   user to confirm/override for BYO fields
9. write ./labs64io-install/{values-overrides.yaml, secrets.yaml, preflight-values.yaml}
10. helm repo add/update labs64io-helm-charts; resolve latest version per selected chart
    via `helm search repo`
11. if BYO infra was selected: helm install/upgrade preflight -f preflight-values.yaml,
    kubectl wait --for=condition=complete, abort with `kubectl logs` on failure
12. helm upgrade --install (one release for ecosystem mode, one per chart in
    per-module mode) -f values-overrides.yaml [-f secrets.yaml]
13. print NOTES: status check commands, uninstall commands, how to re-run to change config
```

Re-running is safe: step 2 detects prior state, and step 12 always uses
`helm upgrade --install`, so repeated runs converge rather than
duplicate releases.

## Module selection

Selectable: `auditflow`, `checkout`, `payment-gateway`,
`customer-portal` (app modules) and `api-gateway`, `authz-pdp`,
`api-docs` (platform pieces) — the same set as
`labs64io-ecosystem/values.yaml`'s toggle list.

- **Full ecosystem**: all toggles default `true`; infra/gateway/OIDC
  are asked once, shared across every module.
- **Pick modules**: user selects app modules directly; the wizard then
  checks whether any selected module declares a protected gateway
  route (per the README's module table) and, if so, prompts to also
  include `api-gateway` + `authz-pdp` (default yes, can decline —
  script warns that protected routes will fail to render without
  Gateway API/ForwardAuth in place, matching the chart's own
  fail-fast behavior).

## Values generation

Two generation paths sharing the same collected answers, kept as
separate functions in the script so each can be tested independently:

- **Ecosystem mode** — single `values-overrides.yaml` matching
  `labs64io-ecosystem/values.yaml`'s shape: `<module>.enabled` flags,
  `global.postgresql/rabbitmq/redis`, `secrets.data`,
  `postgresql.enabled`/`rabbitmq.enabled`/`redis.enabled` for the
  bundled-infra case.
- **Per-module mode** — one values file per selected chart (e.g.
  `payment-gateway.values.yaml`), seeded from that chart's
  `values.standalone.yaml` structure: `global.postgresql`/`redis` host
  and port, `secrets.data`, `applicationYaml`, `gateway.*`. Standalone
  releases are independent `helm` releases and don't share one values
  file.

## Secrets handling

All passwords / client secrets (DB, broker, OIDC client secret, shared
secret) are written to a **separate** `secrets.yaml`, `chmod 600`,
passed as an additional `-f` to `helm`. The output directory gets a
generated `.gitignore` covering `secrets.yaml`. This keeps credentials
out of the values file a user might paste into a support ticket or
commit by habit.

Values not explicitly supplied by the user (bundled-infra passwords,
shared secret) are auto-generated (strong random). Anything the user
must know to connect to their own infra (BYO host/user/password, OIDC
client secret) is always prompted for — never silently generated.

## Gateway / OIDC detection

Gateway API CRD presence is checked via `kubectl get crd
gateways.gateway.networking.k8s.io` (or equivalent) at wizard time; the
result only changes which fields are collected, it does not create the
`Gateway`/`GatewayClass` resource itself — the same division of
responsibility as today (README: "None of these charts create the
Gateway API `Gateway` resource itself").

## File layout

```
./labs64io-install/
  values-overrides.yaml       # ecosystem mode
  <chart>.values.yaml         # per-module mode, one per selected chart
  secrets.yaml                # chmod 600, gitignored
  preflight-values.yaml       # only when BYO infra selected
  .gitignore                  # covers secrets.yaml
```

## Error handling

- Missing prerequisite → fail fast, print the exact remediation
  command (e.g. install link for `helm`, `kubectl config` hint).
- Preflight Job failure → print `kubectl logs job/preflight
  --all-containers`, abort before touching module charts.
- `helm upgrade --install` failure on one chart in per-module mode →
  report which releases succeeded/failed by name; do not roll back
  the others (releases are already independent).

## Distribution

Lives at the repo root (`labs64.io-helm-charts/install.sh`),
documented as:

```
curl -fsSL https://raw.githubusercontent.com/Labs64/labs64.io-helm-charts/master/install.sh | bash
```

Pure POSIX-ish bash (matches the sketch), no external dependencies
beyond `kubectl`/`helm`/`curl` already required by the prerequisites.

## Version resolution

No hardcoded chart versions. The script does `helm repo add
labs64io-helm-charts ...` + `helm repo update`, then lets `helm
upgrade --install` resolve each selected chart to its latest version
by omitting `--version` (Helm's default). No `helm search`
parsing needed.

## Testing

No unit-test framework exists for shell scripts in this repo today
(the Python `scripts/*.py` linters have pytest; this is bash). Plan:
a smoke test that drives the wizard non-interactively (answers
supplied via env vars) against a local k3d cluster, reusing this
repo's existing `just up` / k3d tooling. Run manually against a live
cluster; not wired into CI initially.

## Out of scope (v1)

- Non-interactive / CI mode (fully flag-driven, no prompts)
- Modifying/uninstall wizard (uninstall documented as a manual next
  step in the printed NOTES)
- Creating the shared `Gateway`/`GatewayClass` resource
- Bundling infra for per-module (cherry-pick) mode — bundled infra is
  only offered through the ecosystem chart, matching today's chart
  design (standalone charts don't bundle infra as a subchart)

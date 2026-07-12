<p align="center"><img src="https://raw.githubusercontent.com/Labs64/.github/refs/heads/master/assets/labs64-io-ecosystem.png"></p>

# Labs64.IO :: Helm Charts

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/labs64io-helm-charts)](https://artifacthub.io/packages/search?repo=labs64io-helm-charts)
[![📖 Documentation](https://img.shields.io/badge/📖-Documentation-AB6543.svg)](https://github.com/Labs64/labs64.io-docs)

## Usage

[Helm](https://helm.sh) must be installed to use the charts.  Please refer to Helm's [documentation](https://helm.sh/docs) to get started.

Once Helm is properly set up, add the repository as follows:
```
helm repo add <alias> https://labs64.github.io/labs64.io-helm-charts
```

If you have already added this repository, run the following command to retrieve the latest versions of the packages:
```
helm repo update
```

To list the available chart versions:
```
helm search repo <alias>
```

To view default chart values:
```
helm show values <alias>/<chart-name>
```

To install the <chart-name> chart:
```
helm upgrade --install my-<chart-name> <alias>/<chart-name>
```

To uninstall the chart:
```
helm uninstall my-<chart-name>
```

## Building-Box: cherry-pick your modules

Every module chart is standalone - install only what you need. Bundled infra
(`<dep>.enabled: true`) is for evaluation/local use; production installs point
`applicationYaml` at your own infrastructure.

| Module | Purpose | Infra (optional bundled) | Gateway routes (opt-in) | Install |
|---|---|---|---|---|
| auditflow | Audit logging | RabbitMQ | `/auditflow/api` (protected), `/auditflow/v3/api-docs` (public) | `helm install my-auditflow labs64io-pub/auditflow` |
| checkout | Checkout API | RabbitMQ, PostgreSQL | `/checkout/api` (protected), `/checkout/v3/api-docs` (public) | `helm install my-checkout labs64io-pub/checkout` |
| checkout-ui | Checkout UI | - | `/checkout` (protected) | `helm install my-checkout-ui labs64io-pub/checkout-ui` |
| payment-gateway | Payments API | RabbitMQ, PostgreSQL, Redis | `/payment-gateway/api` (protected), `/payment-gateway/v3/api-docs` (public) | `helm install my-payments labs64io-pub/payment-gateway` |
| customer-portal-ui | Customer portal | - | `/customer-portal` (protected) | `helm install my-portal labs64io-pub/customer-portal-ui` |
| gateway-common | Shared Traefik middlewares (auth, rate limit, headers) | - | n/a | `helm install gateway-common labs64io-pub/gateway-common` |
| traefik-authproxy | ForwardAuth OIDC/JWT verifier | - | n/a | `helm install authproxy labs64io-pub/traefik-authproxy` |
| swagger-ui | Swagger UI aggregator | - | `/swagger-ui` (public) | `helm install swagger-ui labs64io-pub/swagger-ui` |

Gateway integration (`gateway.enabled: true`) requires Traefik v3 CRDs plus the
`gateway-common` and `traefik-authproxy` charts; without them, use the standard
`ingress.enabled` with any ingress controller.

Local testing: `just mock-oidc-install` (dev-only M2M tokens),
`just labs64io-<module>-install`, `helm test labs64io-<module> -n labs64io`,
`just labs64io-e2e-auth`.

### Provisioning profiles

| Profile | File | Use case |
|---|---|---|
| shared local | `overrides/<module>/values.local.yaml` | dev cluster with the shared toolset (`just local-up`) |
| standalone | `overrides/<module>/values.standalone.yaml` | single-module eval with bundled infra (`just labs64io-standalone-install <module>`) |
| BYO / production | `overrides/<module>/values.prod-example.yaml` | copy & adapt: your infrastructure, credentials via `secrets.data` (ESO recommended) |

### Capability requirements (bring-your-own infrastructure)

Modules need capabilities, not specific tools:

| Module | Needs |
|---|---|
| auditflow | AMQP 0-9-1 broker |
| checkout | AMQP 0-9-1 broker; PostgreSQL (db `checkout`, login with CREATE DATABASE for first install) |
| payment-gateway | AMQP 0-9-1 broker; PostgreSQL (db `payment_gateway`); Redis |
| gateway stack | any OIDC provider supporting client_credentials; scope/role claims are configurable via `TOKEN_SCOPES_CLAIM_PATHS` (default: `scope,realm_access.roles,resource_access.{audience}.roles`) |

Reference versions (tested in CI via the bundled subcharts): RabbitMQ chart 16.0.14,
PostgreSQL chart 18.7.11, Redis chart 27.0.13. For local development, images must be
built and pushed to the local registry (`localhost:5005`) — see DEVELOPERS.md.

### Preflight: verify your infrastructure first

    helm install preflight ./charts/preflight -n labs64io --create-namespace \
      -f my-endpoints.yaml
    kubectl wait --for=condition=complete job/preflight -n labs64io --timeout=120s \
      || kubectl logs job/preflight -n labs64io --all-containers

Each enabled check (broker TCP, PostgreSQL login, Redis PING, OIDC token grant)
runs as one container; the Job succeeds only if all pass.

### Local cluster

    just local-up        # k3d cluster + pinned toolset + all modules
    just local-up-full   # + monitoring stack
    just local-down

## Observability

Observability across the ecosystem is **infrastructure-owned**: services ship no OpenTelemetry
SDK, instrumentation is injected at runtime (OTel Java Agent / `opentelemetry-instrument`), and
the whole stack is toggled per deployment with `observability.enabled` — the same image runs with
it on or off. Signals flow through an OpenTelemetry Collector to Tempo (traces), Loki
(logs), and Prometheus (metrics), unified in Grafana.

See **[OBSERVABILITY.md](OBSERVABILITY.md)** for the full model, the env-variable contract, and
how to make a new module observable.

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=Labs64/labs64.io-helm-charts&type=Date)](https://www.star-history.com/#Labs64/labs64.io-helm-charts&Date)

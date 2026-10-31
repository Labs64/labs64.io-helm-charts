# Labs64.IO :: Helm Charts

**Kubernetes charts for every Labs64.IO module, and the installer that puts them to work.**
*Part of the [Labs64.IO Ecosystem](https://labs64.io): how the whole platform, or a single module, gets onto a cluster.*

[![Labs64.IO - Helm Charts - Release Charts](https://github.com/Labs64/labs64.io-helm-charts/actions/workflows/labs64io-release-charts.yml/badge.svg)](https://github.com/Labs64/labs64.io-helm-charts/actions/workflows/labs64io-release-charts.yml)
[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/labs64io-helm-charts)](https://artifacthub.io/packages/search?repo=labs64io-helm-charts)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![📖 Documentation](https://img.shields.io/badge/📖-Documentation-AB6543.svg)](https://labs64.io/docs/getting-started/deploy-to-kubernetes.html)

<p align="center"><img src="docs/assets/helm-charts-hero.svg" alt="Helm Charts: The umbrella chart as a container ship: Traefik, AuthProxy, Cerbos and AuditFlow are on board, Checkout and Customer Portal are optional, and a crane lowers Payment Gateway into place." width="880"></p>

[**Get started**](https://labs64.io/docs/getting-started/quickstart.html) · [Features](#features) · [AI agents](#using-it-with-ai-agents) · [Ecosystem](#the-labs64io-ecosystem) · [Documentation](https://labs64.io/docs/getting-started/deploy-to-kubernetes.html) · [labs64.io](https://labs64.io)

> [!NOTE]
> `install.sh` is for evaluation: its Quickstart profile ships a demo identity provider that issues a token to anyone. For anything reachable by other people, install with your own identity provider and follow the go-live checks.

## Why Helm Charts?

Running a platform of several services means one chart per service, gateway wiring, an identity provider and a handful of backing stores, and you want to see it work before you commit a week to it. Helm Charts is how you start small and grow.

1. **One command to see it work.** `install.sh` installs the platform on any cluster and proves it with a real request.
2. **Cherry-pick modules.** Every module chart is standalone: install only what you need, and bring your own infrastructure.
3. **A path to production.** The same charts run on AWS, Azure, Google Cloud or on-premises, with a `preflight` chart to check your infrastructure first.

**A good fit if**

- You want Labs64.IO on a Kubernetes cluster, from a laptop to a managed cloud.
- You want to adopt one module at a time and bring your own database, broker and identity provider.
- You want a repeatable, scriptable install that can run unattended in CI.

**Probably not what you need if**

- You do not run Kubernetes: the Docker option in each module's README is the simpler way to evaluate a single service.
- You want a fully managed hosted offering: these charts are for running it yourself.

## Features

- **`install.sh`**: install, status, start, stop, uninstall and smoke test for the whole platform on any cluster.
- **Umbrella chart**: `labs64io-ecosystem` installs the platform together, with demo and AWS reference profiles.
- **Module charts**: `auditflow`, `payment-gateway`, `checkout`, `reporting`, `customer-portal`, `api-gateway`, `authz-pdp` and `api-docs`, each standalone.
- **Gateway API routing**: modules own their routes; Traefik is the Gateway implementation.
- **Preflight**: a one-shot job that tests your broker, database, Redis and OIDC endpoint from inside the cluster.
- **Bring your own infrastructure**: no application chart bundles RabbitMQ, PostgreSQL or Redis as a dependency.
- **Secrets your way**: plain Kubernetes Secrets, or External Secrets Operator.

## Which path is for whom

| You are… | Start with | Why |
|---|---|---|
| Evaluating, with a laptop | `install.sh` on a k3d cluster | Five minutes to a working gateway, with a smoke test |
| A platform team on a real cluster | Module charts or the umbrella chart with your own identity provider | You decide the data stores, the DNS and TLS, and the secrets |
| Adopting one module | That module's chart (`auditflow`, `payment-gateway`, …) | Every chart is standalone; infrastructure is yours |
| In CI | `LABS64_PROFILE=quickstart bash install.sh` | No prompts, and `status` and `smoke` exit non-zero on failure |

## Before you go live

- **Replace the demo identity provider.** The Quickstart profile hands out valid tokens to anyone; use the `byo` profile or your own values with your provider's discovery URL.
- **Bring real infrastructure.** Point the charts at your PostgreSQL, RabbitMQ and Redis (`global.<service>.host`) and run the `preflight` chart first to verify reachability.
- **Keep secrets out of values files.** Use Kubernetes Secrets or External Secrets Operator, and generate strong passwords.
- **Pin chart versions.** Set `LABS64_CHART_VERSION` (installer) or `--version` (Helm) so upgrades are a decision, not a surprise.

## Using it with AI agents

The installer runs unattended, so an agent or a CI job can get an environment to test against. The [guide for AI agents](https://labs64.io/docs/introduction/ai-agents.html) covers authentication, retries and errors across all modules. Working on this repository with an agent? [`AGENTS.md`](AGENTS.md) and [`CLAUDE.md`](CLAUDE.md) describe the layout, conventions and checks.

## The Labs64.IO Ecosystem

Helm Charts is one module of the [Labs64.IO Ecosystem](https://labs64.io); [every module is documented here](https://labs64.io/docs/).

| Module | What it does | Link |
|---|---|---|
| **AuditFlow** | Audit-event routing pipeline | [labs64.io-auditflow](https://github.com/Labs64/labs64.io-auditflow) |
| **API Gateway** | Authenticating, policy-enforcing edge for all modules | [labs64.io-authproxy](https://github.com/Labs64/labs64.io-authproxy) |
| **Payment Gateway** | One API over multiple payment providers | [labs64.io-payment-gateway](https://github.com/Labs64/labs64.io-payment-gateway) |
| **Checkout** | Embeddable, brandable checkout | [labs64.io-checkout](https://github.com/Labs64/labs64.io-checkout) |
| **Reporting** | Read-only reports over the events AuditFlow stored | [labs64.io-reporting](https://github.com/Labs64/labs64.io-reporting) |
| **Customer Portal** | Customer self-service UI | [labs64.io-customer-portal](https://github.com/Labs64/labs64.io-customer-portal) |
| **Commons** | Shared Java and Python libraries | [labs64.io-commons](https://github.com/Labs64/labs64.io-commons) |
| **Helm Charts** | Kubernetes deployment for every module | [labs64.io-helm-charts](https://github.com/Labs64/labs64.io-helm-charts) |
| **Workspace** | Dev container and multi-repo tooling | [labs64.io-workspace](https://github.com/Labs64/labs64.io-workspace) |
| **Tests** | Cross-module regression suite | [labs64.io-tests](https://github.com/Labs64/labs64.io-tests) |
| **Docs** | Published documentation | [labs64.io-docs](https://github.com/Labs64/labs64.io-docs) |
| **NetLicensing** | Licensing-as-a-Service: license and entitlement management | [netlicensing.io](https://netlicensing.io) |
| **GuideChimp** | Interactive guided product tours | [labs64.com/guidechimp](https://www.labs64.com/guidechimp/) |

## Contributing

We would love your help. Chart fixes and documentation improvements are very welcome, and so are reports from a cluster setup we have not tried. Fork the repository, make your change on a branch, run the checks described in [`AGENTS.md`](AGENTS.md) and open a pull request. Not sure whether an idea fits? Open an issue first and we will talk it through; that is a perfectly good way to start.

## License

Everything in this repository is open source under the [Apache License 2.0](LICENSE): you can use it, change it and ship it commercially. The core of the *Labs64.IO Ecosystem* is free forever; community modules are Apache-2.0 licensed.

---

<p align="center">
  <a href="https://labs64.io"><img alt="Labs64.IO" src="https://labs64.io/docs/assets/images/labs64-logo.png" width="110"></a><br>
  <sub>Made by the <a href="https://labs64.io">Labs64</a> team and community.</sub>
</p>

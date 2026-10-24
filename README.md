# Labs64.IO :: Helm Charts

**Kubernetes charts for every Labs64.IO module, and the installer that puts them to work.**
*Part of the [Labs64.IO Ecosystem](https://labs64.io): how the whole platform, or a single module, gets onto a cluster.*

[![Labs64.IO - Helm Charts - Release Charts](https://github.com/Labs64/labs64.io-helm-charts/actions/workflows/labs64io-release-charts.yml/badge.svg)](https://github.com/Labs64/labs64.io-helm-charts/actions/workflows/labs64io-release-charts.yml)
[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/labs64io-helm-charts)](https://artifacthub.io/packages/search?repo=labs64io-helm-charts)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![📖 Documentation](https://img.shields.io/badge/📖-Documentation-AB6543.svg)](https://labs64.io/docs/getting-started/deploy-to-kubernetes.html)

<p align="center"><img src="docs/assets/helm-charts-hero.svg" alt="Helm Charts: The umbrella chart as a container ship: Traefik, AuthProxy, Cerbos and AuditFlow are on board, Checkout and Customer Portal are optional, and a crane lowers Payment Gateway into place." width="880"></p>

[Why Helm Charts?](#why-helm-charts) · [Documentation](https://labs64.io/docs/getting-started/deploy-to-kubernetes.html) · [Build and test](#build-and-test) · [Ecosystem](#the-labs64io-ecosystem) · [labs64.io](https://labs64.io)

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

## Documentation

Install, configure and operate Helm Charts in the **[Helm Charts documentation](https://labs64.io/docs/getting-started/deploy-to-kubernetes.html)**.

[Quickstart](https://labs64.io/docs/getting-started/quickstart.html) · [Choose a deployment path](https://labs64.io/docs/getting-started/choose-a-deployment-path.html)

New to Labs64.IO? The [Quickstart](https://labs64.io/docs/getting-started/quickstart.html) puts the platform on any Kubernetes cluster in about five minutes with one script.

## Build and test

```bash
just ci                       # what the pull-request check runs: run it before pushing
just up                       # k3d cluster, registry and all modules
just down                     # delete the k3d cluster
helm dependency build charts/auditflow && helm lint charts/auditflow
```

Needs Helm 4, Git, and Docker with k3d for the local cluster. [`DEVELOPERS.md`](DEVELOPERS.md) and [`docs/reference.md`](docs/reference.md) cover the layout and every chart. Working on the code with an AI agent? [`AGENTS.md`](AGENTS.md) and [`CLAUDE.md`](CLAUDE.md) describe the layout, conventions and checks.

## The Labs64.IO Ecosystem

This repository is part of the [Labs64.IO Ecosystem](https://labs64.io): open-source building blocks for secure commerce platforms. Every module is documented at [labs64.io/docs](https://labs64.io/docs/).

| Module | What it does |
|---|---|
| [**AuditFlow**](https://github.com/Labs64/labs64.io-auditflow) | Publish once, route anywhere, lose nothing |
| [**Auth Gateway**](https://github.com/Labs64/labs64.io-authproxy) | One authenticated edge for every module |
| [**Payment Gateway**](https://github.com/Labs64/labs64.io-payment-gateway) | One API across multiple payment providers |
| [**Checkout**](https://github.com/Labs64/labs64.io-checkout) | Whitelabel checkout and order workflow |
| [**Customer Portal**](https://github.com/Labs64/labs64.io-customer-portal) | Self-service portal for your customers |

Built on [Commons](https://github.com/Labs64/labs64.io-commons), deployed with [Helm Charts](https://github.com/Labs64/labs64.io-helm-charts), developed in the [Workspace](https://github.com/Labs64/labs64.io-workspace), verified by [Tests](https://github.com/Labs64/labs64.io-tests) and documented in [Docs](https://github.com/Labs64/labs64.io-docs). Also from Labs64: [NetLicensing](https://netlicensing.io) for licensing-as-a-service and [GuideChimp](https://www.labs64.com/guidechimp/) for guided product tours.

## Contributing

We would love your help. Chart fixes and documentation improvements are very welcome, and so are reports from a cluster setup we have not tried. Fork the repository, make your change on a branch, run the checks described in [`AGENTS.md`](AGENTS.md) and open a pull request. Not sure whether an idea fits? Open an issue first.

## License

Open source under the [Apache License 2.0](LICENSE): use it, change it and ship it commercially.

---

<p align="center">
  <a href="https://labs64.io"><img alt="Labs64.IO" src="https://labs64.io/docs/assets/images/labs64-logo.png" width="110"></a><br>
  <sub>Made by the <a href="https://labs64.io">Labs64</a> team and community.</sub>
</p>

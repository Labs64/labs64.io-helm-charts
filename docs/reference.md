# Helm Charts reference

For everything else, see [Kubernetes & Helm setup](https://labs64.io/docs/operate-manage/kubernetes-helm-setup.html) and [Deploy to Kubernetes](https://labs64.io/docs/getting-started/deploy-to-kubernetes.html).

Reference versions: the shared local toolset (`just install-tools`) runs exactly the chart
versions pinned in `helmfile.yaml.gotmpl` — the single place they are written; print one with
`just show-chart-version postgresql` (or `redis`, `traefik`, …). RabbitMQ is the official image via
`overrides/rabbitmq/chart`. For local development, images must be built and pushed to the local
registry (`localhost:5005`) — see DEVELOPERS.md.

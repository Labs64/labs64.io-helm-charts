# Group `local stack` (docs/justfiles.md in labs64.io-workspace). Imported by the justfile.

# Create the local k3d cluster and registry, or start them again if they are stopped
[group('local stack')]
start-cluster:
    k3d cluster list labs64io >/dev/null 2>&1 && k3d cluster start labs64io || k3d cluster create --config k3d/labs64io.yaml
    k3d kubeconfig merge -d labs64io
    if [ -f /.dockerenv ]; then perl -i -pe 's/server: https:\/\/0\.0\.0\.0/server: https:\/\/host.docker.internal/g' ~/.kube/config; fi
    if [ -f /.dockerenv ]; then perl -i -pe 's/server: https:\/\/127\.0\.0\.1/server: https:\/\/host.docker.internal/g' ~/.kube/config; fi

# Start the local k3d cluster and deploy the stack from the Helm overrides
[group('local stack')]
up: generate-secrets start-cluster
    just deploy

# Reconcile tools, the selected identity provider, and all applications.
# The workspace-level `just up` calls this after building first-party images.
#
# Install the core tools, the selected identity provider and all applications
[group('local stack')]
deploy:
    just update-repos
    just install-tools
    just install-apps
    @echo "Local environment ready: http://gateway.localhost/swagger-ui/"

# Start the local environment with the monitoring stack and module telemetry enabled
[group('local stack')]
up-otel: up install-monitoring enable-observability

# Uninstall all apps, monitoring and tools but keep the cluster
[group('local stack')]
reset: uninstall-apps uninstall-monitoring uninstall-tools

# Reset the environment, then delete the local k3d cluster and its registry
[group('local stack')]
down: reset
    k3d cluster delete labs64io

# enable OTel instrumentation on instrumented module apps (requires the monitoring
# stack — the collector DaemonSet must be running so OTLP export has a target).
# Kept off in the base `up` profile so a monitoring-less cluster shows no export errors.
# Which apps are instrumented is declared in helmfile.yaml.gotmpl (label
# `observability: "true"`); every apply below passes the same switch, so neither
# `install-app` nor `install-apps` can silently drop telemetry afterwards.
#
# Turn on OpenTelemetry instrumentation for the instrumented module apps
[group('local stack')]
enable-observability:
    helmfile -e {{ENV}} --state-values-set observability.enabled=true apply -l observability=true

# Helmfile state flag that follows the monitoring stack: observability is on exactly when
# the OTel collector is running.
#
# Print the Helmfile flag that enables observability when the OTel collector is running
[private]
_observability-args:
    #!/usr/bin/env bash
    if kubectl get daemonset opentelemetry-collector-agent -n {{NAMESPACE_MONITORING}} >/dev/null 2>&1; then
        echo "--state-values-set observability.enabled=true"
    fi

# uninstall every release of a helmfile layer (infra | identity | monitoring | apps),
# whether or not the current overrides still select it
#
# Uninstall every release of a Helmfile layer, even if the overrides no longer select it
[private]
_uninstall-layer layer:
    #!/usr/bin/env bash
    set -euo pipefail
    helmfile -e {{ENV}} list --output json 2>/dev/null \
        | jq -r --arg layer "layer:{{layer}}" '.[] | select(.labels | split(",") | index($layer)) | "\(.name) \(.namespace)"' \
        | while read -r name namespace; do
            helm uninstall "$name" --namespace "$namespace" 2>/dev/null || true
        done

# Show pods, services and ingresses in the apps, tools and monitoring namespaces
[group('local stack')]
status:
    @echo "\n=== Labs64.IO Apps ==="
    @kubectl get pods,svc,ingress -n {{NAMESPACE_LABS64IO}}
    @echo "\n=== Tools ==="
    @kubectl get pods,svc,ingress -n {{NAMESPACE_TOOLS}}
    @echo "\n=== Monitoring ==="
    @kubectl get pods,svc,ingress -n {{NAMESPACE_MONITORING}}

# Without an app: the warnings and errors of every Labs64.IO pod, once.
#
# Follow the logs of one app, or show the warnings and errors of all of them
[group('local stack')]
logs app="":
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -n "{{app}}" ]; then
        kubectl logs -f -n {{NAMESPACE_LABS64IO}} -l app.kubernetes.io/name={{app}}
    else
        kubectl --namespace {{NAMESPACE_LABS64IO}} logs -l app.kubernetes.io/part-of=Labs64.IO | grep -E 'WARN|ERROR|FATAL|FAILURE|FAILED' || true
    fi

# Delete all persistent volume claims in the apps, tools and monitoring namespaces
[group('local stack')]
delete-pvcs:
    kubectl delete pvc --all -n {{NAMESPACE_LABS64IO}} || true
    kubectl delete pvc --all -n {{NAMESPACE_TOOLS}} || true
    kubectl delete pvc --all -n {{NAMESPACE_MONITORING}} || true

# Open the Swagger UI of the local gateway in the browser
[group('local stack')]
open-swagger:
    open "http://gateway.localhost/swagger-ui/"

# Open the Traefik dashboard in the browser
[group('local stack')]
open-traefik:
    open "http://dashboard.localhost/dashboard/"

# Print the Grafana password and open Grafana in the browser
[group('local stack')]
open-grafana:
    @just show-grafana-password
    @echo "Opening Grafana... (Press Ctrl+C to quit)"
    open http://gateway.localhost/grafana/ || echo "Visit http://gateway.localhost/grafana/"

# Prune unused Docker data, including volumes, without asking for confirmation
[group('local stack')]
prune-docker:
    docker system prune -a --volumes -f

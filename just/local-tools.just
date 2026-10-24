# Group `local tools` (docs/justfiles.md in labs64.io-workspace). Imported by the justfile.

# Install the core tools and the identity provider selected in the overrides
[group('local tools')]
install-tools: install-crds
    # traefik is applied separately with --skip-crds: its chart bundles its own copy of
    # the Traefik CRDs, which can now drift ahead of the traefik-crds chart pinned in
    # install-crds (e.g. a middlewares CRD field newer than TRAEFIK_CRDS_CHART_VERSION).
    # Helm's own CRD installer applies its bundled copy via server-side apply, which then
    # conflicts with the field manager from install-crds' `kubectl apply --server-side`
    # instead of the plain create-skip-if-exists this was designed around. Since helmfile
    # has no per-release skip-crds (only the global apply flag), traefik is selected out
    # of the blanket apply below and given its own --skip-crds run — the other layer=infra
    # charts (e.g. external-secrets) still need normal CRD install.
    helmfile -e {{ENV}} apply -l layer=infra,name!=traefik
    helmfile -e {{ENV}} apply -l name=traefik --skip-crds
    kubectl apply -f overrides/traefik/dashboard-httproute.yaml
    # The ClusterSecretStore goes through ESO's validating webhook — wait for it to be
    # ready first, since `helmfile apply` above returns as soon as objects are applied,
    # not once the webhook deployment is actually serving.
    kubectl -n {{NAMESPACE_TOOLS}} wait --for=condition=available --timeout=120s deployment/external-secrets-webhook
    kubectl apply -f overrides/eso/cluster-secret-store.yaml
    just migrate-legacy-mock-oidc
    helmfile -e {{ENV}} apply -l layer=identity

# Uninstall all core tools (identity providers included, whichever is selected)
[group('local tools')]
uninstall-tools: (_uninstall-layer "identity")
    kubectl delete -f overrides/eso/cluster-secret-store.yaml --ignore-not-found
    just _uninstall-layer infra
    kubectl delete pvc -l app=rabbitmq --namespace {{NAMESPACE_TOOLS}} --ignore-not-found

# Install the Gateway API (standard channel) + Traefik CRDs before the `traefik` Helm
# release (Helmfile's release schema has no per-release skip-crds equivalent, and Helm
# never upgrades CRDs bundled in a chart's crds/ directory after first install — so these
# are managed here as an independently-versioned, re-appliable step. Helm/Helmfile only
# install a chart's bundled CRDs "if not already present", so pre-seeding them here means
# the `traefik` release's own bundled copies are simply skipped, no conflict).
#
# Install the Gateway API and Traefik CRDs ahead of the Traefik release
[group('local tools')]
install-crds:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Installing Gateway API (standard channel) CRDs..."
    kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/{{GATEWAY_API_VERSION}}/standard-install.yaml
    echo "Installing Traefik CRDs..."
    helm template traefik-crds traefik/traefik-crds --version {{TRAEFIK_CRDS_CHART_VERSION}} --namespace {{NAMESPACE_TOOLS}} | kubectl apply --server-side -f -

# (Re)install one core or monitoring tool exactly as `install-tools` / `install-monitoring`
# would — same chart version, same values, straight from helmfile.yaml.gotmpl:
# `just install-tool postgresql`, `just install-tool redis`, … (names: `helmfile -e local list`).
# Five need more than their release, and get it here too: traefik (its CRDs first), opentelemetry
# (the collector config validated first), grafana (its route and dashboards), mock-oidc and keycloak
# (only the identity provider the overrides select). The monitoring CRDs come with install-monitoring.
#
# Install or reinstall one core or monitoring tool exactly as install-tools and install-monitoring would
[group('local tools')]
install-tool name:
    #!/usr/bin/env bash
    set -euo pipefail
    case "{{name}}" in
        traefik|grafana|mock-oidc|keycloak) just _install-tool-{{name}} ;;
        opentelemetry|opentelemetry-collector) just _install-tool-opentelemetry ;;
        *) helmfile -e {{ENV}} apply -l name={{name}} ;;
    esac

# Uninstall one core or monitoring tool by its Helmfile release name
[group('local tools')]
uninstall-tool name:
    #!/usr/bin/env bash
    set -euo pipefail
    namespace="$(helmfile -e {{ENV}} list --output json 2>/dev/null \
        | jq -r --arg name "{{name}}" '.[] | select(.name == $name) | .namespace')"
    [ -n "$namespace" ] || { echo "no helmfile release named '{{name}}'" >&2; exit 1; }
    helm uninstall "{{name}}" --namespace "$namespace" || true

# Install the Traefik CRDs, then the Traefik release without its bundled CRDs
[private]
_install-tool-traefik: install-crds
    helmfile -e {{ENV}} apply -l name=traefik --skip-crds
    kubectl apply -f overrides/traefik/dashboard-httproute.yaml

# Print the identity provider selected in overrides/helmfile/values.<env>.yaml
[group('local tools')]
show-identity-provider:
    @sed -n -E 's/^identityProvider:[[:space:]]*([a-z]+).*/\1/p' overrides/helmfile/values.{{ENV}}.yaml | grep . || echo mock

# One-time migration for clusters created before mock-oidc became a Helm release: it used to be
# applied as raw manifests (overrides/mock-oidc/mock-oidc.yaml, removed), and Helm refuses to adopt
# objects it does not own ("exists and cannot be imported into the current release"). Deletes only
# those four legacy objects, and only when the Deployment carries no Helm ownership annotation;
# Helmfile then recreates them as the `mock-oidc` release. No-op on every other cluster.
#
# Remove the legacy raw mock-oidc objects so Helm can take them over (one-time migration)
[group('local tools')]
migrate-legacy-mock-oidc:
    #!/usr/bin/env bash
    set -euo pipefail
    kubectl -n {{NAMESPACE_TOOLS}} get deployment mock-oidc >/dev/null 2>&1 || exit 0
    owner=$(kubectl -n {{NAMESPACE_TOOLS}} get deployment mock-oidc -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-name}')
    [ -z "$owner" ] || exit 0
    echo "Migrating legacy raw-manifest mock-oidc to a Helm release..."
    kubectl -n {{NAMESPACE_TOOLS}} delete httproute/mock-oidc service/mock-oidc deployment/mock-oidc configmap/mock-oidc-config --ignore-not-found

# Install mock OIDC only when it is the provider selected by the environment overrides.
# Provider switching remains declarative: this recipe never edits values files itself.
#
# Install mock OIDC if it is the identity provider selected in the overrides
[private]
_install-tool-mock-oidc: migrate-legacy-mock-oidc
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "$(just show-identity-provider)" != "mock" ]; then
        echo "identityProvider is not 'mock' in overrides/helmfile/values.{{ENV}}.yaml" >&2
        exit 1
    fi
    helmfile -e {{ENV}} apply -l layer=identity

# Install Keycloak only when it is the provider selected by the environment overrides.
#
# Install Keycloak if it is the identity provider selected in the overrides
[private]
_install-tool-keycloak:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "$(just show-identity-provider)" != "keycloak" ]; then
        echo "identityProvider is not 'keycloak' in overrides/helmfile/values.{{ENV}}.yaml" >&2
        exit 1
    fi
    helmfile -e {{ENV}} apply -l layer=identity

# Install all monitoring tools
[group('local tools')]
install-monitoring: install-monitoring-crds
    helmfile -e {{ENV}} apply -l layer=monitoring
    kubectl apply -f overrides/grafana/grafana-httproute.yaml
    kubectl apply -f overrides/grafana/grafana-dashboards.yaml

# Pre-install kube-prometheus-stack's CRDs (Prometheus/PrometheusRule/ServiceMonitor/etc.).
# Helm only applies a chart's bundled crds/ during actual install/upgrade, but helmfile's
# helm-diff plugin renders+diffs first (even for a brand-new release) and needs those types
# already registered to resolve REST mappings — without this, `install-monitoring` fails with
# "no matches for kind Prometheus/PrometheusRule/ServiceMonitor in version monitoring.coreos.com/v1"
# on a fresh cluster. Mirrors the Traefik/Gateway API CRD pre-install in `install-crds`.
#
# Install the kube-prometheus-stack CRDs ahead of the monitoring release
[group('local tools')]
install-monitoring-crds:
    helm show crds prometheus-community/kube-prometheus-stack --version "$(just show-chart-version prometheus)" | kubectl apply --server-side -f -

# Uninstall all monitoring tools
[group('local tools')]
uninstall-monitoring: (_uninstall-layer "monitoring")

# Install the OpenTelemetry collector after validating the collector config
[private]
_install-tool-opentelemetry: check-otel-config
    helmfile -e {{ENV}} apply -l name=opentelemetry-collector

# Install Grafana with its route and dashboards
[private]
_install-tool-grafana:
    helmfile -e {{ENV}} apply -l name=grafana
    kubectl apply -f overrides/grafana/grafana-httproute.yaml
    kubectl apply -f overrides/grafana/grafana-dashboards.yaml

# Print the Grafana admin password
[group('local tools')]
show-grafana-password:
    @echo "Password: " && kubectl get secret --namespace {{NAMESPACE_MONITORING}} grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

# generate an M2M JWT from the selected identity provider (identityProvider).
# mock: pass a persona (admin|auditflow|ecommerce|no-access) for a curated scope set, or ANY exact
# scope string(s) to mint a token carrying precisely those scopes, e.g.
# `just generate-jwt audit-event:read` (echoed verbatim into the token).
# keycloak: a persona selects the realm client whose role grants that scope set (arbitrary scope
# strings are not a thing a real IdP does).
#
# Request an M2M JWT from the selected identity provider
[group('local tools')]
generate-jwt scope="admin":
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "$(just show-identity-provider)" = "keycloak" ]; then
        case "{{scope}}" in
            admin) CLIENT=local-tooling; KEY=LOCAL_TOOLING_CLIENT_SECRET ;;
            auditflow) CLIENT=auditflow; KEY=AUDITFLOW_CLIENT_SECRET ;;
            ecommerce) CLIENT=payment-gateway; KEY=PAYMENT_GATEWAY_CLIENT_SECRET ;;
            no-access) CLIENT=preflight; KEY=PREFLIGHT_CLIENT_SECRET ;;
            *) echo "keycloak: persona must be admin|auditflow|ecommerce|no-access" >&2; exit 1 ;;
        esac
        SECRET=$(sed -n -E "s/^[[:space:]]*${KEY}:[[:space:]]*\"?([^\"]*)\"?[[:space:]]*$/\1/p" overrides/keycloak/values.secrets.{{ENV}}.yaml)
        curl -s -X POST 'http://keycloak.localhost/realms/labs64io/protocol/openid-connect/token' \
          --data-urlencode 'grant_type=client_credentials' \
          --data-urlencode "client_id=$CLIENT" \
          --data-urlencode "client_secret=$SECRET" | jq .
    else
        curl -s -X POST 'http://mock-oidc.localhost/labs64io/token' \
          -H 'Content-Type: application/x-www-form-urlencoded' \
          --data-urlencode 'grant_type=client_credentials' \
          --data-urlencode 'client_id=local-test' \
          --data-urlencode 'client_secret=local-test' \
          --data-urlencode 'scope={{scope}}' | jq .
    fi

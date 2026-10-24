# Recipes that were renamed. Each old name fails and names its replacement, so muscle memory and old scripts
# get a clear message instead of a different behaviour (docs/justfiles.md in labs64.io-workspace).
# Remove this file after 2027-01-31.

# Fail with the new name of a renamed recipe
[private]
_renamed old +new:
    @echo 'error: `just {{old}}` is now `just {{new}}` (see just/renamed.just).' >&2 && exit 1

[private]
build-policies *args:
    @just _renamed build-policies generate-policies

[private]
chart-version *args:
    @just _renamed chart-version show-chart-version

[private]
clean-pvcs *args:
    @just _renamed clean-pvcs delete-pvcs

[private]
cluster-down *args:
    @just _renamed cluster-down down

[private]
cluster-up *args:
    @just _renamed cluster-up start-cluster

[private]
diff *args:
    @just _renamed diff diff-app

[private]
docker-system-prune *args:
    @just _renamed docker-system-prune prune-docker

[private]
docs *args:
    @just _renamed docs open-swagger

[private]
generate-docu *args:
    @just _renamed generate-docu generate-docs

[private]
grafana *args:
    @just _renamed grafana open-grafana

[private]
grafana-password *args:
    @just _renamed grafana-password show-grafana-password

[private]
helm-tools *args:
    @just _renamed helm-tools install-helm-plugins

[private]
identity-provider *args:
    @just _renamed identity-provider show-identity-provider

[private]
install-all-apps *args:
    @just _renamed install-all-apps install-apps

[private]
install-tool-grafana *args:
    @just _renamed install-tool-grafana install-tool grafana

[private]
install-tool-keycloak *args:
    @just _renamed install-tool-keycloak install-tool keycloak

[private]
install-tool-mock-oidc *args:
    @just _renamed install-tool-mock-oidc install-tool mock-oidc

[private]
install-tool-opentelemetry *args:
    @just _renamed install-tool-opentelemetry install-tool opentelemetry

[private]
install-tool-traefik *args:
    @just _renamed install-tool-traefik install-tool traefik

[private]
lint-all *args:
    @just _renamed lint-all lint-charts

[private]
logs-errors *args:
    @just _renamed logs-errors logs

[private]
payment-gateway-psp-stub-disable *args:
    @just _renamed payment-gateway-psp-stub-disable disable-payment-gateway-stub

[private]
payment-gateway-psp-stub-enable *args:
    @just _renamed payment-gateway-psp-stub-enable enable-payment-gateway-stub

[private]
repo-add *args:
    @just _renamed repo-add update-repos

[private]
repo-update *args:
    @just _renamed repo-update update-repos

[private]
restart *args:
    @just _renamed restart restart-app

[private]
template *args:
    @just _renamed template template-app

[private]
template-all *args:
    @just _renamed template-all check-templates

[private]
test-check-bumps *args:
    @just _renamed test-check-bumps test

[private]
test-check-package *args:
    @just _renamed test-check-package test

[private]
test-lint-authoring *args:
    @just _renamed test-lint-authoring test

[private]
test-lint-secrets *args:
    @just _renamed test-lint-secrets test

[private]
test-update-chart-images *args:
    @just _renamed test-update-chart-images test

[private]
traefik-dashboard *args:
    @just _renamed traefik-dashboard open-traefik

[private]
uninstall-all-apps *args:
    @just _renamed uninstall-all-apps uninstall-apps

[private]
validate-otel-config *args:
    @just _renamed validate-otel-config check-otel-config

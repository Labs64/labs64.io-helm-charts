# Group `local apps` (docs/justfiles.md in labs64.io-workspace). Imported by the justfile.

# Install all Labs64.IO apps
[group('local apps')]
install-apps:
    helmfile -e {{ENV}} $(just _observability-args) apply -l layer=apps

# Uninstall all Labs64.IO apps
[group('local apps')]
uninstall-apps: (_uninstall-layer "apps")

# Install a specific Labs64.IO application — the same helmfile release `install-apps`
# applies (chart values, global values, per-env override, secrets, identity provider),
# optionally with one more values file layered on top
#
# Install one Labs64.IO app the way install-apps does, optionally with an extra values file
[group('local apps')]
install-app app extra_values="":
    #!/usr/bin/env bash
    set -euo pipefail
    echo "=== Installing Labs64.IO App: {{app}} ==="
    ARGS=()
    extra_values="{{extra_values}}"
    if [ -n "$extra_values" ]; then
      if [ ! -f "$extra_values" ]; then
        echo "Additional values file not found: $extra_values" >&2
        exit 1
      fi
      echo "Using additional override: $extra_values"
      ARGS+=("--values" "$extra_values")
    fi
    STATE_ARGS=()
    if [ "{{app}}" = "checkout" ]; then
      # Not GA, so not in the default set (helmfile.yaml.gotmpl); asking for it by name installs it.
      STATE_ARGS+=("--state-values-set" "installCheckout=true")
    fi
    helmfile -e {{ENV}} $(just _observability-args) "${STATE_ARGS[@]}" apply -l name=labs64io-{{app}} "${ARGS[@]}"

# Point only the existing local Payment Gateway deployment at the host-side PSP stub.
# The extra values file deep-merges provider-owned Spring configuration and rolls the PG pod.
#
# Point the local Payment Gateway at the host-side PSP stub and roll its pod
[group('local apps')]
enable-payment-gateway-stub host_cidr stub_url:
    helm upgrade labs64io-payment-gateway ./charts/payment-gateway \
      --namespace {{NAMESPACE_LABS64IO}} \
      --reuse-values \
      -f ./overrides/payment-gateway/values.psp-stub.local.yaml \
      --set-string 'applicationYaml.payment-provider.stripe.api-base-url={{stub_url}}' \
      --set-string 'applicationYaml.payment-provider.paypal.api-base-url={{stub_url}}' \
      --set-string 'networkPolicy.extraEgress[0].to[0].ipBlock.cidr={{host_cidr}}' \
      --set-string 'networkPolicy.extraEgress[0].ports[0].protocol=TCP' \
      --set 'networkPolicy.extraEgress[0].ports[0].port=8090' \
      --force-conflicts
    # Rollout health is the setup gate. The selected PSP Robot scenarios then prove that both
    # SDK clients actually use this endpoint by making black-box calls that WireMock verifies;
    # startup-log text is diagnostic output, not a stable configuration contract.
    kubectl rollout status deployment/labs64io-payment-gateway --namespace {{NAMESPACE_LABS64IO}} --timeout=180s

# Restore the default Payment Gateway values with the official PSP endpoints
[group('local apps')]
disable-payment-gateway-stub:
    just install-app payment-gateway
    kubectl rollout status deployment/labs64io-payment-gateway --namespace {{NAMESPACE_LABS64IO}} --timeout=180s

# Uninstall a specific Labs64.IO application
[group('local apps')]
uninstall-app app:
    helm uninstall labs64io-{{app}} --namespace {{NAMESPACE_LABS64IO}} || true

# Render one application exactly as Helmfile would install it, with all value layers
[group('local apps')]
template-app app:
    helmfile -e {{ENV}} $(just _observability-args) template -l name=labs64io-{{app}}

# Show the diff between one application and the cluster, as Helmfile would apply it
[group('local apps')]
diff-app app:
    helmfile -e {{ENV}} $(just _observability-args) diff -l name=labs64io-{{app}}

# Run helm test for one application
[group('local apps')]
test-app app:
    helm test labs64io-{{app}} --namespace {{NAMESPACE_LABS64IO}}

# Restart one application with a rollout restart
[group('local apps')]
restart-app app:
    kubectl rollout restart deployment labs64io-{{app}} -n {{NAMESPACE_LABS64IO}}

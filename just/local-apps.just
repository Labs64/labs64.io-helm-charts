# Group `local apps` (docs/justfiles.md in labs64.io-workspace). Imported by the justfile.

# Install all Labs64.IO apps (and keep an already installed checkout or reporting in step)
[group('local apps')]
install-apps: _pod-security
    helmfile -e {{ENV}} $(just _observability-args) $(just _optional-app-args) apply -l layer=apps

# Checkout and Reporting are not in the default set (helmfile.yaml.gotmpl). Once installed they
# stay selected: every apply passes their state value, so install-apps keeps them current and the
# Swagger UI (api-docs) keeps listing exactly the APIs that are installed.
#
# Print the Helmfile flags that keep the installed optional apps (checkout, reporting) selected
[private]
_optional-app-args:
    #!/usr/bin/env bash
    for app in checkout reporting; do
        if helm status "labs64io-${app}" --namespace {{NAMESPACE_LABS64IO}} >/dev/null 2>&1; then
            echo "--state-values-set install${app^}=true"
        fi
    done

# Uninstall all Labs64.IO apps
[group('local apps')]
uninstall-apps: (_uninstall-layer "apps")

# Install a specific Labs64.IO application — the same helmfile release `install-apps`
# applies (chart values, global values, per-env override, secrets, identity provider),
# optionally with one more values file layered on top
#
# Install one Labs64.IO app the way install-apps does, optionally with an extra values file
[group('local apps')]
install-app app extra_values="": _pod-security
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
    # Optional apps already installed stay selected (see _optional-app-args).
    read -r -a STATE_ARGS <<< "$(just _optional-app-args | tr '\n' ' ')"
    if [ "{{app}}" = "checkout" ]; then
      # Not GA, so not in the default set (helmfile.yaml.gotmpl); asking for it by name installs it.
      STATE_ARGS+=("--state-values-set" "installCheckout=true")
    fi
    if [ "{{app}}" = "reporting" ]; then
      # Needs a ClickHouse, so not in the default set either (helmfile.yaml.gotmpl).
      STATE_ARGS+=("--state-values-set" "installReporting=true")
    fi
    helmfile -e {{ENV}} $(just _observability-args) ${STATE_ARGS[@]+"${STATE_ARGS[@]}"} apply -l name=labs64io-{{app}} ${ARGS[@]+"${ARGS[@]}"}
    if [ "{{app}}" = "checkout" ] || [ "{{app}}" = "reporting" ]; then
      # The Swagger UI lists an API only while its module is installed. Applied on its own, so an
      # extra values file meant for {{app}} never reaches api-docs.
      helmfile -e {{ENV}} $(just _observability-args) ${STATE_ARGS[@]+"${STATE_ARGS[@]}"} apply -l name=labs64io-api-docs
    fi

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
    # Drop the API from the Swagger UI list again (see install-app).
    if [ "{{app}}" = "checkout" ] || [ "{{app}}" = "reporting" ]; then helmfile -e {{ENV}} $(just _observability-args) $(just _optional-app-args) apply -l name=labs64io-api-docs; fi

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

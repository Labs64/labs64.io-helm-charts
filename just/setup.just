# Group `setup` (docs/justfiles.md in labs64.io-workspace). Imported by the justfile.

# Create missing local secret files from their .example templates
[group('setup')]
generate-secrets:
    #!/usr/bin/env bash
    set -euo pipefail
    for dir in overrides/*/; do
        if [ -f "${dir}values.secrets.local.yaml.example" ] && [ ! -f "${dir}values.secrets.local.yaml" ]; then
            cp "${dir}values.secrets.local.yaml.example" "${dir}values.secrets.local.yaml"
            echo "Generated ${dir}values.secrets.local.yaml"
        fi
    done

# Install the Helm plugins at the versions pinned in tool-versions.env
[group('setup')]
install-helm-plugins:
    #!/usr/bin/env bash
    set -euo pipefail
    : "${HELM_DIFF_VERSION:?not set — check out labs64.io-workspace next to this repo (tool-versions.env)}"
    : "${HELM_SCHEMA_VERSION:?not set — check out labs64.io-workspace next to this repo (tool-versions.env)}"
    helm plugin install --verify=false https://github.com/databus23/helm-diff --version "v${HELM_DIFF_VERSION}" 2>/dev/null || true
    helm plugin install --verify=false https://github.com/dadav/helm-schema --version "${HELM_SCHEMA_VERSION}" 2>/dev/null || true
    echo "Installed Helm plugins:"
    helm plugin list

# add + refresh exactly the helm repositories helmfile.yaml.gotmpl declares
#
# Deliberately not a bare `helm repo update`, which updates EVERY repo in the caller's
# local helm config and fails the whole command if any one is unreachable: a stale
# entry left over in a developer's config was enough to abort `just up`. `helmfile repos`
# runs `helm repo add --force-update` for the declared repositories only.
#
# Add and refresh only the Helm repositories declared in helmfile.yaml.gotmpl
[group('setup')]
update-repos:
    helmfile -e {{ENV}} repos

# Each tool must be on the PATH; where labs64.io-workspace/tool-versions.env pins a version (it is loaded as the
# dotenv file of this justfile), a different one is reported, not failed. `just doctor` in the workspace checks the
# whole ecosystem's tools.
#
# Check the tools this repository's recipes use and their versions
[group('setup')]
doctor:
    #!/usr/bin/env bash
    set -uo pipefail
    missing=0
    check() { # name, command, pinned version or "", version command...
        local name=$1 cmd=$2 want=$3 have
        if ! command -v "$cmd" >/dev/null 2>&1; then echo "❌ $name: not installed"; missing=$((missing + 1)); return; fi
        have="$("${@:4}" 2>&1 || true)"; have="${have%%$'\n'*}"
        if [ -n "$want" ] && [[ "$have" != *"$want"* ]]; then echo "⚠️  $name: $have (tool-versions.env pins $want)"; else echo "✅ $name: $have"; fi
    }
    check helm      helm      "${HELM_VERSION:+v$HELM_VERSION}"   helm version --short
    check helmfile  helmfile  "${HELMFILE_VERSION:-}"             helmfile --version
    check k3d       k3d       "${K3D_VERSION:+v$K3D_VERSION}"     k3d --version
    check kubectl   kubectl   ""                                  kubectl version --client
    check docker    docker    ""                                  docker --version
    check jq        jq        ""                                  jq --version
    check python3   python3   ""                                  python3 --version
    if python3 -c 'import yaml, pytest' 2>/dev/null; then echo "✅ python3 modules: pyyaml, pytest"; else echo "❌ python3 modules: pip install pyyaml pytest"; missing=$((missing + 1)); fi
    for plugin in diff schema; do
        if helm plugin list 2>/dev/null | awk '{print $1}' | grep -qx "$plugin"; then echo "✅ helm-$plugin plugin"; else echo "❌ helm-$plugin plugin: just install-helm-plugins"; missing=$((missing + 1)); fi
    done
    [ -f ../labs64.io-workspace/tool-versions.env ] || echo "(labs64.io-workspace is not cloned next to this repository: versions are not compared)"
    [ "$missing" -eq 0 ]

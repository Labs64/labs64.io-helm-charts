# Group `charts` (docs/justfiles.md in labs64.io-workspace). Imported by the justfile.

# Print the chart version that helmfile.yaml.gotmpl pins for a release
[group('charts')]
show-chart-version release:
    #!/usr/bin/env bash
    set -euo pipefail
    version="$(helmfile -e {{ENV}} list --output json 2>/dev/null \
        | jq -r --arg name "{{release}}" '.[] | select(.name == $name) | .version')"
    if [ -z "$version" ] || [ "$version" = "null" ]; then
        echo "helmfile.yaml.gotmpl pins no chart version for release '{{release}}'" >&2
        exit 1
    fi
    echo "$version"

# Generate Helm chart documentation (README.md) for all charts. Uses a local `helm-docs` binary
# when it is the pinned version (the dev container installs it), else the pinned Docker image —
# which cannot work inside the dev container, where Docker resolves bind-mount paths on the host.
#
# Generate the README.md documentation for all Helm charts
[group('charts')]
generate-docs:
    #!/usr/bin/env bash
    set -euo pipefail
    : "${HELM_DOCS_VERSION:?not set — check out labs64.io-workspace next to this repo (tool-versions.env)}"
    if command -v helm-docs >/dev/null 2>&1 && [ "$(helm-docs --version | awk '{print $NF}')" = "${HELM_DOCS_VERSION}" ]; then
        helm-docs --chart-search-root ./charts --log-level warning
    else
        docker run --rm \
            --volume "$(pwd):/helm-docs" \
            --user "$(id -u):$(id -g)" \
            "jnorwood/helm-docs:v${HELM_DOCS_VERSION}" \
            --chart-search-root ./charts \
            --log-level warning
    fi

# Generate Helm values schema (values.schema.json) for all charts
#
# helm-schema exits non-zero when it cannot parse a *vendored subchart's* own
# @schema comments: Traefik's values.yaml uses a single-line
# `@schema type: [boolean, null]` form its parser rejects. It still writes every
# schema in this repo correctly, so the run is judged by its output rather than its
# exit code — fail only when a chart ends up without a schema. (--dependencies-filter
# silences the message but writes 1 schema instead of 11; do not "fix" it that way.)
#
# Generate values.schema.json for all Helm charts
[group('charts')]
generate-schema: install-helm-plugins
    #!/usr/bin/env bash
    set -uo pipefail
    helm schema \
        --chart-search-root ./charts \
        --no-dependencies \
        --append-newline || true
    missing=0
    for chart in charts/*/values.yaml; do
        dir=$(dirname "$chart")
        if [ ! -f "$dir/values.schema.json" ]; then
            echo "generate-schema: no schema written for $dir" >&2
            missing=1
        fi
    done
    exit $missing

# Generate the chart documentation and the values schemas
[group('charts')]
generate-all: generate-docs generate-schema

# Generate the Cerbos policy set + authproxy routes manifests from module OpenAPI
# specs. Writes charts/authz-pdp/{policies,schemas} + charts/api-gateway/routes.
#
# Generate the Cerbos policies and authproxy routes from the module OpenAPI specs
[group('charts')]
generate-policies:
    ./policies/build-authz-policies.sh

# pin released image digests into a chart (what the release pipeline runs).
# Normally driven by the module-released event; use this to replay a release or
# pin a chart by hand. Pass every first-party image of the release.
#   just update-chart-images auditflow 1.4.0 \
#       --image labs64/auditflow@sha256:... \
#       --image labs64/auditflow-transformer@sha256:... \
#       --image labs64/auditflow-sink@sha256:...
#
# Pin released image digests into a chart, as the release pipeline does
[group('charts')]
update-chart-images chart version *ARGS:
    python3 scripts/update-chart-images.py --chart {{chart}} --app-version {{version}} {{ARGS}}

# bump a chart's version AND every chart that vendors it (chart-libs consumers, the
# labs64io-ecosystem umbrella) — chart CI rejects a change without these bumps.
#   just bump auditflow          # patch
#   just bump chart-libs minor
#
# Bump a chart's version and the version of every chart that vendors it
[group('charts')]
bump chart part="patch":
    python3 scripts/bump-chart-version.py {{chart}} {{part}}

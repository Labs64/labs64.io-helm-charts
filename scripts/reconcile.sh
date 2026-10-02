#!/usr/bin/env bash
# Reports this deployment's status as JSON.
# Usage: reconcile.sh
# Output format: labs64.io-workspace/cockpit/design/DESIGN.md.
#
# Read-only: only ever reads live kubectl/helm state, same as `just status` /
# `just identity-provider` already do — never writes anything, never touches k3d itself.
set -euo pipefail

namespace_labs64io="labs64io"
namespace_tools="tools"
namespace_monitoring="monitoring"
checked_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if ! command -v jq >/dev/null 2>&1; then
    echo "reconcile.sh needs jq" >&2
    exit 1
fi

actions=$(jq -n '[
  {id:"status", label:"Pods & services", type:"command", command:["just","status"]},
  {id:"identity-provider", label:"Identity provider in use", type:"command", command:["just","identity-provider"]},
  {id:"grafana", label:"Grafana", type:"browser", url:"http://gateway.localhost/grafana/"},
  {id:"traefik-dashboard", label:"Traefik dashboard", type:"browser", url:"http://dashboard.localhost/dashboard/"},
  {id:"docs", label:"API docs (Swagger)", type:"browser", url:"http://gateway.localhost/swagger-ui/"}
]')

services="[]"

emit() {
    local status="$1"; shift
    local issues_json
    issues_json=$(printf '%s\n' "$@" | jq -R . | jq -s 'map(select(length > 0))')
    jq -n \
        --arg kind local-k8s \
        --arg checkedAt "$checked_at" \
        --arg status "$status" \
        --argjson issues "$issues_json" \
        --argjson services "$services" \
        --argjson actions "$actions" \
        '{kind: $kind, env: null, checkedAt: $checkedAt, status: $status, issues: $issues, services: $services, actions: $actions}'
}

if ! kubectl get namespace "$namespace_labs64io" >/dev/null 2>&1; then
    emit red "cluster not reachable (no ${namespace_labs64io} namespace) -- run: labs64.io-helm-charts: just up"
    exit 0
fi

issues=()
services_parts=()

for ns in "$namespace_labs64io" "$namespace_tools" "$namespace_monitoring"; do
    pods_json=$(kubectl -n "$ns" get pods -o json 2>/dev/null || echo '{"items":[]}')
    bad_pods=$(echo "$pods_json" | jq -r '.items[]? | select(.status.phase != "Running" and .status.phase != "Succeeded") | .metadata.name')
    if [ -n "$bad_pods" ]; then
        issues+=("pods not healthy in ${ns}: $(echo "$bad_pods" | tr '\n' ' ')")
    fi

    svc_json=$(kubectl -n "$ns" get deployments,statefulsets -o json 2>/dev/null || echo '{"items":[]}')
    services_parts+=("$(echo "$svc_json" | jq -c --arg ns "$ns" '[.items[]? | {
        name: .metadata.name,
        kind: .kind,
        namespace: $ns,
        ready: (.status.readyReplicas // 0),
        desired: (.spec.replicas // 1)
    }]')")
done

services=$(printf '%s\n' "${services_parts[@]}" | jq -s 'add')
short_services=$(echo "$services" | jq -r '.[] | select(.ready < .desired) | .name')
if [ -n "$short_services" ]; then
    issues+=("services short on replicas: $(echo "$short_services" | tr '\n' ' ')")
fi

releases_json=$(helm list --all-namespaces -o json 2>/dev/null || echo '[]')
bad_releases=$(echo "$releases_json" | jq -r '.[]? | select(.status != "deployed") | "\(.name) (\(.status))"')
if [ -n "$bad_releases" ]; then
    issues+=("helm releases not deployed: $(echo "$bad_releases" | tr '\n' ' ')")
fi

if [ "${#issues[@]}" -eq 0 ]; then
    emit green
else
    emit yellow "${issues[@]}"
fi

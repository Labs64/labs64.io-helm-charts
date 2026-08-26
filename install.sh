#!/usr/bin/env bash
#
# Labs64.IO Ecosystem installer.
#
#   curl -fsSL https://raw.githubusercontent.com/Labs64/labs64.io-helm-charts/<tag>/install.sh | bash
#
# Install, inspect, stop, restart, and uninstall the ecosystem on any Kubernetes
# cluster. Everything it creates is labelled and recorded in a ConfigMap, so
# uninstall never touches resources it did not create.
#
# Portability: bash 3.2 (macOS ships 3.2) — no associative arrays, no
# mapfile/readarray, no ${var^^}. No jq. `base64 -w0` is GNU-only.
set -euo pipefail

WIZARD_VERSION="1.0.0"
REPO_ALIAS="labs64io"
REPO_URL="https://labs64.github.io/labs64.io-helm-charts"
SCRIPT_URL="https://raw.githubusercontent.com/Labs64/labs64.io-helm-charts/master/install.sh"
RELEASE="${LABS64_RELEASE:-labs64io}"
NS_MODULES="${LABS64_NAMESPACE:-labs64io}"
NS_GATEWAY="${LABS64_GATEWAY_NAMESPACE:-tools}"
STATE_CM="labs64io-installer-state"
WORKDIR="${LABS64_WORKDIR:-./labs64io-install}"
LOGFILE="$WORKDIR/install.log"
GATEWAY_API_VERSION="${LABS64_GATEWAY_API_VERSION:-v1.6.0}"
# Chart to install. Defaults to the local directory if it exists, otherwise the published one.
# Point it at a local directory to exercise chart changes that are not published yet ("./charts/labs64io-ecosystem").
if [ -d "./charts/labs64io-ecosystem" ] && [ -z "${LABS64_CHART:-}" ]; then
  CHART="./charts/labs64io-ecosystem"
else
  CHART="${LABS64_CHART:-$REPO_ALIAS/labs64io-ecosystem}"
fi
STOP_ANNOTATION="labs64io.install/original-replicas"

usage() {
  cat <<'USAGE'
Labs64.IO Ecosystem installer

  install.sh [install|status|stop|start|uninstall|smoke] [--dry-run] [--version] [--help]

With no arguments it opens a menu. Name an action to run just that one, which is
what scripts and CI should do — feeding menu numbers on stdin is fragile because
the first prompt is the cluster confirmation.

  install.sh status     # exits non-zero when anything is unhealthy
  install.sh smoke      # re-runs the quickstart request flow for real (install already runs
                         # it once automatically); exits non-zero on failure
  LABS64_YES=1 install.sh stop

Set LABS64_PROFILE=quickstart|custom to install without any prompts.

Environment:
  LABS64_PROFILE              quickstart | custom — skips the menu and every prompt
  LABS64_NAMESPACE            namespace for modules, bundled infra, and the gateway workload
                              itself (Traefik, the ForwardAuth proxy) (default: labs64io)
  LABS64_GATEWAY_NAMESPACE    namespace for the Gateway API `Gateway` object only — no pods
                              ever run here (default: tools)
  LABS64_RELEASE              Helm release name (default: labs64io)
  LABS64_WORKDIR              where generated values/logs go (default: ./labs64io-install)
  LABS64_OIDC_DISCOVERY_URL   issuer discovery URL (required by the custom profile)
  LABS64_CHART                chart to install (default: labs64io/labs64io-ecosystem);
                              set to a local path to test unpublished chart changes
  LABS64_YES=1                accept every default without asking
USAGE
}

DRY_RUN=""
COMMAND=""
for arg in "$@"; do
  case "$arg" in
    # Server-side: a client-side dry run cannot resolve `lookup`, and the bundled
    # Bitnami charts use it to read back existing credentials on upgrade — without
    # it they abort with "You must provide your current passwords when upgrading".
    --dry-run) DRY_RUN="--dry-run=server" ;;
    --version) printf 'labs64io installer %s\n' "$WIZARD_VERSION"; exit 0 ;;
    -h|--help) usage; exit 0 ;;
    # Naming the action beats feeding menu numbers on stdin: the first prompt is
    # the cluster confirmation, which would silently swallow the menu number.
    install|status|stop|start|uninstall|smoke) COMMAND="$arg" ;;
    *) printf 'Unrecognised argument: %s\n\n' "$arg" >&2; usage >&2; exit 2 ;;
  esac
done

# A profile in the environment means "do not ask me anything" — it is both the
# CI path and the escape hatch when no terminal is available.
NONINTERACTIVE=""
if [ -n "${LABS64_PROFILE:-}" ] || [ "${LABS64_YES:-}" = "1" ]; then
  NONINTERACTIVE=1
fi

# --- output -------------------------------------------------------------------

# Colors
C_BOLD='\033[1m'
C_GREEN='\033[32m'
C_YELLOW='\033[33m'
C_RED='\033[31m'
C_CYAN='\033[36m'
C_RESET='\033[0m'

mkdir -p "$WORKDIR"
: > "$LOGFILE"

log()  { printf '%s\n' "$*" >> "$LOGFILE"; printf '%b%s%b\n' "${C_BOLD}" "$*" "${C_RESET}"; }
info() { printf '  %s\n' "$*" >> "$LOGFILE"; printf '  %b%s%b\n' "${C_GREEN}" "$*" "${C_RESET}"; }
warn() { printf 'WARNING: %s\n' "$*" >> "$LOGFILE"; printf '%bWARNING: %s%b\n' "${C_YELLOW}" "$*" "${C_RESET}" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >> "$LOGFILE"; printf '%bERROR: %s%b\n' "${C_RED}" "$*" "${C_RESET}" >&2; exit 1; }

on_err() {
  local rc=$?
  printf '\nFailed (exit %s). Full transcript: %s\n' "$rc" "$LOGFILE" >&2
  exit $rc
}
trap on_err ERR

# --- prompting ----------------------------------------------------------------
#
# Under `curl | bash` the script arrives on stdin, so stdin is NOT free: reading
# answers from it would consume the script's own body — a classic and very
# confusing failure mode. Answers then have to come from /dev/tty.
#
# When the script was run from a file (`bash install.sh`, including
# `bash install.sh <<< "2"`), stdin is free and is the right place to read from.

TTY_FD=""
PROMPT_OUT="/dev/stderr"

open_tty() {
  [ -n "$TTY_FD" ] && return 0
  if [ -t 0 ]; then TTY_FD=0; PROMPT_OUT="/dev/tty"; return 0; fi
  # Read from a file => the script body is not on stdin, so stdin is answers.
  if [ -f "$0" ] && [ -r "$0" ]; then TTY_FD=0; return 0; fi
  # curl | bash => the script body IS stdin. Answers must come from the terminal.
  # The braces keep bash's own "/dev/tty: Device not configured" off the console;
  # a redirection failure is not reported through the command's own stderr.
  if { exec 3</dev/tty; } 2>/dev/null; then TTY_FD=3; PROMPT_OUT="/dev/tty"; return 0; fi
  die "No terminal available for prompts.
This happens when the script is piped in without a TTY (CI, some containers).
Run it non-interactively instead:
  curl -fsSL $SCRIPT_URL -o install.sh
  LABS64_PROFILE=quickstart bash install.sh"
}

# prompt VAR "question" "default"
#
# Locals carry a __p_ prefix so they cannot collide with the caller's variable
# name: `prompt __ans ...` against a `local __ans` here would assign to the local
# and silently discard the answer, leaving every caller with the default.
prompt() {
  local __p_var=$1 __p_q=$2 __p_def=${3:-} __p_ans=""
  if [ -n "$NONINTERACTIVE" ]; then
    eval "$__p_var=\"\$__p_def\""
    return 0
  fi
  open_tty
  if [ -n "$__p_def" ]; then printf '%b%s%b [%s]: ' "${C_CYAN}" "$__p_q" "${C_RESET}" "$__p_def" > "$PROMPT_OUT"
  else printf '%b%s%b: ' "${C_CYAN}" "$__p_q" "${C_RESET}" > "$PROMPT_OUT"; fi
  IFS= read -r __p_ans <&"$TTY_FD" || __p_ans=""
  eval "$__p_var=\"\${__p_ans:-\$__p_def}\""
}

# confirm "question" "y|n"  -> returns 0 for yes
confirm() {
  local __c_q=$1 __c_def=${2:-n} __c_ans=""
  prompt __c_ans "$__c_q (y/n)" "$__c_def"
  case "$__c_ans" in [yY]|[yY][eE][sS]) return 0 ;; *) return 1 ;; esac
}

# --- prerequisites ------------------------------------------------------------

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "$1 is required but not installed.
  $2"
}

check_prereqs() {
  log "Checking prerequisites..."
  need_cmd kubectl "Install: https://kubernetes.io/docs/tasks/tools/"
  need_cmd helm    "Install: https://helm.sh/docs/intro/install/"
  need_cmd curl    "Install curl via your package manager."
  need_cmd base64  "base64 is part of coreutils."
  need_cmd awk     "awk is part of any POSIX base system."
  need_cmd sed     "sed is part of any POSIX base system."

  local kv hv
  kv=$(kubectl version --client -o json 2>/dev/null \
       | sed -n 's/.*"minor": *"\([0-9]*\)".*/\1/p' | head -1)
  if [ -n "$kv" ] && [ "$kv" -lt 27 ] 2>/dev/null; then
    warn "kubectl 1.$kv is older than the tested 1.27."
  fi
  hv=$(helm version --template '{{.Version}}' 2>/dev/null | sed 's/^v//;s/\..*//')
  if [ -n "$hv" ] && [ "$hv" -lt 4 ] 2>/dev/null; then
    die "helm 4.0+ is required (found v$hv)."
  fi

  kubectl cluster-info >/dev/null 2>&1 \
    || die "Cannot reach a Kubernetes cluster.
  Check: kubectl config current-context"

  # Which cluster this lands in is the one thing never to guess at.
  local ctx; ctx=$(kubectl config current-context)
  log ""
  log "  Cluster context: $ctx"
  # Everything (modules, bundled infra, Traefik itself, the ForwardAuth proxy) is one Helm
  # release installed with --namespace NS_MODULES. NS_GATEWAY holds exactly one object: the
  # Gateway API `Gateway` resource, which the traefik subchart pins there via an explicit
  # metadata.namespace override so it can, in principle, be shared across app namespaces —
  # it is never where the gateway *workload* runs, unlike the Helmfile-based local dev path
  # (helmfile.yaml.gotmpl), which installs Traefik as its own release inside NS_GATEWAY.
  log "  Namespaces:      $NS_MODULES — modules, bundled infra (PostgreSQL/RabbitMQ/Redis), and"
  log "                    the gateway workload itself ($RELEASE-traefik, and the ForwardAuth"
  log "                    proxy \"gateway-common\") all run here"
  log "                    $NS_GATEWAY — holds only the Gateway API's Gateway object; no pods"
  log "                    are ever created here"
  confirm "  Install into this cluster?" y \
    || die "Aborted. Switch with: kubectl config use-context <name>"

  kubectl auth can-i create namespace >/dev/null 2>&1 \
    || die "Insufficient permissions: cannot create namespaces in this cluster."
  kubectl auth can-i create customresourcedefinition >/dev/null 2>&1 \
    || warn "Cannot create CRDs — the Gateway API CRD install will be skipped."

  # Without a default StorageClass the bundled Bitnami PVCs sit Pending forever,
  # which looks like a hang rather than a misconfiguration.
  if ! kubectl get storageclass -o jsonpath='{.items[*].metadata.annotations}' 2>/dev/null \
       | grep -q 'is-default-class":"true'; then
    warn "No default StorageClass found. Bundled PostgreSQL/RabbitMQ/Redis request
  PVCs and will stay Pending. Set a default StorageClass, or bring your own infrastructure."
  fi

  info "Prerequisites OK"
}

# --- state --------------------------------------------------------------------
#
# The state ConfigMap is the source of truth for Status / Stop / Start /
# Uninstall. It is written incrementally — after each successful step, not once
# at the end — so an interrupted run is still safe to re-run.
#
# Flat key=value pairs only; values must not contain newlines. Secrets NEVER go
# here: credentials live only in the Kubernetes Secret and in secrets.yaml.

state_init() {
  [ -n "$DRY_RUN" ] && return 0
  kubectl get ns "$NS_MODULES" >/dev/null 2>&1 || kubectl create ns "$NS_MODULES" >/dev/null
  if ! kubectl -n "$NS_MODULES" get configmap "$STATE_CM" >/dev/null 2>&1; then
    kubectl -n "$NS_MODULES" create configmap "$STATE_CM" \
      --from-literal=wizardVersion="$WIZARD_VERSION" \
      --from-literal=created="$(date -u +%Y-%m-%dT%H:%M:%SZ)" >/dev/null
  fi
  kubectl -n "$NS_MODULES" label configmap "$STATE_CM" \
    app.kubernetes.io/managed-by=labs64io-installer --overwrite >/dev/null
}

state_exists() {
  kubectl -n "$NS_MODULES" get configmap "$STATE_CM" >/dev/null 2>&1
}

# state_get KEY [default]
state_get() {
  local v
  v=$(kubectl -n "$NS_MODULES" get configmap "$STATE_CM" \
        -o "jsonpath={.data.$1}" 2>/dev/null || true)
  [ -n "$v" ] && printf '%s' "$v" || printf '%s' "${2:-}"
}

# state_set KEY VALUE
state_set() {
  [ -n "$DRY_RUN" ] && { log "[dry-run] would record $1=$2"; return 0; }
  kubectl -n "$NS_MODULES" patch configmap "$STATE_CM" \
    --type merge -p "{\"data\":{\"$1\":\"$2\"}}" >/dev/null
}

# Append to a comma-separated list value, no duplicates. Kubernetes ConfigMap
# values are strings, and bash 3.2 has no associative arrays — a delimited
# string is the honest representation for both.
state_append() {
  local cur; cur=$(state_get "$1")
  case ",$cur," in *",$2,"*) return 0 ;; esac
  if [ -n "$cur" ]; then state_set "$1" "$cur,$2"; else state_set "$1" "$2"; fi
}

# --- detection ----------------------------------------------------------------
#
# Quickstart installs only what is missing. Anything already present is skipped
# or adopted, and adoption is recorded distinctly from creation — uninstall must
# never delete infrastructure the wizard merely found.

have_gateway_crds() { kubectl get crd gateways.gateway.networking.k8s.io >/dev/null 2>&1; }
have_gateway()      { kubectl -n "$NS_GATEWAY" get gateway labs64io-gateway >/dev/null 2>&1; }
have_release()      { helm status "$1" -n "$2" >/dev/null 2>&1; }
have_service()      { kubectl -n "$2" get svc "$1" >/dev/null 2>&1; }

# Helm never upgrades CRDs bundled in a chart's crds/ after first install, which
# is why these are applied here rather than shipped in the umbrella — the same
# reason the repo's own `just install-crds` pre-applies them server-side.
ensure_gateway_crds() {
  if have_gateway_crds; then
    info "Gateway API CRDs already present — skipping"
    state_set gatewayApiCrds "pre-existing"
    return 0
  fi
  local url="https://github.com/kubernetes-sigs/gateway-api/releases/download/${GATEWAY_API_VERSION}/standard-install.yaml"
  if [ -n "$DRY_RUN" ]; then
    log "[dry-run] would apply Gateway API CRDs $GATEWAY_API_VERSION"
    return 0
  fi
  log "Installing Gateway API CRDs ($GATEWAY_API_VERSION)..."
  kubectl apply --server-side -f "$url" >>"$LOGFILE" 2>&1 \
    || die "Could not apply the Gateway API CRDs.
  Check egress to github.com, or apply them yourself:
    kubectl apply --server-side -f $url"
  state_set gatewayApiCrds "applied-by-wizard"
}

# --- credentials --------------------------------------------------------------

gen_password() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 24 | tr -d '\n/+=' | cut -c1-24
  else
    LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24
  fi
}

# resolve_password VAR SECRET_KEY
#
# The single most important idempotency rule in this script. Regenerating a
# password against a surviving PostgreSQL PVC produces a database whose stored
# credential no longer matches the Secret: an install that reports success and
# cannot connect. Always reuse what is already in the cluster.
resolve_password() {
  local __r_var=$1 __r_key=$2 __r_existing=""
  __r_existing=$(kubectl -n "$NS_MODULES" get secret labs64io-shared-secret \
                   -o "jsonpath={.data.$__r_key}" 2>/dev/null || true)
  if [ -n "$__r_existing" ]; then
    # `base64 -w0` is GNU-only; decoding needs no wrapping flag either way.
    eval "$__r_var=\"\$(printf '%s' \"\$__r_existing\" | base64 --decode)\""
    info "Reusing the existing $__r_key (never regenerated against an existing volume)"
  else
    eval "$__r_var=\"\$(gen_password)\""
  fi
}

# detect_infra NAME DEFAULT_SVC — sets <NAME>_ENABLED and <NAME>_HOST
#
# The bundled/adopted decision is made once and then remembered. Re-probing on
# every run is actively wrong: after the first install the wizard's OWN bundled
# Service is present, so a second run would "adopt" it, set <infra>.enabled=false
# and have the upgrade delete the very database it just provisioned.
detect_infra() {
  local n=$1 svc=$2 recorded=""
  recorded=$(state_get "infra_$n")

  case "$recorded" in
    bundled)
      eval "${n}_ENABLED=true"; eval "${n}_HOST=$svc"; return 0 ;;
    adopted)
      info "$n was adopted on a previous run — still not managed by this installer"
      eval "${n}_ENABLED=false"; eval "${n}_HOST=$svc"; return 0 ;;
  esac

  # First run. A Service belonging to our own Helm release is not a pre-existing
  # one, even if a previous attempt left it behind.
  local owner=""
  if have_service "$svc" "$NS_MODULES"; then
    owner=$(kubectl -n "$NS_MODULES" get svc "$svc" \
              -o jsonpath='{.metadata.labels.app\.kubernetes\.io/instance}' 2>/dev/null || true)
  fi

  if [ -n "$owner" ] && [ "$owner" != "$RELEASE" ]; then
    info "Found an existing $n at $svc — adopting it (it will not be removed on uninstall)"
    state_append adopted "Service/$svc"
    state_set "infra_$n" adopted
    eval "${n}_ENABLED=false"
  elif [ -n "$owner" ]; then
    info "$n at $svc belongs to this release — keeping it bundled"
    state_set "infra_$n" bundled
    eval "${n}_ENABLED=true"
  elif have_service "$svc" "$NS_MODULES"; then
    # Present but unlabelled: created by hand, so it is not ours to manage.
    info "Found an existing $n at $svc — adopting it (it will not be removed on uninstall)"
    state_append adopted "Service/$svc"
    state_set "infra_$n" adopted
    eval "${n}_ENABLED=false"
  else
    state_set "infra_$n" bundled
    eval "${n}_ENABLED=true"
  fi
  eval "${n}_HOST=$svc"
}

# --- values generation --------------------------------------------------------

write_values() {
  # mock-oidc's personas stamp tenant "t_mock", and the chart ships only the
  # reserved `platform` tenant — without this an authenticated demo call is
  # rejected 403 for an unknown tenant. Demo installs only; a real deployment
  # provisions its own tenants.
  AUDITFLOW_DEMO_TENANT=""
  if [ "$DEMO_MODE" = "true" ]; then
    # tenantId / enabled / quota / pipelines are the only fields TenantConfig
    # accepts; anything else makes the app skip the ConfigMap as malformed.
    #
    # log-level: DEBUG is the sink's own debug mode (logging_sink.py reads this
    # property and sets its logger to it directly, independent of the container's
    # root log level) — it dumps the full transformed event JSON to `kubectl logs`
    # on the auditflow-sink container, not just the one-line "Processing event ..."
    # summary every pipeline already logs at INFO.
    #
    # transformer.name: zero is required to see ANY transformer-side output at
    # all: AuditService (auditflow-be) skips the transform HTTP call entirely
    # for "a pipeline with no transformer" and passes the event straight to the
    # sink — with no transformer stage configured, the transformer container
    # never receives a request, so there is nothing in its logs to turn debug
    # on for. `zero` (pass-through, ships in every image) is enough to route the
    # event through it and get its existing per-event INFO line; transformer
    # modules take no properties/config at all (see AGENTS.md), so there is no
    # further "debug" level to set on that side.
    AUDITFLOW_DEMO_TENANT='  tenants:
    additional:
      - tenantId: t_mock
        enabled: true
        pipelines:
          - name: demo-logging
            enabled: true
            transformer:
              name: zero
            sink:
              name: logging_sink
              properties:
                log-level: DEBUG'
  fi

  # Swagger UI's TopBar needs an explicit list of OpenAPI definitions — it has no
  # way to discover enabled modules on its own, and ships with `urls: []` by
  # default ("Could not render TopBar... No API definition provided."). Relative
  # paths (not `http://gateway.<domain>/...`) so this keeps working no matter which
  # address the browser used to reach the gateway (LoadBalancer IP, localhost,
  # port-forward) — the browser resolves them against the current page itself.
  API_DOCS_URLS=""
  if [ "$ENABLE_AUDITFLOW" = "true" ]; then
    API_DOCS_URLS="$API_DOCS_URLS
    - url: /auditflow/v3/api-docs
      name: AuditFlow API"
  fi
  if [ "$ENABLE_CHECKOUT" = "true" ]; then
    API_DOCS_URLS="$API_DOCS_URLS
    - url: /checkout/v3/api-docs
      name: Checkout API"
  fi
  if [ "$ENABLE_PAYMENT_GATEWAY" = "true" ]; then
    API_DOCS_URLS="$API_DOCS_URLS
    - url: /payment-gateway/v3/api-docs
      name: Payment Gateway API"
  fi
  [ -n "$API_DOCS_URLS" ] || API_DOCS_URLS=" []"

  cat > "$WORKDIR/values-overrides.yaml" <<EOF
# Generated by install.sh v$WIZARD_VERSION on $(date -u +%Y-%m-%dT%H:%M:%SZ)
# Re-running the wizard regenerates this file — hand edits will be lost. Put
# durable customisation in your own file and pass it with -f instead.
demoMode: $DEMO_MODE

api-gateway:
  enabled: $ENABLE_API_GATEWAY
  oidc:
    discoveryUrl: "$OIDC_DISCOVERY_URL"
authz-pdp:
  enabled: $ENABLE_AUTHZ_PDP
api-docs:
  enabled: $ENABLE_API_DOCS
  # The api-docs chart pinned by the currently published labs64io-ecosystem
  # chart ships \`gateway.routes: []\` by default (the working two-route example
  # is commented out) — with no route at all, the Gateway API CRD's own default
  # ("no rules" -> one catch-all PathPrefix "/" rule with zero backendRefs")
  # kicks in, so /swagger-ui 503s "no available server" instead of ever reaching
  # the pod. Set both routes explicitly rather than depend on the chart default.
  gateway:
    routes:
      # service is required explicitly: the currently published api-docs chart's
      # httproute.yaml reads \$route.service.name/.port directly with no nil-safe
      # default, so a route without one fails the render ("nil pointer evaluating
      # interface {}.name") instead of falling back to this chart's own service.
      - path: /swagger-ui
        service:
          name: $RELEASE-api-docs
          port: 8080
        stripPrefix: true
      - path: /
        pathType: Exact
        redirectTo: /swagger-ui/
  swaggerUI:
    urls:$API_DOCS_URLS
# gateway.enabled defaults to false on these two, which would leave the install
# with no route to their APIs at all.
auditflow:
  enabled: $ENABLE_AUDITFLOW
  # The @Authorize SDK defaults to a Cerbos sidecar on localhost:3593. There is no
  # sidecar here — the PDP is central — so without this every domain decision fails
  # "Connection refused" and is enforced as a deny: authenticated, allowed at the
  # edge, still 403.
  env:
    - name: LABS64_AUTH_AUTHZ_PDPADDRESS
      value: "$RELEASE-authz-pdp.$NS_MODULES.svc.cluster.local:3593"
  gateway:
    enabled: true
${AUDITFLOW_DEMO_TENANT}
payment-gateway:
  enabled: $ENABLE_PAYMENT_GATEWAY
  # The @Authorize SDK defaults to a Cerbos sidecar on localhost:3593. There is no
  # sidecar here — the PDP is central — so without this every domain decision fails
  # "Connection refused" and is enforced as a deny: authenticated, allowed at the
  # edge, still 403.
  env:
    - name: LABS64_AUTH_AUTHZ_PDPADDRESS
      value: "$RELEASE-authz-pdp.$NS_MODULES.svc.cluster.local:3593"
  gateway:
    enabled: true
# Not GA — their images have never been published.
checkout:
  enabled: $ENABLE_CHECKOUT
customer-portal:
  enabled: $ENABLE_CUSTOMER_PORTAL

postgresql:
  enabled: $POSTGRES_ENABLED
rabbitmq:
  enabled: $RABBITMQ_ENABLED
  service:
    trafficDistribution: PreferSameZone
redis:
  enabled: $REDIS_ENABLED

global:
  gateway:
    # There is no domain to derive route hostnames from here, and a hostname-scoped
    # HTTPRoute 404s every request that arrives by IP or port-forward.
    anyHost: true
  postgresql:
    host: "$POSTGRES_HOST"
  rabbitmq:
    host: "$RABBITMQ_HOST"
  redis:
    host: "$REDIS_HOST"

traefik:
  enabled: $TRAEFIK_ENABLED
mock-oidc:
  enabled: $MOCK_OIDC_ENABLED
EOF

  ( umask 077
    cat > "$WORKDIR/secrets.yaml" <<EOF
# Generated credentials — chmod 600, gitignored. Keep them out of support tickets.
secrets:
  postgresqlPassword: "$PG_PASSWORD"
  rabbitmqPassword: "$RMQ_PASSWORD"
  redisPassword: "$REDIS_PASSWORD"
EOF
  )
  chmod 600 "$WORKDIR/secrets.yaml"
  printf 'secrets.yaml\ninstall.log\n' > "$WORKDIR/.gitignore"
  info "Wrote $WORKDIR/values-overrides.yaml and $WORKDIR/secrets.yaml (0600)"
}

# --- failure diagnostics ------------------------------------------------------
#
# Helm's own error rarely names the cause. ImagePullBackOff is the most likely
# first failure on a fresh cluster, so it gets named explicitly.

install_failed() {
  warn "Install failed. Recent events:"
  kubectl -n "$NS_MODULES" get events --sort-by=.lastTimestamp 2>/dev/null | tail -20 | tee -a "$LOGFILE" || true
  local bad
  bad=$(kubectl -n "$NS_MODULES" get pods \
    -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.containerStatuses[*].state.waiting.reason}{"\n"}{end}' \
    2>/dev/null | grep -E 'ImagePullBackOff|ErrImagePull' || true)
  if [ -n "$bad" ]; then
    warn "Images could not be pulled:
$bad
  Check that each chart's appVersion matches a tag that was actually published."
  fi
  die "See $LOGFILE for the full transcript."
}

# --- progress -------------------------------------------------------------------
#
# Shared by the install/start progress watcher and `status`, so they can never
# drift into counting readiness two different ways and disagreeing.

# Prints "<ready> <total>" for pods in NS_MODULES (Terminating excluded).
# STATUS=Running alone isn't enough — a pod can sit at "0/1 Running" while its
# container is still starting or crash-looping — so ready compares the READY
# column's own "n/n"; Completed (Job) pods have no ready ratio and count on
# STATUS alone. `|| printf '0 0'` guards against a transient kubectl failure
# (e.g. an API server hiccup) tripping `set -e` in a bare `x=$(pod_readiness)`.
pod_readiness() {
  kubectl -n "$NS_MODULES" get pods --no-headers 2>/dev/null | awk '
    $3 == "Terminating" { next }
    { total++; split($2, r, "/") }
    $3 == "Completed" || (r[1] == r[2] && $3 == "Running") { ready++ }
    END { print (ready + 0), (total + 0) }' || printf '0 0'
}

# Backgrounds a loop that prints "... N/M pods ready" (or "... waiting for pods
# to be created") every 10s, only when it changes. Sets $! to the watcher's PID
# same as backgrounding any other job — read it immediately after calling.
# `kill -0 $$` uses the caller's PID (bash does not update $$ in a subshell),
# so the watcher exits on its own if the parent script dies without an explicit
# stop_pod_watcher — a safety net against an orphaned background loop.
start_pod_watcher() {
  (
    trap 'exit 0' TERM
    local last_msg="" ready total msg
    while sleep 10; do
      kill -0 $$ 2>/dev/null || exit 0
      read -r ready total <<< "$(pod_readiness)"
      if [ "$total" -gt 0 ]; then msg="... $ready/$total pods ready"
      else msg="... waiting for pods to be created"
      fi
      if [ "$msg" != "$last_msg" ]; then
        info "$msg"
        last_msg="$msg"
      fi
    done
  ) &
}

stop_pod_watcher() {
  [ -n "${1:-}" ] && kill "$1" 2>/dev/null || true
}

# Sum of .spec.replicas across every Deployment/StatefulSet — the target
# `wait_for_pods_ready` waits for, computed fresh so it reflects whatever was
# just scaled to.
desired_replica_total() {
  kubectl -n "$NS_MODULES" get deploy,statefulset \
    -o jsonpath='{range .items[*]}{.spec.replicas}{"\n"}{end}' 2>/dev/null \
    | awk '{s += $1} END { print s + 0 }'
}

# Blocks, printing "... N/M pods ready" (M fixed at the desired replica total,
# taken once up front) until enough pods are ready or TIMEOUT_SECS elapses.
# Unlike `helm upgrade --wait` (which do_install's watcher runs alongside),
# `kubectl scale` returns as soon as the Deployment/StatefulSet spec is
# updated — before the controller has even created the new Pod objects — so
# do_start has nothing else already blocking to give pods time to come up,
# and pod_readiness()'s own *current* pod count cannot be trusted as the
# denominator: checked too early, it would only see whatever pods already
# existed (e.g. leftover Completed Jobs) and could look "fully ready" on the
# very first pass, before any of the just-scaled workloads even started.
wait_for_pods_ready() {
  local timeout_secs=${1:-300} elapsed=0 last_msg="" ready total desired msg
  desired=$(desired_replica_total)
  while [ "$elapsed" -lt "$timeout_secs" ]; do
    read -r ready total <<< "$(pod_readiness)"
    msg="... $ready/$desired pods ready"
    if [ "$msg" != "$last_msg" ]; then
      info "$msg"
      last_msg="$msg"
    fi
    if [ "$desired" -gt 0 ] && [ "$ready" -ge "$desired" ]; then return 0; fi
    sleep 10
    elapsed=$((elapsed + 10))
  done
  warn "Not all pods were ready within ${timeout_secs}s — check with: install.sh status"
  return 1
}

# --- install ------------------------------------------------------------------

do_install() {
  local profile="${LABS64_PROFILE:-}" c
  if [ -z "$profile" ]; then
    open_tty
    cat > "$PROMPT_OUT" <<'EOF'

  1) Quickstart  — bundled infra, demo IdP, ready to curl in minutes
  2) Custom      — pick modules, bring your own infra / OIDC issuer
EOF
    prompt c "Choose" "1"
    case "$c" in 2|custom) profile=custom ;; *) profile=quickstart ;; esac
  fi
  case "$profile" in
    quickstart|custom) ;;
    *) die "Unknown profile '$profile' (expected quickstart or custom)." ;;
  esac

  state_init
  state_set profile "$profile"

  if [ "$profile" = quickstart ]; then
    DEMO_MODE=true; TRAEFIK_ENABLED=true; MOCK_OIDC_ENABLED=true
    ENABLE_API_GATEWAY=true; ENABLE_AUTHZ_PDP=true; ENABLE_API_DOCS=true
    ENABLE_AUDITFLOW=true; ENABLE_PAYMENT_GATEWAY=true
    ENABLE_CHECKOUT=false; ENABLE_CUSTOMER_PORTAL=false
    OIDC_DISCOVERY_URL="http://mock-oidc.${NS_MODULES}.svc.cluster.local:8080/labs64io/.well-known/openid-configuration"
  else
    DEMO_MODE=false; MOCK_OIDC_ENABLED=false
    prompt OIDC_DISCOVERY_URL "OIDC discovery URL" "${LABS64_OIDC_DISCOVERY_URL:-}"
    [ -n "$OIDC_DISCOVERY_URL" ] \
      || die "An OIDC discovery URL is required outside demo mode.
  Set LABS64_OIDC_DISCOVERY_URL, or choose the quickstart profile."
    if confirm "Install Traefik and a Gateway?" y; then TRAEFIK_ENABLED=true; else TRAEFIK_ENABLED=false; fi
    log ""
    log "Select modules to install:"
    if confirm "  Enable API Gateway (api-gateway module)?" y; then ENABLE_API_GATEWAY=true; else ENABLE_API_GATEWAY=false; fi
    if confirm "  Enable Authz PDP (authz-pdp module)?" y; then ENABLE_AUTHZ_PDP=true; else ENABLE_AUTHZ_PDP=false; fi
    if confirm "  Enable API Docs (api-docs module)?" y; then ENABLE_API_DOCS=true; else ENABLE_API_DOCS=false; fi
    if confirm "  Enable AuditFlow (auditflow module)?" y; then ENABLE_AUDITFLOW=true; else ENABLE_AUDITFLOW=false; fi
    if confirm "  Enable Payment Gateway (payment-gateway module)?" y; then ENABLE_PAYMENT_GATEWAY=true; else ENABLE_PAYMENT_GATEWAY=false; fi
    if confirm "  Enable Checkout (checkout module)?" n; then ENABLE_CHECKOUT=true; else ENABLE_CHECKOUT=false; fi
    if confirm "  Enable Customer Portal (customer-portal module)?" n; then ENABLE_CUSTOMER_PORTAL=true; else ENABLE_CUSTOMER_PORTAL=false; fi
  fi

  detect_infra POSTGRES labs64io-postgresql
  detect_infra RABBITMQ labs64io-rabbitmq
  detect_infra REDIS    labs64io-redis-master

  # Decided once and remembered, for the same reason detect_infra remembers: after
  # the first install our OWN Gateway is present, and re-probing would "adopt" it,
  # turn Traefik off and have the upgrade delete the gateway serving the release.
  case "$(state_get gatewayCreatedBy)" in
    wizard)       TRAEFIK_ENABLED=true ;;
    pre-existing) TRAEFIK_ENABLED=false ;;
    *)
      if [ "$TRAEFIK_ENABLED" = "true" ] && have_gateway; then
        info "Found an existing Gateway labs64io-gateway — reusing it"
        TRAEFIK_ENABLED=false
        state_append adopted "Gateway/labs64io-gateway"
      fi
      # do_uninstall reads this to decide whether the Gateway is ours to remove.
      if [ "$TRAEFIK_ENABLED" = "true" ]; then
        state_set gatewayCreatedBy "wizard"
      else
        state_set gatewayCreatedBy "pre-existing"
      fi
      ;;
  esac

  state_set demoMode "$DEMO_MODE"
  resolve_password PG_PASSWORD    SPRING_DATASOURCE_PASSWORD
  resolve_password RMQ_PASSWORD   SPRING_RABBITMQ_PASSWORD
  resolve_password REDIS_PASSWORD SPRING_DATA_REDIS_PASSWORD
  write_values
  ensure_gateway_crds

  # The Traefik subchart puts the Gateway in NS_GATEWAY while the release lives in
  # NS_MODULES, and --create-namespace only ever creates the release's own.
  if [ "$TRAEFIK_ENABLED" = "true" ] && [ -z "$DRY_RUN" ]; then
    kubectl get ns "$NS_GATEWAY" >/dev/null 2>&1 || kubectl create ns "$NS_GATEWAY" >/dev/null
  fi

  # A local chart path needs no repo; only resolve the published repo when using it.
  case "$CHART" in
    ./*|/*|../*)
      info "Installing from the local chart $CHART (not the published one)"
      helm repo add bitnami https://charts.bitnami.com/bitnami >/dev/null 2>&1 || true
      helm repo add traefik https://traefik.github.io/charts >/dev/null 2>&1 || true
      
      # Helm does not recursively build file:// dependencies. If we are installing
      # the local umbrella chart, we must first build all its local dependencies.
      if [ -d "${CHART%/*}" ]; then
        for d in "${CHART%/*}"/*; do
          if [ -f "$d/Chart.yaml" ] && [ "$d" != "$CHART" ]; then
            helm dependency update "$d" >>"$LOGFILE" 2>&1 || true
          fi
        done
      fi
      
      helm dependency update "$CHART" >>"$LOGFILE" 2>&1 || true
      ;;
    *)
      helm repo add "$REPO_ALIAS" "$REPO_URL" >/dev/null 2>&1 || true
      helm repo update "$REPO_ALIAS" >/dev/null 2>&1 || helm repo update >/dev/null 2>&1
      ;;
  esac

  # No --version: let Helm resolve the newest published chart, then record what
  # it actually resolved so Status can report drift and Uninstall knows what it
  # installed.
  log "Installing (this takes a few minutes on first run)..."
  
  local watcher_pid=""
  if [ -z "$DRY_RUN" ]; then
    start_pod_watcher
    watcher_pid=$!
  fi

  if ! helm upgrade --install "$RELEASE" "$CHART" \
    --namespace "$NS_MODULES" --create-namespace \
    -f "$WORKDIR/values-overrides.yaml" -f "$WORKDIR/secrets.yaml" \
    ${DRY_RUN:+$DRY_RUN} --wait --timeout 15m 2>&1 | tee -a "$LOGFILE"; then
    stop_pod_watcher "$watcher_pid"
    install_failed
  fi
  [ -n "$watcher_pid" ] && kill "$watcher_pid" 2>/dev/null || true

  if [ -n "$DRY_RUN" ]; then
    log ""
    log "[dry-run] nothing was applied to the cluster."
    return 0
  fi

  state_append releases "$RELEASE:$NS_MODULES"
  state_set resolvedVersion "$(helm list -n "$NS_MODULES" -f "^$RELEASE\$" -o json 2>/dev/null \
    | sed -n 's/.*"chart":"labs64io-ecosystem-\([^"]*\)".*/\1/p')"
  do_verify
}

# --- verification -------------------------------------------------------------
#
# "helm reported success" is not the finish line. Quickstart has to prove the
# deployment is callable and hand the user a working curl.

# Traefik's Service lives in the release namespace even though its Gateway object
# is created in NS_GATEWAY, so look in both rather than assuming.
traefik_svc() {
  local ns name
  for ns in "$NS_MODULES" "$NS_GATEWAY"; do
    name=$(kubectl -n "$ns" get svc -l app.kubernetes.io/name=traefik \
             -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
    if [ -n "$name" ]; then printf '%s %s' "$ns" "$name"; return 0; fi
  done
  printf ''
}

gateway_address() {
  local svc ns name ip host port
  svc=$(traefik_svc); [ -n "$svc" ] || { printf ''; return 0; }
  ns=${svc%% *}; name=${svc##* }
  ip=$(kubectl -n "$ns" get svc "$name" \
        -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
  host=$(kubectl -n "$ns" get svc "$name" \
        -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
  port=$(kubectl -n "$ns" get svc "$name" \
        -o jsonpath='{.spec.ports[?(@.name=="web")].port}' 2>/dev/null || true)
  [ -n "$port" ] || port=8000

  # k3d's built-in servicelb reports the serverlb container's address on the Docker
  # bridge network (e.g. 172.18.0.2) as status.loadBalancer.ingress[0].ip. That address
  # is real from inside Docker's network namespace, but unreachable from the host on
  # Docker Desktop (macOS/Windows), where that namespace lives inside a VM — so it is
  # useless as a "browse to this URL" answer even though kubectl reports it as ready.
  # k3d also always publishes that same service port straight through to localhost
  # (k3d/labs64io.yaml maps 80:80/443:443), so prefer localhost whenever it actually
  # answers, and only fall back to the reported address if it doesn't.
  case "$(kubectl config current-context 2>/dev/null)" in
    k3d-*)
      if curl -s -o /dev/null -m 2 "http://localhost:$port" 2>/dev/null; then
        printf 'http://localhost:%s' "$port"; return 0
      fi
      ;;
  esac

  if   [ -n "$ip" ];   then printf 'http://%s:%s' "$ip" "$port"
  elif [ -n "$host" ]; then printf 'http://%s:%s' "$host" "$port"
  else printf ''; fi
}

# A ready-to-paste port-forward for clusters with no LoadBalancer.
port_forward_cmd() {
  local svc ns name port
  svc=$(traefik_svc)
  if [ -z "$svc" ]; then printf 'kubectl -n %s port-forward svc/traefik 8000:8000' "$NS_GATEWAY"; return 0; fi
  ns=${svc%% *}; name=${svc##* }
  port=$(kubectl -n "$ns" get svc "$name" \
          -o jsonpath='{.spec.ports[?(@.name=="web")].port}' 2>/dev/null || true)
  [ -n "$port" ] || port=8000
  printf 'kubectl -n %s port-forward svc/%s 8000:%s' "$ns" "$name" "$port"
}

# True if a Deployment carrying the chart's standard app.kubernetes.io/name
# label exists. Used to work out which modules are actually installed —
# read live from the cluster rather than install.sh's own state, so it works
# the same whether this run installed them or a previous run did.
module_present() {
  kubectl -n "$NS_MODULES" get deploy -l "app.kubernetes.io/name=$1" --no-headers 2>/dev/null \
    | grep -q .
}

# The one public route every profile is guaranteed to have *something* behind:
# prefer Swagger UI (most universally reachable page), then a real module API,
# then the api-gateway's own /health. Shared by do_verify and do_status so
# they can never drift into checking two different things and disagreeing.
pick_health_route() {
  if   module_present api-docs;   then printf '/swagger-ui'
  elif module_present auditflow;  then printf '/auditflow/v3/api-docs'
  elif module_present api-gateway; then printf '/health'
  else printf '/'
  fi
}

do_verify() {
  log ""
  log "Verifying..."

  if helm test "$RELEASE" -n "$NS_MODULES" --timeout 5m >>"$LOGFILE" 2>&1; then
    info "Module health checks passed"
  else
    warn "helm test failed — see $LOGFILE. Pods may still be starting; re-check with: install.sh status"
  fi

  # The real functional check: run the exact quickstart request flow (gateway,
  # Swagger UI, a demo token, a real published event) instead of one ad-hoc
  # curl. Never let a smoke failure abort a freshly-succeeded `helm install` —
  # it is surfaced above via FAIL lines, not by killing this command.
  do_smoke || true

  print_notes
}

# Copy-pasteable demo commands for the given base URL. Called once, from the
# end of do_smoke — which runs both right after install (do_verify) and
# standalone (`install.sh smoke`) — so it shows up either way without
# printing twice. Reads module_present/state_get rather than do_install's
# ENABLE_* globals, since do_smoke must work in its own invocation with none
# of those set.
print_try_it_yourself() {
  local addr=$1
  [ "$(state_get demoMode)" = "true" ] || return 0

  cat <<EOF

 Try it yourself (DEV ONLY — mock-oidc authenticates nobody):
   Get a demo token:
     TOKEN=\$(curl -s -X POST $addr/labs64io/token \\
       -H 'Content-Type: application/x-www-form-urlencoded' \\
       --data-urlencode 'grant_type=client_credentials' \\
       --data-urlencode 'client_id=local-test' \\
       --data-urlencode 'client_secret=local-test' \\
       --data-urlencode 'scope=admin' \\
       | sed -n 's/.*"access_token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
EOF
  if module_present auditflow; then
    cat <<EOF

   Publish an audit event (eventType and sourceSystem are both required):
     curl -i -X POST $addr/auditflow/api/v1/audit/publish \\
       -H "Authorization: Bearer \$TOKEN" \\
       -H 'Content-Type: application/json' \\
       -d '{"eventType":"demo.hello","sourceSystem":"quickstart"}'
EOF
  fi
}

print_notes() {
  local addr port_forward=""
  addr=$(gateway_address)
  if [ -z "$addr" ]; then
    addr="http://localhost:8000"
    port_forward=1
  fi

  cat <<EOF

────────────────────────────────────────────────────────────────
 Labs64.IO is ready.

   Base URL:  $addr
EOF
  if [ "$ENABLE_API_DOCS" = "true" ]; then
    cat <<EOF
   API docs:  $addr/swagger-ui
EOF
  fi
  [ -n "$port_forward" ] && cat <<EOF

   This cluster has no LoadBalancer — the checks above ran against a guess.
   Run the port-forward first, then re-check against http://localhost:8000:
     $(port_forward_cmd)
EOF

  cat <<EOF

 Enabled modules:
EOF
  [ "$ENABLE_API_GATEWAY" = "true" ]     && printf '   - api-gateway\n'
  [ "$ENABLE_AUTHZ_PDP" = "true" ]       && printf '   - authz-pdp\n'
  [ "$ENABLE_API_DOCS" = "true" ]        && printf '   - api-docs\n'
  [ "$ENABLE_AUDITFLOW" = "true" ]       && printf '   - auditflow\n'
  [ "$ENABLE_PAYMENT_GATEWAY" = "true" ] && printf '   - payment-gateway\n'
  [ "$ENABLE_CHECKOUT" = "true" ]        && printf '   - checkout\n'
  [ "$ENABLE_CUSTOMER_PORTAL" = "true" ] && printf '   - customer-portal\n'

  # Not called here: do_verify (this function's only caller) already ran
  # do_smoke immediately before this, which prints this same section once —
  # calling it again here would just duplicate it.

  cat <<EOF

 Next steps
   bash install.sh smoke       re-run the checks above any time
   bash install.sh status      what is installed, and is it healthy
   bash install.sh stop        scale everything to zero (keeps data)
   bash install.sh start       restore previous replica counts
   bash install.sh uninstall   remove what this wizard created

   Generated config: $WORKDIR/
────────────────────────────────────────────────────────────────
EOF
}

# --- smoke test -----------------------------------------------------------------
#
# print_notes() below only *prints* the quickstart recipe (get a token, publish an
# event) for the user to paste in by hand. do_smoke() runs that exact recipe for
# real against a live install and reports pass/fail per step, so "it's ready" is a
# verified fact instead of a printed suggestion. do_verify() runs it automatically
# at the end of every install; it is also its own command (`install.sh smoke`) for
# re-checking later, so it must not assume it is running right after an install —
# no dependence on do_install's ENABLE_* variables, only on what is actually live
# in the cluster right now (module_present, state_get demoMode).
#
# Exits non-zero if anything fails, so `install.sh smoke` is usable as a scripted
# post-install / CI check, same as `install.sh status`.

do_smoke() {
  state_exists || die "Nothing installed in $NS_MODULES. Run: install.sh install"

  log ""
  log "Smoke test — running the quickstart request flow for real..."
  log ""

  local pass=0 fail=0

  step_pass() { pass=$((pass + 1)); info "PASS  $*"; }
  step_fail() { fail=$((fail + 1)); warn "FAIL  $*"; }
  step_skip() { info "SKIP  $*"; }

  local addr port_forward=""
  addr=$(gateway_address)
  if [ -z "$addr" ]; then
    warn "No external Gateway address (this cluster has no LoadBalancer).
  Reach it with a port-forward instead:
    $(port_forward_cmd)
  then re-run against http://localhost:8000."
    addr="http://localhost:8000"
    port_forward=1
  fi

  # 1. Gateway itself answers. Every other check talks through this same
  #    address, so a failure here means they would all fail identically —
  #    stop after one clear message instead of a wall of confusing FAILs.
  if curl -fsS -m 5 -o /dev/null "$addr/" 2>>"$LOGFILE"; then
    step_pass "Gateway reachable at $addr"
  else
    step_fail "Gateway not reachable at $addr"
    log ""
    log "Smoke test: $pass passed, $fail failed, rest skipped (nothing downstream of the"
    log "gateway can be reached either) — see $LOGFILE for details."
    [ "$port_forward" = "1" ] && warn "Ran against a port-forward guess ($addr) — start one first: $(port_forward_cmd)"
    return 1
  fi

  # 2. Swagger UI, and the TopBar actually has API definitions configured — the
  #    exact regression this smoke test exists to catch (an empty `urls: []`
  #    renders a UI with no error but "No API definition provided").
  if module_present api-docs; then
    if curl -fsS -m 5 -o /dev/null "$addr/swagger-ui/" 2>>"$LOGFILE"; then
      step_pass "Swagger UI reachable at $addr/swagger-ui/"
    else
      step_fail "Swagger UI unreachable at $addr/swagger-ui/"
    fi
    # Matches the per-entry "url: ..." line, not the "urls:" key itself (no
    # trailing colon right after "url") or "validatorUrl:" (capital U) — plain
    # substring match on purpose: \s isn't portable BRE (BSD/macOS grep).
    # `|| true` guards both curl (connection failure) and grep (zero matches,
    # its own definition of "not found") from tripping `set -e`.
    local urls_count
    urls_count=$(curl -fsS -m 5 "$addr/swagger-ui/swagger-config.yaml" 2>>"$LOGFILE" \
                   | grep -c 'url:' || true)
    if [ "${urls_count:-0}" -gt 0 ]; then
      step_pass "Swagger UI TopBar has $urls_count API definition(s) configured"
    else
      step_fail "Swagger UI TopBar has no API definitions (swagger-config.yaml urls: [])"
    fi
  else
    step_skip "api-docs not installed — no Swagger UI to check"
  fi

  # 3. The actual first-good-request flow: get a demo token, then use it.
  if [ "$(state_get demoMode)" != "true" ]; then
    step_skip "demoMode is off (custom profile / your own OIDC issuer) — no demo token to fetch"
  else
    # `|| true` on both curl calls below is load-bearing: without it, a refused
    # connection or a non-2xx (curl -f) exits nonzero, and this bare assignment
    # would trip `set -e` and kill the whole script instead of recording a FAIL.
    local token_resp token
    token_resp=$(curl -fsS -m 5 -X POST "$addr/labs64io/token" \
      -H 'Content-Type: application/x-www-form-urlencoded' \
      --data-urlencode 'grant_type=client_credentials' \
      --data-urlencode 'client_id=local-test' \
      --data-urlencode 'client_secret=local-test' \
      --data-urlencode 'scope=admin' 2>>"$LOGFILE") || token_resp=""
    printf 'token response: %s\n' "$token_resp" >>"$LOGFILE"
    token=$(printf '%s' "$token_resp" \
              | sed -n 's/.*"access_token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

    if [ -n "$token" ]; then
      step_pass "Obtained a demo access token from mock-oidc"
    else
      step_fail "Could not obtain a demo access token from mock-oidc ($addr/labs64io/token)"
    fi

    if [ -z "$token" ]; then
      step_skip "Publish an audit event — no token to authenticate with"
    elif ! module_present auditflow; then
      step_skip "auditflow not installed — no demo API call to make"
    else
      local publish_resp publish_code
      publish_resp=$(mktemp)
      publish_code=$(curl -s -o "$publish_resp" -w '%{http_code}' -m 5 \
        -X POST "$addr/auditflow/api/v1/audit/publish" \
        -H "Authorization: Bearer $token" \
        -H 'Content-Type: application/json' \
        -d '{"eventType":"smoke.test","sourceSystem":"install.sh"}' 2>>"$LOGFILE") || publish_code="000"
      printf 'publish response (HTTP %s): %s\n' "$publish_code" "$(cat "$publish_resp")" >>"$LOGFILE"
      rm -f "$publish_resp"
      case "$publish_code" in
        2??) step_pass "Published a demo audit event (HTTP $publish_code) — first good request succeeded" ;;
        *)   step_fail "Audit event publish failed (HTTP $publish_code) — see $LOGFILE" ;;
      esac
    fi
  fi

  log ""
  if [ "$fail" -eq 0 ]; then
    log "Smoke test: $pass passed, 0 failed — the quickstart flow works end to end."
  else
    log "Smoke test: $pass passed, $fail failed — see $LOGFILE for full request/response detail."
  fi
  [ "$port_forward" = "1" ] && warn "Ran against a port-forward guess ($addr) — start one first if checks above failed to connect."
  print_try_it_yourself "$addr"
  [ "$fail" -eq 0 ]
}

# --- status -------------------------------------------------------------------
#
# Reads the state ConfigMap, then reports live. Exits non-zero when anything is
# unhealthy, so `install.sh` option 2 is usable in a scripted check.

do_status() {
  local rc=0
  state_exists || { log "Not installed (no $STATE_CM in $NS_MODULES)."; return 1; }

  log ""
  log "Installed by wizard v$(state_get wizardVersion) on $(state_get created)"
  log "  profile: $(state_get profile)"
  log "  demoMode: $(state_get demoMode)"
  log "  stopped: $(state_get stopped no)"
  local resolved; resolved=$(state_get resolvedVersion)
  [ -n "$resolved" ] && log "  chart version: $resolved"

  log ""
  log "Releases:"
  local entry rel ns listed
  for entry in $(state_get releases | tr ',' ' '); do
    rel=${entry%%:*}; ns=${entry##*:}
    if have_release "$rel" "$ns"; then
      info "$(helm list -n "$ns" -f "^$rel\$" --no-headers 2>/dev/null | awk '{print $1, $8, $9}')"
    else
      warn "$rel/$ns is recorded in state but not found in Helm — drift"; rc=1
    fi
  done
  # The other direction: a labelled release Helm knows about that state does not.
  listed=$(state_get releases)
  for rel in $(helm list -n "$NS_MODULES" --no-headers -o json 2>/dev/null \
                 | sed -n 's/.*"name":"\([^"]*\)".*/\1/p'); do
    case ",$listed," in *",$rel:$NS_MODULES,"*) : ;;
      *) warn "release $rel exists in $NS_MODULES but is not recorded in state — drift"; rc=1 ;;
    esac
  done

  log ""
  log "Workloads:"
  kubectl -n "$NS_MODULES" get deploy,statefulset \
    -o custom-columns='NAME:.metadata.name,READY:.status.readyReplicas,WANT:.spec.replicas' \
    --no-headers 2>/dev/null | while read -r line; do info "$line"; done
  local ready total notready
  read -r ready total <<< "$(pod_readiness)"
  notready=$((total - ready))
  if [ "$notready" -gt 0 ]; then
    warn "$notready pod(s) not Running"; rc=1
  fi

  log ""
  local addr; addr=$(gateway_address)
  if [ -n "$addr" ]; then
    info "Gateway: $addr"
    local health_route; health_route=$(pick_health_route)
    if curl -fsS -m 5 "$addr$health_route" >/dev/null 2>&1; then
      info "Public route: OK"
    elif kubectl run --rm -i curl-pod --image=curlimages/curl --restart=Never -- curl -fsS -m 5 "$addr$health_route" >/dev/null 2>&1; then
      info "Public route: OK (verified from within cluster)"
    else
      warn "Public route: unreachable"; rc=1
    fi
  else
    warn "Gateway: no external address (no LoadBalancer on this cluster).
  Reach it with: $(port_forward_cmd)"
  fi

  local pvcs adopted
  pvcs=$(kubectl -n "$NS_MODULES" get pvc --no-headers 2>/dev/null \
         | awk '{print "  " $1 " " $2 " " $4}')
  if [ -n "$pvcs" ]; then log ""; log "Volumes:"; printf '%s\n' "$pvcs" | tee -a "$LOGFILE"; fi

  adopted=$(state_get adopted)
  if [ -n "$adopted" ]; then
    log ""
    log "Adopted, never removed on uninstall: $adopted"
  fi
  return $rc
}
# --- stop / start -------------------------------------------------------------
#
# Scale to zero and back, preserving data. The original replica count is stored
# in an annotation on each workload rather than only in the state ConfigMap, so a
# restart still works if that ConfigMap is lost.

# Emits "<kind> <name> <value>" per workload, where <value> is the jsonpath given.
workload_list() {
  kubectl -n "$NS_MODULES" get deploy,statefulset \
    -o jsonpath="{range .items[*]}{.kind}{' '}{.metadata.name}{' '}{$1}{'\n'}{end}" 2>/dev/null
}

lower() { printf '%s' "$1" | tr 'A-Z' 'a-z'; }

do_stop() {
  state_exists || die "Nothing installed in $NS_MODULES."

  # An active HPA will fight a scale-to-zero. Every module chart defaults
  # autoscaling.enabled=false, so this is worth naming, not blocking on.
  local hpas; hpas=$(kubectl -n "$NS_MODULES" get hpa --no-headers 2>/dev/null | wc -l | tr -d ' ')
  if [ "${hpas:-0}" -gt 0 ] 2>/dev/null; then
    warn "$hpas HorizontalPodAutoscaler(s) present — they may scale these workloads back up."
  fi

  log "Scaling workloads in $NS_MODULES to zero (PVCs and Secrets are untouched)..."
  local kind name reps k
  while read -r kind name reps; do
    [ -z "${name:-}" ] && continue
    [ "${reps:-0}" = "0" ] && continue
    k=$(lower "$kind")
    kubectl -n "$NS_MODULES" annotate "$k" "$name" "$STOP_ANNOTATION=$reps" --overwrite >/dev/null
    kubectl -n "$NS_MODULES" scale "$k" "$name" --replicas=0 >/dev/null
    info "$kind/$name: $reps -> 0"
  done <<EOF
$(workload_list '.spec.replicas')
EOF

  state_set stopped "yes"
  log "Stopped. Restart with: install.sh start   (PVCs and Secrets are untouched)"
}

do_start() {
  state_exists || die "Nothing installed in $NS_MODULES."
  log "Restoring replica counts..."
  local kind name reps k
  while read -r kind name reps; do
    [ -z "${name:-}" ] && continue
    # No annotation means this wizard never stopped it; one replica is the safe
    # floor rather than leaving it at zero.
    [ -z "${reps:-}" ] && reps=1
    k=$(lower "$kind")
    kubectl -n "$NS_MODULES" scale "$k" "$name" --replicas="$reps" >/dev/null
    kubectl -n "$NS_MODULES" annotate "$k" "$name" "$STOP_ANNOTATION-" >/dev/null 2>&1 || true
    info "$kind/$name -> $reps"
  done <<EOF
$(workload_list ".metadata.annotations['labs64io\\.install/original-replicas']")
EOF
  state_set stopped "no"

  # `kubectl scale` returns as soon as the request is accepted, not once pods
  # are actually ready — unlike do_install's `helm upgrade --wait`, nothing
  # here already blocks, so show the same "... N/M pods ready" progress while
  # actively waiting for it, instead of leaving the user to guess.
  log "Waiting for pods to become ready..."
  wait_for_pods_ready || true
  log "Started. Check readiness with: install.sh status"
}
# --- uninstall ----------------------------------------------------------------
#
# Prompts per resource class, never one blanket "delete everything?". Destructive
# classes default to No, and anything recorded as adopted is filtered out of every
# list — the wizard must never delete what it merely found.

do_uninstall() {
  state_exists || die "Nothing installed in $NS_MODULES (no $STATE_CM)."

  local adopted entry rel ns
  adopted=$(state_get adopted)
  log ""
  log "Uninstalling. You will be asked about each class of resource separately."
  [ -n "$adopted" ] && log "Left in place (pre-existing, adopted): $adopted"

  # 1. Helm releases — wizard-created only
  log ""
  log "Helm releases created by this wizard:"
  for entry in $(state_get releases | tr ',' ' '); do
    info "${entry%%:*} (namespace ${entry##*:})"
  done
  if confirm "Delete these releases?" y; then
    for entry in $(state_get releases | tr ',' ' '); do
      rel=${entry%%:*}; ns=${entry##*:}
      if helm uninstall "$rel" -n "$ns" --wait --timeout 5m >>"$LOGFILE" 2>&1; then
        info "deleted $rel"
      else
        warn "could not delete $rel — see $LOGFILE"
      fi
    done
  fi

  # 2. PVCs — irreversible, default No, listed with sizes first
  local pvcs
  pvcs=$(kubectl -n "$NS_MODULES" get pvc \
    -o custom-columns='NAME:.metadata.name,SIZE:.spec.resources.requests.storage' \
    --no-headers 2>/dev/null || true)
  if [ -n "$pvcs" ]; then
    log ""
    log "PersistentVolumeClaims in $NS_MODULES (DELETING THESE DESTROYS ALL DATA):"
    printf '%s\n' "$pvcs" | while read -r l; do info "$l"; done
    if confirm "Delete these PVCs? This cannot be undone" n; then
      kubectl -n "$NS_MODULES" delete pvc --all --wait=false >>"$LOGFILE" 2>&1
      info "PVCs deleted"
    else
      info "PVCs kept — a later re-install will reattach to them"
    fi
  fi

  # 3. Secrets. Keeping them is what lets a re-install reattach to surviving PVCs
  #    with credentials the database will still accept.
  log ""
  if confirm "Delete generated Secrets (keeping them lets a re-install reattach to surviving PVCs)?" n; then
    kubectl -n "$NS_MODULES" delete secret labs64io-shared-secret --ignore-not-found >>"$LOGFILE" 2>&1
    info "shared Secret deleted"
  fi

  # 4. Gateway namespace — only if we created the Gateway and nothing else is left
  if [ "$(state_get gatewayCreatedBy)" = "wizard" ]; then
    local left_gw
    left_gw=$(kubectl -n "$NS_GATEWAY" get all --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [ "${left_gw:-0}" -eq 0 ] 2>/dev/null; then
      log ""
      confirm "Namespace $NS_GATEWAY is empty. Delete it?" n \
        && kubectl delete ns "$NS_GATEWAY" --wait=false >>"$LOGFILE" 2>&1 || true
    else
      warn "Namespace $NS_GATEWAY still holds other workloads — left in place."
    fi
  fi

  # 5. Gateway API CRDs — cluster-scoped, default No
  if [ "$(state_get gatewayApiCrds)" = "applied-by-wizard" ]; then
    log ""
    warn "Gateway API CRDs are cluster-scoped. Deleting them removes EVERY Gateway and
  HTTPRoute in this cluster, including ones unrelated to Labs64.IO."
    if confirm "Delete Gateway API CRDs?" n; then
      kubectl delete -f \
        "https://github.com/kubernetes-sigs/gateway-api/releases/download/${GATEWAY_API_VERSION}/standard-install.yaml" \
        --ignore-not-found >>"$LOGFILE" 2>&1 || warn "could not delete the CRDs — see $LOGFILE"
    fi
  fi

  # 6. Module namespace — only when nothing is left in it
  log ""
  local left
  left=$(kubectl -n "$NS_MODULES" get all --no-headers 2>/dev/null | wc -l | tr -d ' ')
  if [ "${left:-0}" -eq 0 ] 2>/dev/null; then
    if confirm "Namespace $NS_MODULES is empty. Delete it?" n; then
      kubectl delete ns "$NS_MODULES" --wait=false >>"$LOGFILE" 2>&1
      log "Uninstalled. Generated files remain in $WORKDIR/"
      return 0
    fi
  else
    info "Namespace $NS_MODULES still holds $left object(s) — left in place."
  fi

  # 7. State ConfigMap last, once everything else has been dealt with
  kubectl -n "$NS_MODULES" delete configmap "$STATE_CM" --ignore-not-found >>"$LOGFILE" 2>&1
  log "Uninstalled. Generated files remain in $WORKDIR/"
}

# --- menu ---------------------------------------------------------------------

main_menu() {
  local installed choice
  while :; do
    installed="not installed"
    state_exists && installed="installed in $NS_MODULES"
    open_tty
    cat > "$PROMPT_OUT" <<EOF

Labs64.IO Ecosystem installer (v$WIZARD_VERSION)
Cluster: $(kubectl config current-context)
Status:  $installed

  1) Install or update  — run the wizard to install or upgrade
  2) Status             — what is installed, and is it healthy
  3) Start              — restore previous replica counts
  4) Stop               — scale everything to zero (keeps data)
  5) Uninstall          — remove what this wizard created
  6) Smoke tests        — run the quickstart request flow for real and verify it works
  q) Quit
EOF
    prompt choice "Choose" "1"
    case "$choice" in
      1) do_install ;;
      2) do_status || true ;;
      3) do_start ;;
      4) do_stop ;;
      5) do_uninstall; return ;;
      6) do_smoke || true ;;
      q|Q) exit 0 ;;
      *) warn "Unrecognised choice: $choice" ;;
    esac
  done
}

main() {
  check_prereqs
  case "${COMMAND:-}" in
    install)   do_install ;;
    status)    do_status ;;
    stop)      do_stop ;;
    start)     do_start ;;
    uninstall) do_uninstall ;;
    smoke)     do_smoke ;;
    *)
      if [ -n "${LABS64_PROFILE:-}" ]; then do_install; else main_menu; fi
      ;;
  esac
}

main "$@"

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
# Chart to install. Defaults to the published one; point it at a local directory
# to exercise chart changes that are not published yet ("./charts/labs64io-ecosystem").
CHART="${LABS64_CHART:-$REPO_ALIAS/labs64io-ecosystem}"
STOP_ANNOTATION="labs64io.install/original-replicas"

usage() {
  cat <<'USAGE'
Labs64.IO Ecosystem installer

  install.sh [install|status|stop|start|uninstall] [--dry-run] [--version] [--help]

With no arguments it opens a menu. Name an action to run just that one, which is
what scripts and CI should do — feeding menu numbers on stdin is fragile because
the first prompt is the cluster confirmation.

  install.sh status     # exits non-zero when anything is unhealthy
  LABS64_YES=1 install.sh stop

Set LABS64_PROFILE=quickstart|custom to install without any prompts.

Environment:
  LABS64_PROFILE              quickstart | custom — skips the menu and every prompt
  LABS64_NAMESPACE            namespace for modules and bundled infra (default: labs64io)
  LABS64_GATEWAY_NAMESPACE    namespace for Traefik and the Gateway (default: tools)
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
    install|status|stop|start|uninstall) COMMAND="$arg" ;;
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

mkdir -p "$WORKDIR"
: > "$LOGFILE"

log()  { printf '%s\n' "$*" | tee -a "$LOGFILE"; }
info() { printf '  %s\n' "$*" | tee -a "$LOGFILE"; }
warn() { printf 'WARNING: %s\n' "$*" | tee -a "$LOGFILE" >&2; }
die()  { printf 'ERROR: %s\n' "$*" | tee -a "$LOGFILE" >&2; exit 1; }

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
  if [ -n "$__p_def" ]; then printf '%s [%s]: ' "$__p_q" "$__p_def" > "$PROMPT_OUT"
  else printf '%s: ' "$__p_q" > "$PROMPT_OUT"; fi
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
  if [ -n "$hv" ] && [ "$hv" -lt 3 ] 2>/dev/null; then
    die "helm 3.12+ is required (found v$hv)."
  fi

  kubectl cluster-info >/dev/null 2>&1 \
    || die "Cannot reach a Kubernetes cluster.
  Check: kubectl config current-context"

  # Which cluster this lands in is the one thing never to guess at.
  local ctx; ctx=$(kubectl config current-context)
  log ""
  log "  Cluster context: $ctx"
  log "  Namespaces:      $NS_MODULES (modules + bundled infra), $NS_GATEWAY (gateway)"
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
    AUDITFLOW_DEMO_TENANT='  tenants:
    additional:
      - tenantId: t_mock
        enabled: true
        pipelines:
          - name: demo-logging
            enabled: true
            sink:
              name: logging_sink
              properties:
                log-level: INFO'
  fi

  cat > "$WORKDIR/values-overrides.yaml" <<EOF
# Generated by install.sh v$WIZARD_VERSION on $(date -u +%Y-%m-%dT%H:%M:%SZ)
# Re-running the wizard regenerates this file — hand edits will be lost. Put
# durable customisation in your own file and pass it with -f instead.
demoMode: $DEMO_MODE

api-gateway:
  enabled: true
  oidc:
    discoveryUrl: "$OIDC_DISCOVERY_URL"
authz-pdp:
  enabled: true
api-docs:
  enabled: true
# gateway.enabled defaults to false on these two, which would leave the install
# with no route to their APIs at all.
auditflow:
  enabled: true
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
  enabled: true
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
  enabled: false
customer-portal:
  enabled: false

postgresql:
  enabled: $POSTGRES_ENABLED
rabbitmq:
  enabled: $RABBITMQ_ENABLED
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
    OIDC_DISCOVERY_URL="http://mock-oidc.${NS_MODULES}.svc.cluster.local:8080/labs64io/.well-known/openid-configuration"
  else
    DEMO_MODE=false; MOCK_OIDC_ENABLED=false
    prompt OIDC_DISCOVERY_URL "OIDC discovery URL" "${LABS64_OIDC_DISCOVERY_URL:-}"
    [ -n "$OIDC_DISCOVERY_URL" ] \
      || die "An OIDC discovery URL is required outside demo mode.
  Set LABS64_OIDC_DISCOVERY_URL, or choose the quickstart profile."
    if confirm "Install Traefik and a Gateway?" y; then TRAEFIK_ENABLED=true; else TRAEFIK_ENABLED=false; fi
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
      helm dependency build "$CHART" >>"$LOGFILE" 2>&1 || true
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
  helm upgrade --install "$RELEASE" "$CHART" \
    --namespace "$NS_MODULES" --create-namespace \
    -f "$WORKDIR/values-overrides.yaml" -f "$WORKDIR/secrets.yaml" \
    ${DRY_RUN:+$DRY_RUN} --wait --timeout 15m 2>&1 | tee -a "$LOGFILE" || install_failed

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

do_verify() {
  log ""
  log "Verifying..."

  if helm test "$RELEASE" -n "$NS_MODULES" --timeout 5m >>"$LOGFILE" 2>&1; then
    info "Module health checks passed"
  else
    warn "helm test failed — see $LOGFILE. Pods may still be starting; re-check with: install.sh status"
  fi

  local addr port_forward=""
  addr=$(gateway_address)
  if [ -z "$addr" ]; then
    warn "The Gateway has no external address (this cluster has no LoadBalancer).
  Reach it with a port-forward instead:
    $(port_forward_cmd)
  then use http://localhost:8000 as the base URL below."
    addr="http://localhost:8000"
    port_forward=1
  elif curl -fsS -m 10 "$addr/auditflow/v3/api-docs" >/dev/null 2>&1; then
    info "Public route reachable at $addr"
  else
    warn "The Gateway is at $addr but is not answering yet — routes may need a moment."
  fi

  print_notes "$addr" "$port_forward"
}

print_notes() {
  local addr=$1 port_forward=${2:-}
  cat <<EOF

────────────────────────────────────────────────────────────────
 Labs64.IO is ready.

   Base URL:  $addr
   API docs:  $addr/swagger-ui
EOF
  [ -n "$port_forward" ] && cat <<EOF

   First run the port-forward (this cluster has no LoadBalancer):
     $(port_forward_cmd)
EOF
  if [ "$(state_get demoMode)" = "true" ]; then
    cat <<EOF

   Get a demo token (DEV ONLY — mock-oidc authenticates nobody):
     TOKEN=\$(curl -s -X POST $addr/labs64io/token \\
       -H 'Content-Type: application/x-www-form-urlencoded' \\
       --data-urlencode 'grant_type=client_credentials' \\
       --data-urlencode 'client_id=local-test' \\
       --data-urlencode 'client_secret=local-test' \\
       --data-urlencode 'scope=admin' \\
       | sed -n 's/.*"access_token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

   Publish an audit event (eventType and sourceSystem are both required):
     curl -i -X POST $addr/auditflow/api/v1/audit/publish \\
       -H "Authorization: Bearer \$TOKEN" \\
       -H 'Content-Type: application/json' \\
       -d '{"eventType":"demo.hello","sourceSystem":"quickstart"}'
EOF
  fi
  cat <<EOF

   Manage this install:  bash install.sh status | stop | start | uninstall
   Generated config:     $WORKDIR/
────────────────────────────────────────────────────────────────
EOF
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
  log "  profile: $(state_get profile)   demoMode: $(state_get demoMode)   stopped: $(state_get stopped no)"
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
  local notready
  kubectl -n "$NS_MODULES" get deploy,statefulset \
    -o custom-columns='NAME:.metadata.name,READY:.status.readyReplicas,WANT:.spec.replicas' \
    --no-headers 2>/dev/null | while read -r line; do info "$line"; done
  notready=$(kubectl -n "$NS_MODULES" get pods --no-headers 2>/dev/null \
             | grep -vcE 'Running|Completed' || true)
  if [ "${notready:-0}" -gt 0 ] 2>/dev/null; then
    warn "$notready pod(s) not Running"; rc=1
  fi

  log ""
  local addr; addr=$(gateway_address)
  if [ -n "$addr" ]; then
    info "Gateway: $addr"
    if curl -fsS -m 10 "$addr/auditflow/v3/api-docs" >/dev/null 2>&1; then
      info "Public route: OK"
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
Cluster: $(kubectl config current-context)   Status: $installed

  1) Install or update
  2) Status        — what is installed, and is it healthy
  3) Stop          — scale everything to zero (keeps data)
  4) Start         — restore previous replica counts
  5) Uninstall     — remove what this wizard created
  q) Quit
EOF
    prompt choice "Choose" "1"
    case "$choice" in
      1) do_install; return ;;
      2) do_status || true ;;
      3) do_stop ;;
      4) do_start ;;
      5) do_uninstall; return ;;
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
    *)
      if [ -n "${LABS64_PROFILE:-}" ]; then do_install; else main_menu; fi
      ;;
  esac
}

main "$@"

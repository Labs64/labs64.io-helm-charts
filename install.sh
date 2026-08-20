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
STOP_ANNOTATION="labs64io.install/original-replicas"

usage() {
  cat <<'USAGE'
Labs64.IO Ecosystem installer

  install.sh [--dry-run] [--version] [--help]

Interactive by default: it opens a menu (install / status / stop / start /
uninstall). Set LABS64_PROFILE=quickstart|custom to run without prompts.

Environment:
  LABS64_PROFILE              quickstart | custom — skips the menu and every prompt
  LABS64_NAMESPACE            namespace for modules and bundled infra (default: labs64io)
  LABS64_GATEWAY_NAMESPACE    namespace for Traefik and the Gateway (default: tools)
  LABS64_RELEASE              Helm release name (default: labs64io)
  LABS64_WORKDIR              where generated values/logs go (default: ./labs64io-install)
  LABS64_OIDC_DISCOVERY_URL   issuer discovery URL (required by the custom profile)
  LABS64_YES=1                accept every default without asking
USAGE
}

DRY_RUN=""
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN="--dry-run" ;;
    --version) printf 'labs64io installer %s\n' "$WIZARD_VERSION"; exit 0 ;;
    -h|--help) usage; exit 0 ;;
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

# --- lifecycle actions (filled in by later tasks) -----------------------------

do_install()   { die "install is not implemented yet"; }
do_verify()    { :; }
do_status()    { die "status is not implemented yet"; }
do_stop()      { die "stop is not implemented yet"; }
do_start()     { die "start is not implemented yet"; }
do_uninstall() { die "uninstall is not implemented yet"; }

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
  if [ -n "${LABS64_PROFILE:-}" ]; then do_install; else main_menu; fi
}

main "$@"

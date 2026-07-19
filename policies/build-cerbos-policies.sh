#!/usr/bin/env bash
# generate the Cerbos policy set + authproxy routes manifests from every
# module's OpenAPI x-labs64-auth, via the commons OpenApiAuthPreprocessor.
#
# Outputs (committed, ArgoCD-synced — this is the RFC's provenance model):
#   charts/cerbos/policies/*.yaml            resource policies (one edge + per-type domain)
#   charts/cerbos/schemas/*.json             principal + per-type JSON schemas
#   charts/traefik-authproxy/routes/*.routes.yaml   per-module routing manifests
#
# Then `cerbos compile` gates the generated set locally.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCES="$REPO/policies/policy-sources.yaml"
COMMONS_DIR="${COMMONS_DIR:-$REPO/../labs64.io-commons/auth-context-java}"
CERBOS_IMAGE="ghcr.io/cerbos/cerbos:0.51.0"

CERBOS_POLICIES="$REPO/charts/cerbos/policies"
CERBOS_SCHEMAS="$REPO/charts/cerbos/schemas"
ROUTES_OUT="$REPO/charts/traefik-authproxy/routes"

# --- commons preprocessor classpath (built jar + deps) ----------------------
[ -d "$COMMONS_DIR" ] || { echo "ERROR: commons not found at $COMMONS_DIR" >&2; exit 1; }
( cd "$COMMONS_DIR" && mvn -q package -DskipTests )
CP="$COMMONS_DIR/target/classes:$(cd "$COMMONS_DIR" && mvn -q dependency:build-classpath -Dmdep.outputFile=/dev/stdout | tail -1)"

# --- clean generated outputs (drop removed modules/ops) ---------------------
# Keep hand-authored static_api.yaml; regenerate everything else.
mkdir -p "$CERBOS_POLICIES"
find "$CERBOS_POLICIES" -maxdepth 1 -name '*.yaml' ! -name 'static_api.yaml' -delete
rm -rf "$CERBOS_SCHEMAS" "$ROUTES_OUT"
mkdir -p "$CERBOS_SCHEMAS" "$ROUTES_OUT"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- per-module generation --------------------------------------------------
python3 - "$SOURCES" <<'PY' | while IFS='|' read -r name base_path openapi; do
import sys, yaml
doc = yaml.safe_load(open(sys.argv[1]))
for m in doc["modules"]:
    print(f'{m["name"]}|{m["basePath"]}|{m["openapi"]}')
PY
  spec="$REPO/$openapi"
  echo "== generating $name from $spec"
  java -cp "$CP" io.labs64.authcontext.openapi.OpenApiAuthPreprocessorCli \
    --input "$spec" \
    --openapi-output "$TMP/$name.openapi.yaml" \
    --cerbos-output "$TMP/$name" \
    --module "$name" \
    --base-path "$base_path" \
    --routes-output "$ROUTES_OUT/$name.routes.yaml"
  cp "$TMP/$name/policies/"*.yaml "$CERBOS_POLICIES/"
  cp "$TMP/$name/policies/_schemas/"*.json "$CERBOS_SCHEMAS/"
done

# --- local gate: schemas live under policies/_schemas for cerbos compile ----
GATE="$TMP/gate"; mkdir -p "$GATE/policies/_schemas"
cp "$CERBOS_POLICIES"/*.yaml "$GATE/policies/"
cp "$CERBOS_SCHEMAS"/*.json "$GATE/policies/_schemas/"
docker run --rm -v "$GATE:/work" "$CERBOS_IMAGE" compile /work/policies
echo "== cerbos compile: PASS"

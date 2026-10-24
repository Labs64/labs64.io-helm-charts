# CLI tool versions (HELM_DOCS_VERSION, HELM_DIFF_VERSION, HELM_SCHEMA_VERSION) come from
# the workspace's single tool-versions.env. In CI the setup-k8s-tools action exports the
# same variables; a missing file is not an error, the recipes that need a value say so.
set dotenv-path := "../labs64.io-workspace/tool-versions.env"

ENV := "local"
NAMESPACE_LABS64IO := "labs64io"
NAMESPACE_KUBE_SYSTEM := "kube-system"
NAMESPACE_MONITORING := "monitoring"
NAMESPACE_TOOLS := "tools"

# Chart versions, repositories, release names and value layering all live in
# helmfile.yaml.gotmpl and nowhere else — recipes below read them from there
# (`just show-chart-version <release>`). The two CRD versions applied outside Helm (Gateway API,
# Traefik CRDs) are in justfile.versions.
import 'justfile.versions'

# List the recipes by group (from the workspace: `just helm-charts`)
default:
    @echo 'labs64.io-helm-charts: the local cluster, chart authoring and the chart gates. From the workspace: just helm-charts <recipe>'
    @just --list --unsorted --list-heading ''

# Recipes by group (docs/justfiles.md in labs64.io-workspace): one file per group, in list order.
import 'just/setup.just'
import 'just/local-stack.just'
import 'just/local-apps.just'
import 'just/local-tools.just'
import 'just/charts.just'
import 'just/quality-gates.just'
import 'just/renamed.just'

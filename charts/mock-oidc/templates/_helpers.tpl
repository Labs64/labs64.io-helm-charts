{{/*
Resource names are deliberately NOT templated with the release name. The
api-gateway chart's oidc.discoveryUrl and the umbrella's values both reference
this service as `mock-oidc.<namespace>.svc.cluster.local` by that exact string,
so a release-name-derived name would silently break the wiring for no benefit.
*/}}
{{- define "mock-oidc.name" -}}mock-oidc{{- end -}}

{{- define "mock-oidc.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{ include "mock-oidc.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "mock-oidc.selectorLabels" -}}
app.kubernetes.io/name: mock-oidc
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "mock-oidc.image" -}}
{{- printf "%s:%s" .Values.image.repository (.Values.image.tag | default .Chart.AppVersion) -}}
{{- end -}}

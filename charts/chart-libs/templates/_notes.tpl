{{/*
Post-install NOTES for a standard module chart (backend, optionally + UI). Defensive about
which blocks exist so one definition covers every module shape (API-only, UI-only, both, or
neither routed through the Gateway).
Usage (wrapper template in the module chart's templates/NOTES.txt):
{{ include "chart-libs.notes" . }}
*/}}
{{- define "chart-libs.notes" -}}
{{- $hasBackendSvc := .Values.service -}}
{{- $hasUiSvc := and .Values.ui .Values.ui.enabled .Values.ui.service -}}
{{ .Chart.Name }} {{ .Chart.Version }} has been installed as "{{ .Release.Name }}" in namespace "{{ .Release.Namespace }}".

{{- if or $hasBackendSvc $hasUiSvc }}

Reach it directly (no Gateway API needed):
{{- if $hasBackendSvc }}
  kubectl port-forward -n {{ .Release.Namespace }} svc/{{ include "chart-libs.fullname" . }} {{ .Values.service.port }}:{{ .Values.service.port }}
{{- end }}
{{- if $hasUiSvc }}
  kubectl port-forward -n {{ .Release.Namespace }} svc/{{ include "chart-libs.fullname" . }}-ui {{ .Values.ui.service.port }}:{{ .Values.ui.service.port }}
{{- end }}
{{- end }}

{{- if and .Values.gateway .Values.gateway.enabled .Values.gateway.routes }}
{{- $parent := first .Values.gateway.parentRefs }}
{{- $prefix := .Values.gateway.prefix | default (printf "/%s" .Chart.Name) }}

Gateway API routing is enabled. This chart's HTTPRoute attaches to Gateway "{{ $parent.name }}" in
namespace "{{ $parent.namespace }}" — if that Gateway doesn't exist yet, the route will report
Accepted: False and no traffic will reach this service. See the "Gateway API setup" section of
the chart repo's README to provision Traefik + the shared Gateway.

Once routed, reachable at:
{{- range $route := .Values.gateway.routes }}
{{- if not $route.redirectTo }}
  http://<gateway-host>{{ $prefix }}{{ $route.path }}{{ if not $route.public }} (protected — requires a Bearer token via the api-gateway ForwardAuth chain){{ end }}
{{- end }}
{{- end }}
{{- end }}

{{- if and .Values.ui .Values.ui.enabled .Values.ui.gateway .Values.ui.gateway.enabled }}
{{- $uiParent := first .Values.ui.gateway.parentRefs }}
{{- $uiPrefix := .Values.ui.gateway.prefix | default (printf "/%s" .Chart.Name) }}

UI Gateway API routing is enabled, attached to Gateway "{{ $uiParent.name }}" in namespace
"{{ $uiParent.namespace }}" (same prerequisite as above). Reachable at:
  http://<gateway-host>{{ $uiPrefix }}
{{- end }}

Quick smoke test:
  helm test {{ .Release.Name }} -n {{ .Release.Namespace }}
{{- end }}

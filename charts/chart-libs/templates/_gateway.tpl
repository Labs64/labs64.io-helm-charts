{{/*
Gateway host derived from global.domain (default: localhost).
Usage: {{ include "chart-libs.gatewayHost" . }}
*/}}
{{- define "chart-libs.gatewayHost" -}}
{{- $domain := "localhost" -}}
{{- if .Values.global -}}
{{- $domain = .Values.global.domain | default "localhost" -}}
{{- end -}}
{{- printf "gateway.%s" $domain -}}
{{- end }}

{{/*
Module-owned gateway routes: IngressRoute + strip-prefix Middleware +
role-mapping ConfigMap fragment for the traefik-authproxy sidecar.
Usage (wrapper template in the module chart):
{{ include "chart-libs.gateway-routes" . }}
*/}}
{{- define "chart-libs.gateway-routes" -}}
{{- if and .Values.gateway .Values.gateway.enabled }}
{{- $fullname := include "chart-libs.fullname" . -}}
{{- $prefix := .Values.gateway.prefix | default (printf "/%s" .Chart.Name) -}}
{{- $host := include "chart-libs.gatewayHost" . -}}
{{- $mw := .Values.gateway.sharedMiddlewares -}}
{{- /* Strip list order: full-path strips (stripPath) are added before the bare module prefix (stripPrefix). Traefik strips the first matching prefix. */ -}}
{{- $stripPrefixes := list -}}
{{- range .Values.gateway.routes -}}
{{- if .stripPath -}}{{- $stripPrefixes = append $stripPrefixes (printf "%s%s" $prefix .path) -}}{{- end -}}
{{- end -}}
{{- range .Values.gateway.routes -}}
{{- if and .stripPrefix (not .stripPath) -}}{{- $stripPrefixes = append $stripPrefixes $prefix -}}{{- end -}}
{{- end -}}
{{- $stripPrefixes = $stripPrefixes | uniq -}}
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: {{ $fullname }}-gateway
  labels:
    {{- include "chart-libs.labels" . | nindent 4 }}
spec:
  entryPoints:
    {{- toYaml .Values.gateway.entryPoints | nindent 4 }}
  routes:
    {{- range $route := .Values.gateway.routes }}
    - match: Host(`{{ $host }}`) && PathPrefix(`{{ $prefix }}{{ $route.path }}`)
      kind: Rule
      services:
        - name: {{ $route.service | default $fullname }}
          port: {{ $route.port }}
      middlewares:
        {{- /* Always first: drop inbound X-Auth-* so clients can never smuggle
               identity headers to backends (RFC-03 edge stripping) — public
               routes included, where no ForwardAuth would overwrite them. */}}
        - name: {{ $mw.stripAuthHeaders | default "gateway-common-strip-auth-headers" }}
        {{- if not $route.public }}
        - name: {{ $mw.auth }}
        - name: {{ $mw.rateLimit }}
        {{- end }}
        - name: {{ $mw.securityHeaders }}
        {{- if $mw.compress }}
        - name: {{ $mw.compress }}
        {{- end }}
        {{- if or $route.stripPrefix $route.stripPath }}
        - name: {{ $fullname }}-strip-prefix
        {{- end }}
    {{- end }}
{{- if $stripPrefixes }}
---
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: {{ $fullname }}-strip-prefix
  labels:
    {{- include "chart-libs.labels" . | nindent 4 }}
spec:
  stripPrefix:
    prefixes:
      {{- range $stripPrefixes }}
      - {{ . }}
      {{- end }}
{{- end }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ $fullname }}-role-mapping-fragment
  labels:
    {{- include "chart-libs.labels" . | nindent 4 }}
    labs64.io/role-mapping: "true"
data:
  {{ $fullname }}.yaml: |
    {{- range $route := .Values.gateway.routes }}
    {{ $prefix }}{{ $route.path }}: {{ default (list) $route.roles | toJson }}
    {{- end }}
{{- end }}
{{- end }}

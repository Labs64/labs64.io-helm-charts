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
Module-owned gateway routes: IngressRoute + strip-prefix Middleware.
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
               identity headers to backends — public
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
{{- end }}
{{- end }}

{{/*
Auth-policy discovery metadata for the module Service. The traefik-authproxy
watches Services carrying the label and fetches
http://<svc>.<ns>:<port>/.well-known/auth-policy, prefixing every OpenAPI
route with the base-path annotation.
Usage in a module chart's service.yaml:
  labels:
    {{- include "chart-libs.labels" . | nindent 4 }}
    {{- with (include "chart-libs.authPolicyLabels" .) }}{{ . | nindent 4 }}{{- end }}
  {{- with (include "chart-libs.authPolicyAnnotations" .) }}
  annotations:
    {{- . | nindent 4 }}
  {{- end }}
*/}}
{{- define "chart-libs.authPolicyEnabled" -}}
{{- if and .Values.gateway .Values.gateway.enabled .Values.gateway.authPolicy .Values.gateway.authPolicy.enabled -}}true{{- end -}}
{{- end }}

{{- define "chart-libs.authPolicyLabels" -}}
{{- if include "chart-libs.authPolicyEnabled" . }}
labs64.io/auth-policy: "true"
{{- end }}
{{- end }}

{{- define "chart-libs.authPolicyAnnotations" -}}
{{- if include "chart-libs.authPolicyEnabled" . }}
{{- $prefix := .Values.gateway.prefix | default (printf "/%s" .Chart.Name) }}
labs64.io/auth-policy-base-path: {{ .Values.gateway.authPolicy.basePath | default (printf "%s/api/v1" $prefix) | quote }}
labs64.io/auth-policy-port: {{ .Values.service.port | quote }}
{{- end }}
{{- end }}

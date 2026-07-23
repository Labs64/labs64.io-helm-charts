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
Module-owned Gateway API routes: one HTTPRoute with native filters
(RequestHeaderModifier / ResponseHeaderModifier / URLRewrite) plus Traefik
ExtensionRef filters for ForwardAuth, rate-limit, and compress (no native
Gateway API primitive exists for those three).
Usage (wrapper template in the module chart):
{{ include "chart-libs.gateway-routes" . }}
*/}}
{{- define "chart-libs.gateway-routes" -}}
{{- if and .Values.gateway .Values.gateway.enabled }}
{{- $fullname := include "chart-libs.fullname" . -}}
{{- $prefix := .Values.gateway.prefix | default (printf "/%s" .Chart.Name) -}}
{{- $host := include "chart-libs.gatewayHost" . -}}
{{- $mw := .Values.gateway.sharedMiddlewares -}}
{{- if .Capabilities.APIVersions.Has "gateway.networking.k8s.io/v1" }}
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: {{ $fullname }}-gateway
  labels:
    {{- include "chart-libs.labels" . | nindent 4 }}
spec:
  parentRefs:
    {{- toYaml .Values.gateway.parentRefs | nindent 4 }}
  hostnames:
    - {{ $host | quote }}
  rules:
    {{- range $route := .Values.gateway.routes }}
    - matches:
        - path:
            type: PathPrefix
            value: {{ printf "%s%s" $prefix $route.path | default "/" | quote }}
      filters:
        {{- /* 1. ALWAYS FIRST: strip inbound X-Auth-* so clients can never smuggle
               identity headers — native RequestHeaderModifier, public routes included. */}}
        {{- /* Root convenience redirect: 302 to a fixed path (native RequestRedirect). */}}
        {{- if $route.redirectTo }}
        - type: RequestRedirect
          requestRedirect:
            path:
              type: ReplaceFullPath
              replaceFullPath: {{ $route.redirectTo | quote }}
            statusCode: 302
        {{- end }}
        - type: RequestHeaderModifier
          requestHeaderModifier:
            remove:
              - X-Auth-User
              - X-Auth-Scopes
              - X-Auth-Tenant
        {{- if not $route.public }}
        {{- /* 2. ForwardAuth + rate-limit: no native primitive → Traefik ExtensionRef. */}}
        - type: ExtensionRef
          extensionRef:
            group: traefik.io
            kind: Middleware
            name: {{ $mw.auth }}
        - type: ExtensionRef
          extensionRef:
            group: traefik.io
            kind: Middleware
            name: {{ $mw.rateLimit }}
        {{- end }}
        {{- /* 2.5 Buffering: prevent large payload attacks */}}
        {{- if $mw.buffering }}
        - type: ExtensionRef
          extensionRef:
            group: traefik.io
            kind: Middleware
            name: {{ $mw.buffering }}
        {{- end }}
        {{- /* 3. Security headers — native ResponseHeaderModifier. */}}
        - type: ResponseHeaderModifier
          responseHeaderModifier:
            set:
              {{- include "chart-libs.securityHeaders" $ | nindent 14 }}
        {{- /* 4. Response compression: no native primitive → Traefik ExtensionRef. */}}
        {{- if $mw.compress }}
        - type: ExtensionRef
          extensionRef:
            group: traefik.io
            kind: Middleware
            name: {{ $mw.compress }}
        {{- end }}
        {{- /* 5. Path rewrite — native URLRewrite. ReplacePrefixMatch replaces the
               whole matched PathPrefix: stripPath -> "/", stripPrefix -> route path. */}}
        {{- if $route.stripPath }}
        - type: URLRewrite
          urlRewrite:
            path:
              type: ReplacePrefixMatch
              replacePrefixMatch: /
        {{- else if $route.stripPrefix }}
        - type: URLRewrite
          urlRewrite:
            path:
              type: ReplacePrefixMatch
              replacePrefixMatch: {{ $route.path | default "/" | quote }}
        {{- end }}
      {{- if not $route.redirectTo }}
      backendRefs:
        - name: {{ $route.service | default $fullname }}
          port: {{ $route.port }}
      {{- end }}
    {{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Security response headers as a Gateway API ResponseHeaderModifier `set` list.
Canonical source (replaces the removed gateway-common security-headers Middleware).
Values mirror the prior Traefik headers-middleware semantics 1:1.
Usage: {{ include "chart-libs.securityHeaders" . | nindent N }}
*/}}
{{- define "chart-libs.securityHeaders" -}}
- name: X-Frame-Options
  value: DENY
- name: X-Content-Type-Options
  value: nosniff
- name: X-XSS-Protection
  value: "1; mode=block"
- name: Referrer-Policy
  value: strict-origin-when-cross-origin
- name: Content-Security-Policy
  value: "default-src 'self'; script-src 'self'; object-src 'none'"
- name: Strict-Transport-Security
  value: "max-age=31536000; includeSubDomains"
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

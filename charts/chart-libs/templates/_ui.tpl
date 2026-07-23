{{/*
UI Deployment macro. Usage: {{ include "chart-libs.ui-deployment" . }}
*/}}
{{- define "chart-libs.ui-deployment" -}}
{{- if and .Values.ui .Values.ui.enabled }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "chart-libs.fullname" . }}-ui
  labels:
    helm.sh/chart: {{ include "chart-libs.chart" . }}
    app.kubernetes.io/name: {{ include "chart-libs.name" . }}-ui
    app.kubernetes.io/instance: {{ .Release.Name }}
    {{- if .Chart.AppVersion }}
    app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
    {{- end }}
    app.kubernetes.io/managed-by: {{ .Release.Service }}
    app.kubernetes.io/part-of: "Labs64.IO"
    app.kubernetes.io/component: ui
spec:
  {{- if not (and .Values.ui.autoscaling .Values.ui.autoscaling.enabled) }}
  replicas: {{ .Values.ui.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      app.kubernetes.io/name: {{ include "chart-libs.name" . }}-ui
      app.kubernetes.io/instance: {{ .Release.Name }}
  template:
    metadata:
      {{- with .Values.ui.podAnnotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      labels:
        helm.sh/chart: {{ include "chart-libs.chart" . }}
        app.kubernetes.io/name: {{ include "chart-libs.name" . }}-ui
        app.kubernetes.io/instance: {{ .Release.Name }}
        {{- if .Chart.AppVersion }}
        app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
        {{- end }}
        app.kubernetes.io/managed-by: {{ .Release.Service }}
        app.kubernetes.io/part-of: "Labs64.IO"
        app.kubernetes.io/component: ui
        {{- with .Values.ui.podLabels }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
    spec:
      {{- with .Values.ui.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "chart-libs.ui-serviceAccountName" . }}
      terminationGracePeriodSeconds: {{ .Values.ui.terminationGracePeriodSeconds | default 30 }}
      {{- with .Values.ui.podSecurityContext }}
      securityContext:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      containers:
        - name: {{ .Chart.Name }}-ui
          {{- with .Values.ui.securityContext }}
          securityContext:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          image: "{{ .Values.ui.image.repository }}:{{ .Values.ui.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.ui.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.ui.service.port }}
              protocol: TCP
          {{- include "chart-libs.preStopDrain" . | nindent 10 }}
          {{- include "chart-libs.startupProbe" . | nindent 10 }}
          {{- with .Values.ui.livenessProbe }}
          livenessProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.ui.readinessProbe }}
          readinessProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- if .Values.ui.resources }}
          resources:
            {{- toYaml .Values.ui.resources | nindent 12 }}
          {{- else }}
          {{- include "chart-libs.defaultResources" . | nindent 10 }}
          {{- end }}
          env:
          {{- with .Values.ui.env }}
            {{- toYaml . | nindent 12 }}
          {{- end }}
          envFrom:
            - configMapRef:
                name: {{ include "chart-libs.fullname" . }}-ui
            - secretRef:
                name: {{ include "chart-libs.fullname" . }}-ui
          volumeMounts:
          {{- if and .Values.ui.application .Values.ui.application.runtimeEnv .Values.ui.application.runtimeEnv.enabled }}
            - name: runtime-env
              mountPath: {{ .Values.ui.application.runtimeEnv.path }}
              subPath: env.json
          {{- end }}
          {{- with .Values.ui.volumeMounts }}
            {{- toYaml . | nindent 12 }}
          {{- end }}
      volumes:
      {{- if and .Values.ui.application .Values.ui.application.runtimeEnv .Values.ui.application.runtimeEnv.enabled }}
        - name: runtime-env
          configMap:
            name: {{ include "chart-libs.fullname" . }}-ui-runtime-env
            optional: {{ not .Values.ui.application.runtimeEnv.strict }}
      {{- end }}
      {{- with .Values.ui.volumes }}
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.ui.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.ui.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.ui.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
{{- end }}
{{- end }}

{{/*
UI Service macro. Usage: {{ include "chart-libs.ui-service" . }}
*/}}
{{- define "chart-libs.ui-service" -}}
{{- if and .Values.ui .Values.ui.enabled }}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "chart-libs.fullname" . }}-ui
  labels:
    helm.sh/chart: {{ include "chart-libs.chart" . }}
    app.kubernetes.io/name: {{ include "chart-libs.name" . }}-ui
    app.kubernetes.io/instance: {{ .Release.Name }}
    {{- if .Chart.AppVersion }}
    app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
    {{- end }}
    app.kubernetes.io/managed-by: {{ .Release.Service }}
    app.kubernetes.io/part-of: "Labs64.IO"
    app.kubernetes.io/component: ui
spec:
  type: {{ .Values.ui.service.type }}
  ports:
    - port: {{ .Values.ui.service.port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    app.kubernetes.io/name: {{ include "chart-libs.name" . }}-ui
    app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
{{- end }}

{{/*
UI ConfigMap macro. Usage: {{ include "chart-libs.ui-configmap" . }}
*/}}
{{- define "chart-libs.ui-configmap" -}}
{{- if and .Values.ui .Values.ui.enabled }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "chart-libs.fullname" . }}-ui
  labels:
    helm.sh/chart: {{ include "chart-libs.chart" . }}
    app.kubernetes.io/name: {{ include "chart-libs.name" . }}-ui
    app.kubernetes.io/instance: {{ .Release.Name }}
    {{- if .Chart.AppVersion }}
    app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
    {{- end }}
    app.kubernetes.io/managed-by: {{ .Release.Service }}
    app.kubernetes.io/part-of: "Labs64.IO"
    app.kubernetes.io/component: ui
data:
{{- if and .Values.ui.application .Values.ui.application.runtimeEnv .Values.ui.application.runtimeEnv.enabled }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "chart-libs.fullname" . }}-ui-runtime-env
data:
  env.json: |-
    {{ include "chart-libs.envjson" (dict "env" .Values.ui.application.runtimeEnv.env) | nindent 4 }}
{{- end }}
{{- end }}
{{- end }}

{{/*
UI NetworkPolicy macro. Independent of chart-libs.networkpolicy (not a passthrough) —
that macro's podSelector/name resolve to the *backend* workload, so calling it here
produced an exact duplicate of the backend's NetworkPolicy (same name, same
backend-pod selector) while leaving the actual UI pod with no NetworkPolicy at all
(default-allow egress). Scoped to .Values.ui.networkPolicy; the UI is a static
frontend with no broker/database/PDP dependency of its own, so egress is DNS
(+ optional OTLP) only, no toolsEgress.
*/}}
{{- define "chart-libs.ui-networkpolicy" -}}
{{- if and .Values.ui .Values.ui.enabled .Values.ui.networkPolicy .Values.ui.networkPolicy.enabled }}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ include "chart-libs.fullname" . }}-ui
  labels:
    helm.sh/chart: {{ include "chart-libs.chart" . }}
    app.kubernetes.io/name: {{ include "chart-libs.name" . }}-ui
    app.kubernetes.io/instance: {{ .Release.Name }}
    {{- if .Chart.AppVersion }}
    app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
    {{- end }}
    app.kubernetes.io/managed-by: {{ .Release.Service }}
    app.kubernetes.io/part-of: "Labs64.IO"
    app.kubernetes.io/component: ui
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: {{ include "chart-libs.name" . }}-ui
      app.kubernetes.io/instance: {{ .Release.Name }}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: {{ .Values.ui.networkPolicy.gatewayNamespace | default "tools" }}
          podSelector:
            matchLabels:
              app.kubernetes.io/name: traefik
        - podSelector: {}
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: monitoring
      ports:
        - protocol: TCP
          port: {{ .Values.ui.service.port }}
    {{- with .Values.ui.networkPolicy.extraIngress }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  egress:
    # DNS
    - to:
        - namespaceSelector: {}
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
    {{- if and .Values.observability .Values.observability.enabled }}
    # OTLP export to the OpenTelemetry Collector (traces/logs)
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: monitoring
      ports:
        - protocol: TCP
          port: 4317
        - protocol: TCP
          port: 4318
    {{- end }}
    {{- if .Values.ui.networkPolicy.egress }}
    {{- toYaml .Values.ui.networkPolicy.egress | nindent 4 }}
    {{- end }}
{{- end }}
{{- end }}

{{/*
UI Gateway Routes macro. Independent of chart-libs.gateway-routes (not a passthrough)
— that macro's HTTPRoute name and backendRefs resolve to the *backend* workload/values
(.Values.gateway), so calling it here produced an exact duplicate of the backend's
HTTPRoute (same name, same backend Service target) while the UI Service was never
actually exposed. Scoped to .Values.ui.gateway, named "<fullname>-ui-gateway", and
backendRefs default to the UI Service ("<fullname>-ui").
*/}}
{{- define "chart-libs.ui-gateway-routes" -}}
{{- if and .Values.ui .Values.ui.enabled .Values.ui.gateway .Values.ui.gateway.enabled }}
{{- $fullname := include "chart-libs.fullname" . -}}
{{- $uiFullname := printf "%s-ui" $fullname -}}
{{- $prefix := .Values.ui.gateway.prefix | default (printf "/%s" .Chart.Name) -}}
{{- $host := include "chart-libs.gatewayHost" . -}}
{{- $mw := .Values.ui.gateway.sharedMiddlewares -}}
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: {{ $fullname }}-ui-gateway
  labels:
    helm.sh/chart: {{ include "chart-libs.chart" . }}
    app.kubernetes.io/name: {{ include "chart-libs.name" . }}-ui
    app.kubernetes.io/instance: {{ .Release.Name }}
    {{- if .Chart.AppVersion }}
    app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
    {{- end }}
    app.kubernetes.io/managed-by: {{ .Release.Service }}
    app.kubernetes.io/part-of: "Labs64.IO"
    app.kubernetes.io/component: ui
spec:
  parentRefs:
    {{- toYaml .Values.ui.gateway.parentRefs | nindent 4 }}
  hostnames:
    - {{ $host | quote }}
  rules:
    {{- range $route := .Values.ui.gateway.routes }}
    - matches:
        - path:
            type: PathPrefix
            value: {{ printf "%s%s" $prefix $route.path | default "/" | quote }}
      filters:
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
        {{- if $mw.buffering }}
        - type: ExtensionRef
          extensionRef:
            group: traefik.io
            kind: Middleware
            name: {{ $mw.buffering }}
        {{- end }}
        - type: ResponseHeaderModifier
          responseHeaderModifier:
            set:
              {{- include "chart-libs.securityHeaders" $ | nindent 14 }}
        {{- if $mw.compress }}
        - type: ExtensionRef
          extensionRef:
            group: traefik.io
            kind: Middleware
            name: {{ $mw.compress }}
        {{- end }}
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
        - name: {{ $route.service | default $uiFullname }}
          port: {{ $route.port }}
      {{- end }}
    {{- end }}
{{- end }}
{{- end }}

{{/*
UI Secret macro. Always renders (like chart-libs.secret does for the backend) whenever
the UI is enabled — the UI Deployment's envFrom.secretRef references this object
unconditionally, so it must exist even with empty stringData when .Values.ui.secrets
is unset.
*/}}
{{- define "chart-libs.ui-secret" -}}
{{- if and .Values.ui .Values.ui.enabled }}
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "chart-libs.fullname" . }}-ui
  labels:
    helm.sh/chart: {{ include "chart-libs.chart" . }}
    app.kubernetes.io/name: {{ include "chart-libs.name" . }}-ui
    app.kubernetes.io/instance: {{ .Release.Name }}
    {{- if .Chart.AppVersion }}
    app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
    {{- end }}
    app.kubernetes.io/managed-by: {{ .Release.Service }}
    app.kubernetes.io/part-of: "Labs64.IO"
    app.kubernetes.io/component: ui
type: Opaque
stringData:
{{- if and .Values.ui.secrets .Values.ui.secrets.data }}
{{- range $key, $value := .Values.ui.secrets.data }}
  {{ $key }}: {{ $value | quote }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/*
UI PodDisruptionBudget macro.
*/}}
{{- define "chart-libs.ui-pdb" -}}
{{- if and .Values.ui .Values.ui.enabled }}
{{ include "chart-libs.pdb" . }}
{{- end }}
{{- end }}

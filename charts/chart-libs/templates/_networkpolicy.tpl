{{/*
NetworkPolicy: allow ingress from Traefik (gateway namespace), same-namespace
pods and the observability namespace (metrics scrape). Two optional values narrow the
first rule, which otherwise admits every pod of the namespace on every port:
.Values.networkPolicy.ingressPorts limits it to the listed TCP ports (sidecar and
other container ports are then closed to the pod network), and
.Values.networkPolicy.ingressFrom replaces "every pod in the namespace" with the
ingress controller, the chart's own pods (the helm test hook carries their labels)
and the listed app.kubernetes.io/name values. Egress is restricted to DNS,
the observability namespace (OTLP, when observability is enabled), specific tools-namespace destinations declared via
.Values.networkPolicy.toolsEgress (name + port pairs — NOT a blanket allow to the
whole tools namespace, to preserve database-per-service isolation), and any
base destinations listed in .Values.networkPolicy.egress plus chart/environment-specific
rules in .Values.networkPolicy.extraEgress.
The observability namespace is .Values.networkPolicy.observabilityNamespace
(default "monitoring") and is used for both the scrape ingress and the OTLP egress.
Usage: {{ include "chart-libs.networkpolicy" . }}
*/}}
{{- define "chart-libs.networkpolicy" -}}
{{- if and .Values.networkPolicy .Values.networkPolicy.enabled }}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ include "chart-libs.fullname" . }}
  labels:
    {{- include "chart-libs.labels" . | nindent 4 }}
spec:
  podSelector:
    matchLabels:
      {{- include "chart-libs.selectorLabels" . | nindent 6 }}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: {{ .Values.networkPolicy.gatewayNamespace | default "tools" }}
          podSelector:
            matchLabels:
              {{- if .Values.networkPolicy.ingressControllerLabels }}
              {{- toYaml .Values.networkPolicy.ingressControllerLabels | nindent 14 }}
              {{- else }}
              app.kubernetes.io/name: traefik
              {{- end }}
        {{- if .Values.networkPolicy.ingressFrom }}
        {{- /* The ingress controller may also run in the release namespace (umbrella install). */}}
        - podSelector:
            matchLabels:
              {{- if .Values.networkPolicy.ingressControllerLabels }}
              {{- toYaml .Values.networkPolicy.ingressControllerLabels | nindent 14 }}
              {{- else }}
              app.kubernetes.io/name: traefik
              {{- end }}
        - podSelector:
            matchLabels:
              {{- include "chart-libs.selectorLabels" . | nindent 14 }}
        {{- range .Values.networkPolicy.ingressFrom }}
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: {{ . }}
        {{- end }}
        {{- else }}
        - podSelector: {}
        {{- end }}
      {{- with .Values.networkPolicy.ingressPorts }}
      ports:
        {{- range . }}
        - protocol: TCP
          port: {{ . }}
        {{- end }}
      {{- end }}
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: {{ .Values.networkPolicy.observabilityNamespace | default "monitoring" }}
      ports:
        - protocol: TCP
          port: {{ .Values.service.port }}
    {{- with .Values.networkPolicy.extraIngress }}
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
    {{- range .Values.networkPolicy.toolsEgress }}
    # {{ .name }} (tools namespace)
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: {{ $.Values.networkPolicy.gatewayNamespace | default "tools" }}
          podSelector:
            matchLabels:
              app.kubernetes.io/name: {{ .name }}
      ports:
        - protocol: {{ .protocol | default "TCP" }}
          port: {{ .port }}
    {{- end }}
    {{- if and .Values.observability .Values.observability.enabled }}
    # OTLP export to the OpenTelemetry Collector (traces/logs)
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: {{ .Values.networkPolicy.observabilityNamespace | default "monitoring" }}
      ports:
        - protocol: TCP
          port: 4317
        - protocol: TCP
          port: 4318
    {{- end }}
    {{- if .Values.networkPolicy.egress }}
    {{- toYaml .Values.networkPolicy.egress | nindent 4 }}
    {{- end }}
    {{- with .Values.networkPolicy.extraEgress }}
    # Additional chart-specific egress rules
    {{- toYaml . | nindent 4 }}
    {{- end }}
{{- end }}
{{- end }}

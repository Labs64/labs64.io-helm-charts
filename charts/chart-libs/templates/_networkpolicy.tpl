{{/*
NetworkPolicy: allow ingress from Traefik (gateway namespace) and same-namespace
pods. Egress is restricted to DNS, the monitoring namespace (OTLP, when
observability is enabled), specific tools-namespace destinations declared via
.Values.networkPolicy.toolsEgress (name + port pairs — NOT a blanket allow to the
whole tools namespace, to preserve database-per-service isolation), and any
additional destinations listed in .Values.networkPolicy.egress.
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
              app.kubernetes.io/name: traefik
        - podSelector: {}
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: monitoring
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
              kubernetes.io/metadata.name: monitoring
      ports:
        - protocol: TCP
          port: 4317
        - protocol: TCP
          port: 4318
    {{- end }}
    {{- if .Values.networkPolicy.egress }}
    {{- toYaml .Values.networkPolicy.egress | nindent 4 }}
    {{- end }}
{{- end }}
{{- end }}

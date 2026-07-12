{{/*
NetworkPolicy: allow ingress from Traefik (gateway namespace) and same-namespace
pods. When .Values.networkPolicy.egress is set, also restricts egress to the
listed destinations plus DNS. Egress rules are passed through as-is from values.
When observability is enabled, egress to the OpenTelemetry Collector (monitoring
namespace, OTLP 4317/4318) is added automatically so locking down egress never
silently breaks telemetry.
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
    {{- if .Values.networkPolicy.egress }}
    - Egress
    {{- end }}
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
  {{- if .Values.networkPolicy.egress }}
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
    {{- toYaml .Values.networkPolicy.egress | nindent 4 }}
  {{- end }}
{{- end }}
{{- end }}

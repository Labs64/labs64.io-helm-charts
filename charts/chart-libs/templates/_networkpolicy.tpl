{{/*
NetworkPolicy: allow ingress only from Traefik (gateway namespace) and
same-namespace pods. Usage: {{ include "chart-libs.networkpolicy" . }}
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
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: {{ .Values.networkPolicy.gatewayNamespace | default "tools" }}
          podSelector:
            matchLabels:
              app.kubernetes.io/name: traefik
        - podSelector: {}
    {{- with .Values.networkPolicy.extraIngress }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
{{- end }}
{{- end }}

{{/*
Grafana Dashboard ConfigMap: SLO panels for availability and latency.
Generated if `.Values.slo.enabled` is true.
*/}}
{{- define "chart-libs.slo.grafanadashboard" -}}
{{- if and .Values.slo .Values.slo.enabled }}
{{- $svc := include "chart-libs.name" . }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "chart-libs.fullname" . }}-slo-dashboard
  labels:
    {{- include "chart-libs.labels" . | nindent 4 }}
    grafana_dashboard: "1"
data:
  dashboard.json: |
    {
      "title": "{{ include "chart-libs.fullname" . }} SLOs",
      "panels": [
        {
          "title": "Availability SLO (Target: {{ mul 100 (.Values.slo.availability.targetRatio | default "0.999") }}%)",
          "type": "stat",
          "datasource": "Prometheus",
          "targets": [
            {
              "expr": "slo:availability:ratio_rate5m{job=\"{{ $svc }}\"}",
              "refId": "A"
            }
          ]
        },
        {
          "title": "Latency SLO (<{{ .Values.slo.latency.thresholdSeconds | default "0.5" }}s, Target: {{ mul 100 (.Values.slo.latency.targetRatio | default "0.99") }}%)",
          "type": "stat",
          "datasource": "Prometheus",
          "targets": [
            {
              "expr": "slo:latency:ratio_rate5m{job=\"{{ $svc }}\"}",
              "refId": "A"
            }
          ]
        }
      ]
    }
{{- end }}
{{- end }}

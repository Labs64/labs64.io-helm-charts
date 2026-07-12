{{/*
Grafana Dashboard ConfigMap: SLO panels for availability and latency,
plus module-specific Traefik metrics (request rate, latency, errors).
Generated if `.Values.slo.enabled` is true.
*/}}
{{- define "chart-libs.slo.grafanadashboard" -}}
{{- if and .Values.slo .Values.slo.enabled }}
{{- /* Match the collector's "<namespace>/<service.name>" job label (see _prometheusrule.tpl). */ -}}
{{- $svc := printf "%s/%s" .Release.Namespace (include "chart-libs.name" .) }}
{{- $svcName := include "chart-libs.name" . }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "chart-libs.fullname" . }}-slo-dashboard
  labels:
    {{- include "chart-libs.labels" . | nindent 4 }}
    grafana_dashboard: "1"
data:
  {{ include "chart-libs.name" . }}.json: |
    {
      "title": "{{ .Values.slo.dashboardTitle | default (printf "Labs64.IO %s" (replace "-" " " .Chart.Name | title)) }}",
      "description": "SLO metrics and module-specific traffic for {{ .Chart.Name }}",
      "tags": ["slo", "{{ .Chart.Name }}"],
      "timezone": "browser",
      "editable": true,
      "refresh": "30s",
      "time": { "from": "now-1h", "to": "now" },
      "panels": [
        {
          "id": 1,
          "title": "Availability SLO (Target: {{ mul 100 (.Values.slo.availability.targetRatio | default "0.999") }}%)",
          "type": "stat",
          "datasource": { "type": "prometheus", "uid": "Prometheus" },
          "gridPos": { "h": 6, "w": 6, "x": 0, "y": 0 },
          "fieldConfig": {
            "defaults": {
              "unit": "percentunit",
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  { "color": "red", "value": null },
                  { "color": "yellow", "value": 0.99 },
                  { "color": "green", "value": 0.999 }
                ]
              }
            }
          },
          "targets": [
            {
              "expr": "slo:availability:ratio_rate5m{job=\"{{ $svc }}\"}",
              "refId": "A"
            }
          ]
        },
        {
          "id": 2,
          "title": "Latency SLO (<{{ .Values.slo.latency.thresholdSeconds | default "0.5" }}s, Target: {{ mul 100 (.Values.slo.latency.targetRatio | default "0.99") }}%)",
          "type": "stat",
          "datasource": { "type": "prometheus", "uid": "Prometheus" },
          "gridPos": { "h": 6, "w": 6, "x": 6, "y": 0 },
          "fieldConfig": {
            "defaults": {
              "unit": "percentunit",
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  { "color": "red", "value": null },
                  { "color": "yellow", "value": 0.95 },
                  { "color": "green", "value": 0.99 }
                ]
              }
            }
          },
          "targets": [
            {
              "expr": "slo:latency:ratio_rate5m{job=\"{{ $svc }}\"}",
              "refId": "A"
            }
          ]
        },
        {
          "id": 3,
          "title": "Request Rate by Status",
          "type": "timeseries",
          "datasource": { "type": "prometheus", "uid": "Prometheus" },
          "gridPos": { "h": 8, "w": 12, "x": 0, "y": 6 },
          "fieldConfig": {
            "defaults": {
              "custom": { "drawStyle": "line", "lineWidth": 2, "fillOpacity": 10 },
              "unit": "reqps"
            },
            "overrides": [
              { "matcher": { "id": "byRegexp", "options": "^2" }, "properties": [{ "id": "color", "value": { "fixedColor": "green", "mode": "fixed" } }] },
              { "matcher": { "id": "byRegexp", "options": "^4" }, "properties": [{ "id": "color", "value": { "fixedColor": "orange", "mode": "fixed" } }] },
              { "matcher": { "id": "byRegexp", "options": "^5" }, "properties": [{ "id": "color", "value": { "fixedColor": "red", "mode": "fixed" } }] }
            ]
          },
          "targets": [
            {
              "expr": "sum(rate(traefik_service_requests_total{service=~\".*{{ $svcName }}.*\"}[5m])) by (code)",
              "legendFormat": "{{`{{code}}`}}",
              "refId": "A"
            }
          ]
        },
        {
          "id": 4,
          "title": "Response Latency (p95/p50)",
          "type": "timeseries",
          "datasource": { "type": "prometheus", "uid": "Prometheus" },
          "gridPos": { "h": 8, "w": 12, "x": 12, "y": 6 },
          "fieldConfig": {
            "defaults": {
              "custom": { "drawStyle": "line", "lineWidth": 2, "fillOpacity": 10 },
              "unit": "s"
            }
          },
          "targets": [
            {
              "expr": "histogram_quantile(0.95, sum(rate(traefik_service_request_duration_seconds_bucket{service=~\".*{{ $svcName }}.*\"}[5m])) by (le))",
              "legendFormat": "p95",
              "refId": "A"
            },
            {
              "expr": "histogram_quantile(0.50, sum(rate(traefik_service_request_duration_seconds_bucket{service=~\".*{{ $svcName }}.*\"}[5m])) by (le))",
              "legendFormat": "p50",
              "refId": "B"
            }
          ]
        },
        {
          "id": 5,
          "title": "Error Rate (4xx/5xx)",
          "type": "timeseries",
          "datasource": { "type": "prometheus", "uid": "Prometheus" },
          "gridPos": { "h": 8, "w": 12, "x": 0, "y": 14 },
          "fieldConfig": {
            "defaults": {
              "custom": { "drawStyle": "bars", "lineWidth": 1, "fillOpacity": 50 },
              "unit": "reqps"
            },
            "overrides": [
              { "matcher": { "id": "byRegexp", "options": "^4" }, "properties": [{ "id": "color", "value": { "fixedColor": "orange", "mode": "fixed" } }] },
              { "matcher": { "id": "byRegexp", "options": "^5" }, "properties": [{ "id": "color", "value": { "fixedColor": "red", "mode": "fixed" } }] }
            ]
          },
          "targets": [
            {
              "expr": "sum(rate(traefik_service_requests_total{service=~\".*{{ $svcName }}.*\", code=~\"4..|5..\"}[5m])) by (code)",
              "legendFormat": "{{`{{code}}`}}",
              "refId": "A"
            }
          ]
        },
        {
          "id": 6,
          "title": "Request Volume by Method",
          "type": "piechart",
          "datasource": { "type": "prometheus", "uid": "Prometheus" },
          "gridPos": { "h": 8, "w": 12, "x": 12, "y": 14 },
          "targets": [
            {
              "expr": "sum(rate(traefik_service_requests_total{service=~\".*{{ $svcName }}.*\"}[5m])) by (method)",
              "legendFormat": "{{`{{method}}`}}",
              "refId": "A"
            }
          ]
        }
      ],
      "schemaVersion": 39
    }
{{- end }}
{{- end }}

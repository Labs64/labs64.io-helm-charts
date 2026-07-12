{{/*
PrometheusRule: SLO recording rules and alerts based on error budgets.
Generated if `.Values.slo.enabled` is true.

The `job` label is the stable service name (chart-libs.name == the pod's
app.kubernetes.io/name). The OTel Collector's kubernetes-pods scrape must
relabel `job` to that same value (see overrides/opentelemetry). Recording
rules use `sum by (job)` so the recorded series keep the `job` label the
Grafana dashboard filters on.
*/}}
{{- define "chart-libs.slo.prometheusrule" -}}
{{- /* Only render when SLOs are enabled AND the PrometheusRule CRD exists, so
       installing apps before the monitoring stack (e.g. `just up`) never fails
       on an unknown kind. */ -}}
{{- if and .Values.slo .Values.slo.enabled (.Capabilities.APIVersions.Has "monitoring.coreos.com/v1/PrometheusRule") }}
{{- /* The OTel Collector's prometheusremotewrite exporter emits `job` as
       "<namespace>/<service.name>", so the SLO selector must match that form.
       chart-libs.name == the pod's app.kubernetes.io/name (relabeled to the
       service part by the collector's kubernetes-pods scrape). */ -}}
{{- $svc := printf "%s/%s" .Release.Namespace (include "chart-libs.name" .) }}
{{- $le := .Values.slo.latency.thresholdSeconds | default "0.5" }}
{{- $availTarget := .Values.slo.availability.targetRatio | default "0.999" }}
{{- $latTarget := .Values.slo.latency.targetRatio | default "0.99" }}
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: {{ include "chart-libs.fullname" . }}-slo
  labels:
    {{- include "chart-libs.labels" . | nindent 4 }}
spec:
  groups:
    - name: {{ include "chart-libs.fullname" . }}-slo
      rules:
        # Availability recording rule (Micrometer: http_server_requests_seconds_count)
        - record: slo:availability:ratio_rate5m
          expr: |
            sum by (job) (rate(http_server_requests_seconds_count{job="{{ $svc }}", status!~"5.."}[5m]))
            /
            sum by (job) (rate(http_server_requests_seconds_count{job="{{ $svc }}"}[5m]))

        # Latency recording rule (Micrometer: http_server_requests_seconds_bucket).
        # Requires an le="{{ $le }}" histogram bucket — services set
        # management.metrics.distribution.slo.http.server.requests accordingly.
        - record: slo:latency:ratio_rate5m
          expr: |
            sum by (job) (rate(http_server_requests_seconds_bucket{job="{{ $svc }}", le="{{ $le }}"}[5m]))
            /
            sum by (job) (rate(http_server_requests_seconds_count{job="{{ $svc }}"}[5m]))

        # Alerting rules (scoped to this service's job)
        - alert: AvailabilitySLOViolation
          expr: slo:availability:ratio_rate5m{job="{{ $svc }}"} < {{ $availTarget }}
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: Availability SLO violated for {{ $svc }}
            description: "Availability ratio has been below the target ({{ $availTarget }}) for 5 minutes."

        - alert: LatencySLOViolation
          expr: slo:latency:ratio_rate5m{job="{{ $svc }}"} < {{ $latTarget }}
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: Latency SLO violated for {{ $svc }}
            description: "Less than {{ $latTarget }} of requests are completing within {{ $le }}s for the last 5 minutes."
{{- end }}
{{- end }}

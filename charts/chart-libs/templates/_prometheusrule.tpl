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

        # Alerting rules (scoped to this service's job). The block below is evaluated word for word, but
        # for the job and the targets, by the managed Prometheus of the Labs64.IO environments as well; a
        # check there fails when the two differ, so change both together.
        # slo-burn-rate: begin
        # Error-budget burn rates over a 30-day SLO (multiwindow, multi-burn-rate): an alert fires when the
        # long and the short window both burn faster than the factor, so it pages for a real outage, not a
        # blip, and resolves soon after it ends. 14.4x spends 2% of the budget in an hour, 6x 5% in six
        # hours, 3x 10% in a day.
        - record: slo:availability:error_ratio_rate5m
          expr: |
            sum by (job) (rate(http_server_requests_seconds_count{job="{{ $svc }}", status=~"5.."}[5m]))
            /
            sum by (job) (rate(http_server_requests_seconds_count{job="{{ $svc }}"}[5m]))
        - record: slo:availability:error_ratio_rate30m
          expr: |
            sum by (job) (rate(http_server_requests_seconds_count{job="{{ $svc }}", status=~"5.."}[30m]))
            /
            sum by (job) (rate(http_server_requests_seconds_count{job="{{ $svc }}"}[30m]))
        - record: slo:availability:error_ratio_rate1h
          expr: |
            sum by (job) (rate(http_server_requests_seconds_count{job="{{ $svc }}", status=~"5.."}[1h]))
            /
            sum by (job) (rate(http_server_requests_seconds_count{job="{{ $svc }}"}[1h]))
        - record: slo:availability:error_ratio_rate2h
          expr: |
            sum by (job) (rate(http_server_requests_seconds_count{job="{{ $svc }}", status=~"5.."}[2h]))
            /
            sum by (job) (rate(http_server_requests_seconds_count{job="{{ $svc }}"}[2h]))
        - record: slo:availability:error_ratio_rate6h
          expr: |
            sum by (job) (rate(http_server_requests_seconds_count{job="{{ $svc }}", status=~"5.."}[6h]))
            /
            sum by (job) (rate(http_server_requests_seconds_count{job="{{ $svc }}"}[6h]))
        - record: slo:availability:error_ratio_rate1d
          expr: |
            sum by (job) (rate(http_server_requests_seconds_count{job="{{ $svc }}", status=~"5.."}[1d]))
            /
            sum by (job) (rate(http_server_requests_seconds_count{job="{{ $svc }}"}[1d]))
        - record: slo:latency:slow_ratio_rate5m
          expr: |
            1 - (
              sum by (job) (rate(http_server_requests_seconds_bucket{job="{{ $svc }}", le="{{ $le }}"}[5m]))
              /
              sum by (job) (rate(http_server_requests_seconds_count{job="{{ $svc }}"}[5m]))
            )
        - record: slo:latency:slow_ratio_rate30m
          expr: |
            1 - (
              sum by (job) (rate(http_server_requests_seconds_bucket{job="{{ $svc }}", le="{{ $le }}"}[30m]))
              /
              sum by (job) (rate(http_server_requests_seconds_count{job="{{ $svc }}"}[30m]))
            )
        - record: slo:latency:slow_ratio_rate1h
          expr: |
            1 - (
              sum by (job) (rate(http_server_requests_seconds_bucket{job="{{ $svc }}", le="{{ $le }}"}[1h]))
              /
              sum by (job) (rate(http_server_requests_seconds_count{job="{{ $svc }}"}[1h]))
            )
        - record: slo:latency:slow_ratio_rate2h
          expr: |
            1 - (
              sum by (job) (rate(http_server_requests_seconds_bucket{job="{{ $svc }}", le="{{ $le }}"}[2h]))
              /
              sum by (job) (rate(http_server_requests_seconds_count{job="{{ $svc }}"}[2h]))
            )
        - record: slo:latency:slow_ratio_rate6h
          expr: |
            1 - (
              sum by (job) (rate(http_server_requests_seconds_bucket{job="{{ $svc }}", le="{{ $le }}"}[6h]))
              /
              sum by (job) (rate(http_server_requests_seconds_count{job="{{ $svc }}"}[6h]))
            )
        - record: slo:latency:slow_ratio_rate1d
          expr: |
            1 - (
              sum by (job) (rate(http_server_requests_seconds_bucket{job="{{ $svc }}", le="{{ $le }}"}[1d]))
              /
              sum by (job) (rate(http_server_requests_seconds_count{job="{{ $svc }}"}[1d]))
            )
        - alert: AvailabilityBudgetBurnFast
          expr: |
            slo:availability:error_ratio_rate1h{job="{{ $svc }}"} > (14.4 * (1 - {{ $availTarget }}))
            and
            slo:availability:error_ratio_rate5m{job="{{ $svc }}"} > (14.4 * (1 - {{ $availTarget }}))
          for: 2m
          labels:
            severity: critical
          annotations:
            summary: "{{ $svc }}: 5xx answers spend the 30-day availability budget 14.4x too fast (2% of it in an hour)"
        - alert: AvailabilityBudgetBurnSlow
          expr: |
            slo:availability:error_ratio_rate6h{job="{{ $svc }}"} > (6 * (1 - {{ $availTarget }}))
            and
            slo:availability:error_ratio_rate30m{job="{{ $svc }}"} > (6 * (1 - {{ $availTarget }}))
          for: 2m
          labels:
            severity: critical
          annotations:
            summary: "{{ $svc }}: 5xx answers spend the 30-day availability budget 6x too fast (5% of it in six hours)"
        - alert: AvailabilityBudgetBurnTicket
          expr: |
            slo:availability:error_ratio_rate1d{job="{{ $svc }}"} > (3 * (1 - {{ $availTarget }}))
            and
            slo:availability:error_ratio_rate2h{job="{{ $svc }}"} > (3 * (1 - {{ $availTarget }}))
          for: 2m
          labels:
            severity: warning
          annotations:
            summary: "{{ $svc }}: 5xx answers spend the 30-day availability budget 3x too fast (10% of it in a day)"
        - alert: LatencyBudgetBurnFast
          expr: |
            slo:latency:slow_ratio_rate1h{job="{{ $svc }}"} > (14.4 * (1 - {{ $latTarget }}))
            and
            slo:latency:slow_ratio_rate5m{job="{{ $svc }}"} > (14.4 * (1 - {{ $latTarget }}))
          for: 2m
          labels:
            severity: critical
          annotations:
            summary: "{{ $svc }}: requests slower than {{ $le }} s spend the 30-day latency budget 14.4x too fast"
        - alert: LatencyBudgetBurnSlow
          expr: |
            slo:latency:slow_ratio_rate6h{job="{{ $svc }}"} > (6 * (1 - {{ $latTarget }}))
            and
            slo:latency:slow_ratio_rate30m{job="{{ $svc }}"} > (6 * (1 - {{ $latTarget }}))
          for: 2m
          labels:
            severity: warning
          annotations:
            summary: "{{ $svc }}: requests slower than {{ $le }} s spend the 30-day latency budget 6x too fast"
        # slo-burn-rate: end
{{- end }}
{{- end }}

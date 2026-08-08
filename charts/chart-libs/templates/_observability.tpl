{{/*
Observability helpers — infrastructure-owned instrumentation, toggled purely by
`observability.enabled`. The SAME image runs with or without these: they only add
env/annotations that activate the runtime agents already bundled in the image
(OTel Java Agent for Java, opentelemetry-instrument for Python). See OBSERVABILITY.md.

All helpers render to nothing unless `.Values.observability.enabled` is true, so they
are safe to include unconditionally from any chart.
*/}}

{{/*
Prometheus scrape annotations (Micrometer /actuator/prometheus for Java services).
Usage inside pod template metadata.annotations:
  {{- include "chart-libs.observability.podAnnotations" . | nindent 8 }}

Only emit these for services that actually serve a Prometheus endpoint. Java services do
(Micrometer, with OTEL_METRICS_EXPORTER=none so the agent does not double-count). Python
services do NOT — they run with OTEL_METRICS_EXPORTER=otlp and PUSH metrics to the
collector, so annotating them makes the collector scrape a path that does not exist and
log a 404 every interval. Such services set `observability.metricsScrape: false`.

Defaulting note: `metricsScrape` is read via hasKey rather than `| default true`, because
in Helm `false | default true` evaluates to true — `default` treats false as empty. Using
`default` here would make the flag impossible to turn off.
*/}}
{{- define "chart-libs.observability.podAnnotations" -}}
{{- if and .Values.observability .Values.observability.enabled }}
{{- $scrape := true }}
{{- if hasKey .Values.observability "metricsScrape" }}
{{- $scrape = .Values.observability.metricsScrape }}
{{- end }}
{{- if $scrape }}
prometheus.io/scrape: "true"
prometheus.io/port: {{ .Values.service.port | quote }}
prometheus.io/path: {{ .Values.observability.metricsPath | default "/actuator/prometheus" | quote }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Observability env for Java services — activates the bundled OTel Java Agent.
Metrics stay on Micrometer (scraped via the pod annotations above), so the agent's
own metrics exporter is disabled to avoid double-counting.
Usage inside a container's env: list:
  {{- include "chart-libs.observability.javaEnv" . | nindent 12 }}
*/}}
{{- define "chart-libs.observability.javaEnv" -}}
{{- if and .Values.observability .Values.observability.enabled }}
# Node IP for node-local OTLP export to the OTel Collector DaemonSet (hostPort).
# Referenced as $(NODE_IP) by the endpoint below — must be defined before it.
- name: NODE_IP
  valueFrom:
    fieldRef:
      fieldPath: status.hostIP

- name: OTEL_SERVICE_NAME
  value: {{ include "chart-libs.fullname" . }}
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: {{ .Values.observability.otlpEndpoint | quote }}
- name: OTEL_EXPORTER_OTLP_PROTOCOL
  value: "http/protobuf"
- name: OTEL_METRICS_EXPORTER
  value: "none"
{{- end }}
{{- end }}

{{/*
Observability env for Python (FastAPI) services — activates opentelemetry-instrument
(the service entrypoint enables it when OTEL_EXPORTER_OTLP_ENDPOINT is set).
serviceName defaults to the fullname but can be overridden for sidecars.
Usage inside a container's env: list:
  {{- include "chart-libs.observability.pythonEnv" . | nindent 12 }}
*/}}
{{- define "chart-libs.observability.pythonEnv" -}}
{{- if and .Values.observability .Values.observability.enabled }}
# Node IP for node-local OTLP export to the OTel Collector DaemonSet (hostPort).
# Referenced as $(NODE_IP) by the endpoint below — must be defined before it.
- name: NODE_IP
  valueFrom:
    fieldRef:
      fieldPath: status.hostIP
- name: OTEL_SERVICE_NAME
  value: {{ include "chart-libs.fullname" . }}
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: {{ .Values.observability.otlpEndpoint | quote }}
- name: OTEL_EXPORTER_OTLP_PROTOCOL
  value: "http/protobuf"
- name: OTEL_PYTHON_LOG_CORRELATION
  value: "true"
- name: OTEL_PYTHON_LOGGING_AUTO_INSTRUMENTATION_ENABLED
  value: "true"
- name: OTEL_LOGS_EXPORTER
  value: "otlp"
- name: OTEL_METRICS_EXPORTER
  value: "otlp"
{{- end }}
{{- end }}

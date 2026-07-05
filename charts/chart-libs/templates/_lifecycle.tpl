{{/*
Pod lifecycle / reliability helpers — startup probes and graceful shutdown.
Shared so every module behaves identically during rollouts and scale-in behind
the Traefik gateway.
*/}}

{{/*
startupProbe — protects slow-starting apps (Spring Boot + OTel Java Agent cold start)
from being killed by the liveness probe before they finish booting. Renders
`.Values.startupProbe` when set; no-op otherwise.
Usage in a container spec (10-space container indent):
  {{- include "chart-libs.startupProbe" . | nindent 10 }}
*/}}
{{- define "chart-libs.startupProbe" -}}
{{- with .Values.startupProbe }}
startupProbe:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}

{{/*
preStop drain — a short sleep on SIGTERM so kube-proxy / Traefik remove the pod
from the load-balancer endpoints BEFORE the process starts shutting down, avoiding
requests routed to a terminating pod during rolling updates and scale-in.
Duration from `.Values.lifecycle.preStopDrainSeconds` (default 5s). No-op when
`.Values.lifecycle.preStopDrainSeconds` is explicitly 0.
Usage in a container spec (10-space container indent):
  {{- include "chart-libs.preStopDrain" . | nindent 10 }}
*/}}
{{- define "chart-libs.preStopDrain" -}}
{{- $d := 5 -}}
{{- if .Values.lifecycle -}}
{{- $d = int (.Values.lifecycle.preStopDrainSeconds | default 5) -}}
{{- end -}}
{{- if gt $d 0 }}
lifecycle:
  preStop:
    exec:
      command: ["/bin/sh", "-c", "sleep {{ $d }}"]
{{- end }}
{{- end }}

{{/*
Graceful-shutdown env for Spring Boot services — enables in-flight request draining
so rolling updates and scale-in do not cut active HTTP requests or message handlers.
Relies on Spring relaxed binding (SERVER_SHUTDOWN -> server.shutdown). Timeout from
`.Values.gracefulShutdown.timeout` (default 30s).
Usage inside a container's env: list:
  {{- include "chart-libs.gracefulShutdown.springEnv" . | nindent 12 }}
*/}}
{{- define "chart-libs.gracefulShutdown.springEnv" -}}
- name: SERVER_SHUTDOWN
  value: "graceful"
- name: SPRING_LIFECYCLE_TIMEOUT_PER_SHUTDOWN_PHASE
  value: {{ (and .Values.gracefulShutdown .Values.gracefulShutdown.timeout) | default "30s" | quote }}
{{- end }}

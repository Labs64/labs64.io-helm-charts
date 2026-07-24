{{/*
Application ConfigMaps. Usage: {{ include "chart-libs.applicationYaml" . }}
*/}}
{{- define "chart-libs.applicationYaml" -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "chart-libs.fullname" . }}
  labels:
    {{- include "chart-libs.labels" . | nindent 4 }}
data:
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "chart-libs.fullname" . }}-app-ext
  labels:
    {{- include "chart-libs.labels" . | nindent 4 }}
data:
  application.yaml: |-
{{ tpl (toYaml .Values.applicationYaml) $  | indent 4 }}
{{- end }}
---
{{- include "chart-libs.test-connection" . }}
---
{{- include "chart-libs.ui-test-connection" . }}

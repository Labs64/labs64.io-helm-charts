{{/*
PodDisruptionBudget. Usage: {{ include "chart-libs.pdb" . }}
*/}}
{{- define "chart-libs.pdb" -}}
{{- if and .Values.podDisruptionBudget .Values.podDisruptionBudget.enabled }}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "chart-libs.fullname" . }}
  labels:
    {{- include "chart-libs.labels" . | nindent 4 }}
spec:
  minAvailable: {{ .Values.podDisruptionBudget.minAvailable | default 1 }}
  selector:
    matchLabels:
      {{- include "chart-libs.selectorLabels" . | nindent 6 }}
{{- end }}
{{- end }}

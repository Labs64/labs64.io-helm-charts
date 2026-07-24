{{/*
HorizontalPodAutoscaler. Usage: {{ include "chart-libs.hpa" . }}
*/}}
{{- define "chart-libs.hpa" -}}
{{- if and .Values.autoscaling .Values.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "chart-libs.fullname" . }}
  labels:
    {{- include "chart-libs.labels" . | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "chart-libs.fullname" . }}
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}
  metrics:
    {{- if .Values.autoscaling.targetCPUUtilizationPercentage }}
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
    {{- end }}
    {{- if .Values.autoscaling.targetMemoryUtilizationPercentage }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetMemoryUtilizationPercentage }}
    {{- end }}
{{- end }}
{{- end }}

{{/*
UI HorizontalPodAutoscaler. Usage: {{ include "chart-libs.ui-hpa" . }}
*/}}
{{- define "chart-libs.ui-hpa" -}}
{{- if and .Values.ui .Values.ui.autoscaling .Values.ui.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "chart-libs.fullname" . }}-ui
  labels:
    helm.sh/chart: {{ include "chart-libs.chart" . }}
    app.kubernetes.io/name: {{ include "chart-libs.name" . }}-ui
    app.kubernetes.io/instance: {{ .Release.Name }}
    {{- if .Chart.AppVersion }}
    app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
    {{- end }}
    app.kubernetes.io/managed-by: {{ .Release.Service }}
    app.kubernetes.io/part-of: "Labs64.IO"
    app.kubernetes.io/component: ui
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "chart-libs.fullname" . }}-ui
  minReplicas: {{ .Values.ui.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.ui.autoscaling.maxReplicas }}
  metrics:
    {{- if .Values.ui.autoscaling.targetCPUUtilizationPercentage }}
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.ui.autoscaling.targetCPUUtilizationPercentage }}
    {{- end }}
    {{- if .Values.ui.autoscaling.targetMemoryUtilizationPercentage }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ .Values.ui.autoscaling.targetMemoryUtilizationPercentage }}
    {{- end }}
{{- end }}
{{- end }}

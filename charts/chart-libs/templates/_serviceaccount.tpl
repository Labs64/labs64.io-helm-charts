{{/*
ServiceAccount. Usage: {{ include "chart-libs.serviceAccount" . }}
*/}}
{{- define "chart-libs.serviceAccount" -}}
{{- if and .Values.serviceAccount .Values.serviceAccount.create -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "chart-libs.serviceAccountName" . }}
  labels:
    {{- include "chart-libs.labels" . | nindent 4 }}
  {{- with .Values.serviceAccount.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
automountServiceAccountToken: {{ .Values.serviceAccount.automount }}
{{- end }}
{{- end }}

{{/*
UI ServiceAccount. Usage: {{ include "chart-libs.ui-serviceAccount" . }}
*/}}
{{- define "chart-libs.ui-serviceAccount" -}}
{{- if and .Values.ui .Values.ui.serviceAccount .Values.ui.serviceAccount.create -}}
apiVersion: v1
kind: ServiceAccount
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
  {{- with .Values.ui.serviceAccount.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
automountServiceAccountToken: {{ .Values.ui.serviceAccount.automount }}
{{- end }}
{{- end }}

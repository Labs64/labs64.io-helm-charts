{{/*
Role and RoleBinding. Usage: {{ include "chart-libs.rbac" . }}
*/}}
{{- define "chart-libs.rbac" -}}
{{- if and .Values.rbac .Values.rbac.create }}
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: {{ include "chart-libs.fullname" . }}-role
  labels:
    {{- include "chart-libs.labels" . | nindent 4 }}
rules:
  {{- toYaml .Values.rbac.rules | nindent 2 }}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: {{ include "chart-libs.fullname" . }}-binding
  labels:
    {{- include "chart-libs.labels" . | nindent 4 }}
subjects:
  - kind: ServiceAccount
    name: {{ include "chart-libs.serviceAccountName" . }}
roleRef:
  kind: Role
  name: {{ include "chart-libs.fullname" . }}-role
  apiGroup: rbac.authorization.k8s.io
{{- end }}
{{- end }}

{{/*
UI Role and RoleBinding. Usage: {{ include "chart-libs.ui-rbac" . }}
*/}}
{{- define "chart-libs.ui-rbac" -}}
{{- if and .Values.ui.rbac .Values.ui.rbac.create }}
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: {{ include "chart-libs.fullname" . }}-ui-role
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
rules:
  {{- toYaml .Values.ui.rbac.rules | nindent 2 }}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: {{ include "chart-libs.fullname" . }}-ui-binding
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
subjects:
  - kind: ServiceAccount
    name: {{ include "chart-libs.ui-serviceAccountName" . }}
roleRef:
  kind: Role
  name: {{ include "chart-libs.fullname" . }}-ui-role
  apiGroup: rbac.authorization.k8s.io
{{- end }}
{{- end }}

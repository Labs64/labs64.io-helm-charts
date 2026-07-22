{{/*
UI Deployment macro. Usage: {{ include "chart-libs.ui-deployment" . }}
*/}}
{{- define "chart-libs.ui-deployment" -}}
{{- if and .Values.ui .Values.ui.enabled }}
apiVersion: apps/v1
kind: Deployment
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
  {{- if not (and .Values.ui.autoscaling .Values.ui.autoscaling.enabled) }}
  replicas: {{ .Values.ui.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      app.kubernetes.io/name: {{ include "chart-libs.name" . }}-ui
      app.kubernetes.io/instance: {{ .Release.Name }}
  template:
    metadata:
      {{- with .Values.ui.podAnnotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
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
        {{- with .Values.ui.podLabels }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
    spec:
      {{- with .Values.ui.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "chart-libs.ui-serviceAccountName" . }}
      terminationGracePeriodSeconds: {{ .Values.ui.terminationGracePeriodSeconds | default 30 }}
      {{- with .Values.ui.podSecurityContext }}
      securityContext:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      containers:
        - name: {{ .Chart.Name }}-ui
          {{- with .Values.ui.securityContext }}
          securityContext:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          image: "{{ .Values.ui.image.repository }}:{{ .Values.ui.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.ui.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.ui.service.port }}
              protocol: TCP
          {{- include "chart-libs.preStopDrain" . | nindent 10 }}
          {{- include "chart-libs.startupProbe" . | nindent 10 }}
          {{- with .Values.ui.livenessProbe }}
          livenessProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.ui.readinessProbe }}
          readinessProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- if .Values.ui.resources }}
          resources:
            {{- toYaml .Values.ui.resources | nindent 12 }}
          {{- else }}
          {{- include "chart-libs.defaultResources" . | nindent 10 }}
          {{- end }}
          env:
          {{- with .Values.ui.env }}
            {{- toYaml . | nindent 12 }}
          {{- end }}
          envFrom:
            - configMapRef:
                name: {{ include "chart-libs.fullname" . }}-ui
            - secretRef:
                name: {{ include "chart-libs.fullname" . }}-ui
          volumeMounts:
          {{- if and .Values.ui.application .Values.ui.application.runtimeEnv .Values.ui.application.runtimeEnv.enabled }}
            - name: runtime-env
              mountPath: {{ .Values.ui.application.runtimeEnv.path }}
              subPath: env.json
          {{- end }}
          {{- with .Values.ui.volumeMounts }}
            {{- toYaml . | nindent 12 }}
          {{- end }}
      volumes:
      {{- if and .Values.ui.application .Values.ui.application.runtimeEnv .Values.ui.application.runtimeEnv.enabled }}
        - name: runtime-env
          configMap:
            name: {{ include "chart-libs.fullname" . }}-ui-runtime-env
            optional: {{ not .Values.ui.application.runtimeEnv.strict }}
      {{- end }}
      {{- with .Values.ui.volumes }}
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.ui.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.ui.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.ui.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
{{- end }}
{{- end }}

{{/*
UI Service macro. Usage: {{ include "chart-libs.ui-service" . }}
*/}}
{{- define "chart-libs.ui-service" -}}
{{- if and .Values.ui .Values.ui.enabled }}
apiVersion: v1
kind: Service
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
  type: {{ .Values.ui.service.type }}
  ports:
    - port: {{ .Values.ui.service.port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    app.kubernetes.io/name: {{ include "chart-libs.name" . }}-ui
    app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
{{- end }}

{{/*
UI ConfigMap macro. Usage: {{ include "chart-libs.ui-configmap" . }}
*/}}
{{- define "chart-libs.ui-configmap" -}}
{{- if and .Values.ui .Values.ui.enabled }}
apiVersion: v1
kind: ConfigMap
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
data:
{{- if and .Values.ui.application .Values.ui.application.runtimeEnv .Values.ui.application.runtimeEnv.enabled }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "chart-libs.fullname" . }}-ui-runtime-env
data:
  env.json: |-
    {{ include "chart-libs.envjson" (dict "env" .Values.ui.application.runtimeEnv.env) | nindent 4 }}
{{- end }}
{{- end }}
{{- end }}

{{/*
UI NetworkPolicy macro.
*/}}
{{- define "chart-libs.ui-networkpolicy" -}}
{{- if and .Values.ui .Values.ui.enabled }}
{{ include "chart-libs.networkpolicy" . }}
{{- end }}
{{- end }}

{{/*
UI Gateway Routes macro.
*/}}
{{- define "chart-libs.ui-gateway-routes" -}}
{{- if and .Values.ui .Values.ui.enabled }}
{{ include "chart-libs.gateway-routes" . }}
{{- end }}
{{- end }}

{{/*
UI Secret macro.
*/}}
{{- define "chart-libs.ui-secret" -}}
{{- if and .Values.ui .Values.ui.enabled .Values.ui.secrets .Values.ui.secrets.data }}
apiVersion: v1
kind: Secret
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
type: Opaque
stringData:
{{- range $key, $value := .Values.ui.secrets.data }}
  {{ $key }}: {{ $value | quote }}
{{- end }}
{{- end }}
{{- end }}

{{/*
UI PodDisruptionBudget macro.
*/}}
{{- define "chart-libs.ui-pdb" -}}
{{- if and .Values.ui .Values.ui.enabled }}
{{ include "chart-libs.pdb" . }}
{{- end }}
{{- end }}

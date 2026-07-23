{{/*
Deployment macro. Usage: {{ include "chart-libs.deployment" . }}
Requires `.Values.applicationType` (java, python, or none) to conditionally inject framework-specific boilerplate (like Spring Config or Observability Env).
*/}}
{{- define "chart-libs.deployment" -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "chart-libs.fullname" . }}
  labels:
    {{- include "chart-libs.labels" . | nindent 4 }}
spec:
  {{- if not (and .Values.autoscaling .Values.autoscaling.enabled) }}
  replicas: {{ .Values.replicaCount | default 1 }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "chart-libs.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
        {{- range .Values.extraConfigChecksums }}
        checksum/{{ . }}: {{ include (print $.Template.BasePath (printf "/%s.yaml" .)) $ | sha256sum }}
        {{- end }}
      {{- include "chart-libs.observability.podAnnotations" . | nindent 8 }}
      {{- with .Values.podAnnotations }}
        {{- toYaml . | nindent 8 }}
      {{- end }}
      labels:
        {{- include "chart-libs.labels" . | nindent 8 }}
          {{- with .Values.podLabels }}
          {{- toYaml . | nindent 8 }}
          {{- end }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "chart-libs.serviceAccountName" . }}
      terminationGracePeriodSeconds: {{ .Values.terminationGracePeriodSeconds | default 45 }}
      {{- with .Values.podSecurityContext }}
      securityContext:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      containers:
        # Main Application Container
        - name: {{ .Chart.Name }}
          {{- with .Values.securityContext }}
          securityContext:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy | default "IfNotPresent" }}
          ports:
            - name: http
              containerPort: {{ .Values.service.port }}
              protocol: TCP
          {{- include "chart-libs.preStopDrain" . | nindent 10 }}
          {{- include "chart-libs.startupProbe" . | nindent 10 }}
          {{- with .Values.livenessProbe }}
          livenessProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.readinessProbe }}
          readinessProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.resources }}
          resources:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          env:
          {{- if eq .Values.applicationType "java" }}
            - name: SPRING_CONFIG_IMPORT
              value: "optional:file:/opt/application-config/application.yaml"
          {{- include "chart-libs.gracefulShutdown.springEnv" . | nindent 12 }}
          {{- include "chart-libs.observability.javaEnv" . | nindent 12 }}
          {{- else if eq .Values.applicationType "python" }}
          {{- include "chart-libs.observability.pythonEnv" . | nindent 12 }}
          {{- end }}
          {{- with .Values.env }}
            {{- toYaml . | nindent 12 }}
          {{- end }}
          envFrom:
            {{- if and .Values.global .Values.global.sharedConfig .Values.global.sharedConfig.enabled }}
            - configMapRef:
                name: {{ .Values.global.sharedConfig.name }}
            {{- end }}
            {{- if and .Values.global .Values.global.sharedSecret .Values.global.sharedSecret.enabled }}
            - secretRef:
                name: {{ .Values.global.sharedSecret.name }}
            {{- end }}
            - configMapRef:
                name: {{ include "chart-libs.fullname" . }}
            - secretRef:
                name: {{ include "chart-libs.fullname" . }}
            {{- with .Values.envFrom }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
          volumeMounts:
            {{- if eq .Values.applicationType "java" }}
            - name: config-additional-location
              mountPath: /opt/application-config
            - name: tmp
              mountPath: /tmp
            {{- end }}
          {{- if .Values.volumeMounts }}
            {{- tpl (toYaml .Values.volumeMounts) $ | nindent 12 }}
          {{- end }}
        {{- if .Values.extraContainers }}
        {{- tpl .Values.extraContainers $ | nindent 8 }}
        {{- end }}
      volumes:
        {{- if eq .Values.applicationType "java" }}
        - name: config-additional-location
          configMap:
            name: {{ include "chart-libs.fullname" . }}-app-ext
        - name: tmp
          emptyDir: {}
        {{- end }}
      {{- if .Values.volumes }}
        {{- tpl (toYaml .Values.volumes) $ | nindent 8 }}
      {{- end }}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
{{- end }}

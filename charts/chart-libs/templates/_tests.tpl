{{/*
helm test hook: wget the module's health endpoint through its Service.
Usage (wrapper template in the module chart, under templates/tests/):
{{ include "chart-libs.test-connection" . }}
*/}}
{{- define "chart-libs.test-connection" -}}
{{- if and .Values.tests .Values.tests.enabled }}
apiVersion: v1
kind: Pod
metadata:
  name: "{{ include "chart-libs.fullname" . }}-test-connection"
  labels:
    {{- include "chart-libs.labels" . | nindent 4 }}
  annotations:
    "helm.sh/hook": test
spec:
  containers:
    - name: wget
      image: busybox:1.36
      command: ['wget']
      args: ['-qO-', '{{ include "chart-libs.fullname" . }}:{{ .Values.service.port }}{{ .Values.tests.healthPath }}']
  restartPolicy: Never
{{- end }}
{{- end }}

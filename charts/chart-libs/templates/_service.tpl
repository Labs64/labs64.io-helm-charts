{{/*
Service macro. Usage: {{ include "chart-libs.service" . }}
*/}}
{{- define "chart-libs.service" -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "chart-libs.fullname" . }}
  labels:
    {{- include "chart-libs.labels" . | nindent 4 }}
    {{- with (include "chart-libs.authPolicyLabels" .) }}{{ . | nindent 4 }}{{- end }}
  {{- with (include "chart-libs.authPolicyAnnotations" .) }}
  annotations:
    {{- . | nindent 4 }}
  {{- end }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    {{- include "chart-libs.selectorLabels" . | nindent 4 }}
{{- end }}

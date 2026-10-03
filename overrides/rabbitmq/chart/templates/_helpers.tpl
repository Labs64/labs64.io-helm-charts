{{- define "rabbitmq-local.labels" -}}
app: rabbitmq
{{- /* Module egress NetworkPolicies select the broker by app.kubernetes.io/name. */}}
app.kubernetes.io/name: rabbitmq
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

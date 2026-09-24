{{- define "chart-libs.externalsecret" -}}
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: {{ include "chart-libs.fullname" . }}
  labels:
    {{- include "chart-libs.labels" . | nindent 4 }}
  annotations:
    "helm.sh/hook": pre-install,pre-upgrade
    "helm.sh/hook-weight": "-5"
    # Same as the plain-Secret branch below: without before-hook-creation the next
    # `helm upgrade` fails with AlreadyExists (hooks aren't tracked in the release), and
    # uninstall would orphan the ExternalSecret — and with creationPolicy: Owner its target
    # Secret with it.
    "helm.sh/hook-delete-policy": before-hook-creation
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: {{ .Values.externalSecrets.storeName | default "local-kubernetes-store" }}
    kind: ClusterSecretStore
  target:
    name: {{ include "chart-libs.fullname" . }}
    creationPolicy: Owner
  dataFrom:
  - extract:
      key: {{ .Values.externalSecrets.secretKey | default (include "chart-libs.fullname" .) }}
{{- end -}}

{{- define "chart-libs.secret" -}}
{{- if and .Values.externalSecrets .Values.externalSecrets.enabled }}
{{ include "chart-libs.externalsecret" . }}
{{- else }}
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "chart-libs.fullname" . }}
  labels:
    {{- include "chart-libs.labels" . | nindent 4 }}
  annotations:
    "helm.sh/hook": pre-install,pre-upgrade
    "helm.sh/hook-weight": "-5"
    "helm.sh/hook-delete-policy": before-hook-creation
type: Opaque
stringData:
{{- if and .Values.secrets .Values.secrets.data }}
{{- range $key, $value := .Values.secrets.data }}
  {{ $key }}: {{ $value | quote }}
{{- end }}
{{- end }}
{{- end }}
{{- end -}}

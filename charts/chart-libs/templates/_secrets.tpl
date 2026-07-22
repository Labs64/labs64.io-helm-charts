{{- define "chart-libs.externalsecret" -}}
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: {{ include "chart-libs.fullname" . }}
  labels:
    {{- include "chart-libs.labels" . | nindent 4 }}
  annotations:
    "helm.sh/hook": pre-install,pre-upgrade
    "helm.sh/hook-weight": "-5"
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

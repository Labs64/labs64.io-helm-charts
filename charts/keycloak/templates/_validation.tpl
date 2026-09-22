{{- define "keycloak.validate" -}}
{{- if not (has .Values.mode (list "development" "production")) -}}
{{- fail "keycloak: mode must be development or production" -}}
{{- end -}}
{{- if and .Values.realmConfig.config .Values.realmConfig.existingConfigMap -}}
{{- fail "keycloak: set only one of realmConfig.config or realmConfig.existingConfigMap" -}}
{{- end -}}
{{- if and .Values.persistence.enabled (ne .Values.mode "development") -}}
{{- fail "keycloak: persistence is only for the embedded development database; production requires an external database" -}}
{{- end -}}
{{- if and .Values.persistence.enabled (ne (int .Values.replicaCount) 1) -}}
{{- fail "keycloak: embedded development database persistence requires replicaCount=1" -}}
{{- end -}}
{{- if eq .Values.mode "production" -}}
  {{- if not .Values.database.host -}}
  {{- fail "keycloak: production mode requires database.host" -}}
  {{- end -}}
  {{- if or (not (hasPrefix "https://" .Values.hostname.frontendUrl)) (contains "localhost" .Values.hostname.frontendUrl) -}}
  {{- fail "keycloak: production mode requires a non-localhost HTTPS hostname.frontendUrl" -}}
  {{- end -}}
  {{- if and (not .Values.externalSecrets.enabled) (eq (index .Values.secrets.data "KC_BOOTSTRAP_ADMIN_PASSWORD") "change-me") -}}
  {{- fail "keycloak: production mode requires non-default secrets or externalSecrets.enabled" -}}
  {{- end -}}
{{- end -}}
{{- end -}}

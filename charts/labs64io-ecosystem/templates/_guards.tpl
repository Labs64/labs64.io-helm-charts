{{/*
Refuse to render when a bundled-infra password is still at its shipped default
and demoMode is not set. A default credential is correct for a throwaway demo
and wrong everywhere else; render time is the last point where that distinction
can still be enforced cheaply.
*/}}
{{- define "labs64io-ecosystem.guardDefaultPasswords" -}}
{{- $default := "labs64_dev_password" -}}
{{- if not .Values.demoMode -}}
  {{- range $k := list "postgresqlPassword" "rabbitmqPassword" "redisPassword" -}}
    {{- if eq (index $.Values.secrets $k | default "") $default -}}
      {{- fail (printf "secrets.%s is still the shipped default. Set a real password, or set demoMode=true for a throwaway demo install." $k) -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
mock-oidc authenticates nobody — it signs whatever the caller asks for. Allowing it
outside demoMode would let a production install silently accept forged identities.
*/}}
{{- define "labs64io-ecosystem.guardMockOidc" -}}
{{- if and (index .Values "mock-oidc" "enabled") (not .Values.demoMode) -}}
  {{- fail "mock-oidc.enabled requires demoMode=true — it issues tokens to anyone who asks and must never run outside a throwaway demo." -}}
{{- end -}}
{{- end -}}


{{- define "chart-libs.envjson" -}}
{
{{- $env := .env }}
{{- $length := len $env }}
{{- $i := 0 }}
{{- range $key, $value := $env }}
  "{{ $key }}": "{{ $value }}"
  {{- $i = add $i 1 }}
  {{- if lt $i $length }},{{ end }}
{{- end }}
}
{{- end }}

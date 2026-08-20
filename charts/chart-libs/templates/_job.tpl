{{/*
Credential sources for the migration Job, mirroring what chart-libs.deployment
already does for the workload itself: the umbrella's shared Secret first, then
the module's own Secret, which therefore wins on any key it defines.

This used to be two explicit secretKeyRefs against the module Secret alone. Under
the umbrella that Secret is empty — credentials live in the shared one — so the
Job could never start ("couldn't find key SPRING_DATASOURCE_PASSWORD"), taking the
whole install down with it since it is a pre-install hook. The shared Secret is
optional so a standalone install, which has no umbrella, still renders.
*/}}
{{- define "chart-libs.migration-job-credentials" -}}
{{- if and .Values.global .Values.global.sharedSecret .Values.global.sharedSecret.enabled }}
- secretRef:
    name: {{ .Values.global.sharedSecret.name }}
    optional: true
{{- end }}
- secretRef:
    name: {{ include "chart-libs.fullname" . }}
{{- end -}}

{{/*
Migration Job macro. Usage: {{ include "chart-libs.migration-job" . }}
*/}}
{{- define "chart-libs.migration-job" -}}
{{/*
Rendered unless migrationJob.enabled is explicitly false, so charts that never
declare the key keep their current behaviour.

Turn it off when the database is provisioned alongside the app in the same Helm
release (the umbrella's bundled PostgreSQL). This is a pre-install hook, so it
runs before the release's own resources exist — it would be waiting for a
database that cannot be created until it finishes. In that topology the database
is created by the server's initdb scripts and the schema by the application's
own Flyway, which every module here has enabled with baseline-on-migrate.
*/}}
{{- $mj := .Values.migrationJob | default dict -}}
{{- if and (not (eq (toString $mj.enabled) "false")) .Values.applicationYaml .Values.applicationYaml.spring .Values.applicationYaml.spring.datasource }}
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "chart-libs.fullname" . }}-migrate
  annotations:
    "helm.sh/hook": pre-install,pre-upgrade
    "helm.sh/hook-weight": "0"
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  backoffLimit: 3
  template:
    spec:
      restartPolicy: OnFailure
      initContainers:
        - name: ensure-db
          image: postgres:18
          envFrom:
            {{- include "chart-libs.migration-job-credentials" . | nindent 12 }}
          command: ["sh","-c"]
          args:
            # psql's own variable names are read from the environment rather than
            # remapped in `env:`, because envFrom values cannot be referenced by
            # $(VAR) expansion there.
            - |
              set -eu
              export PGPASSWORD="$SPRING_DATASOURCE_PASSWORD"
              DB_USER="$SPRING_DATASOURCE_USERNAME"
              DB_HOST=$(echo {{ tpl .Values.applicationYaml.spring.datasource.url $ }} | sed -E 's|jdbc:postgresql://([^:/]+):?.*|\1|')
              psql -h $DB_HOST -U $DB_USER -d postgres -tc "SELECT 1 FROM pg_database WHERE datname='{{ .Chart.Name | replace "-" "_" }}'" | grep -q 1 || \
              psql -h $DB_HOST -U $DB_USER -d postgres -c "CREATE DATABASE {{ .Chart.Name | replace "-" "_" }};"

      containers:
        - name: migrate
          image: {{ include "chart-libs.image" (dict "imageRoot" .Values.image "context" $) | quote }}
          imagePullPolicy: {{ .Values.image.pullPolicy | default "IfNotPresent" }}
          env:
            - name: SPRING_FLYWAY_ENABLED
              value: "true"
            - name: SPRING_FLYWAY_BASELINE_ON_MIGRATE
              value: "true"
            - name: SPRING_FLYWAY_CREATE_SCHEMAS
              value: "true"
            - name: SPRING_MAIN_WEB_APPLICATION_TYPE
              value: "none"
            - name: SPRING_MAIN_LAZY_INITIALIZATION
              value: "true"
            - name: SPRING_AUTOCONFIGURE_EXCLUDE
              value: >
                org.springframework.boot.autoconfigure.web.servlet.WebMvcAutoConfiguration,
                org.springframework.boot.autoconfigure.web.servlet.DispatcherServletAutoConfiguration,
                org.springframework.boot.autoconfigure.websocket.servlet.WebSocketServletAutoConfiguration,
                org.springframework.boot.autoconfigure.security.servlet.SecurityAutoConfiguration
            - name: SPRING_JPA_HIBERNATE_DDL_AUTO
              value: "validate"
            - name: SPRING_DATASOURCE_URL
              value: {{ tpl .Values.applicationYaml.spring.datasource.url $ | quote }}
          envFrom:
            {{- include "chart-libs.migration-job-credentials" . | nindent 12 }}

          terminationMessagePolicy: FallbackToLogsOnError
{{- end }}
{{- end }}

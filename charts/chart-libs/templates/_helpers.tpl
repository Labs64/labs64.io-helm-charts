{{/*
Expand the name of the chart.
*/}}
{{- define "chart-libs.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "chart-libs.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "chart-libs.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "chart-libs.labels" -}}
helm.sh/chart: {{ include "chart-libs.chart" . }}
{{ include "chart-libs.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: "Labs64.IO"
{{- end }}

{{/*
Selector labels
*/}}
{{- define "chart-libs.selectorLabels" -}}
app.kubernetes.io/name: {{ include "chart-libs.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "chart-libs.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "chart-libs.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the UI service account to use. Mirrors chart-libs.serviceAccountName
but scoped to .Values.ui.serviceAccount — falling back to "default" (not the backend's
own service account) when ui.serviceAccount.create is false, since the UI pod must never
silently inherit the backend's (potentially more privileged) identity.
*/}}
{{- define "chart-libs.ui-serviceAccountName" -}}
{{- if and .Values.ui .Values.ui.serviceAccount .Values.ui.serviceAccount.create }}
{{- default (printf "%s-ui" (include "chart-libs.fullname" .)) .Values.ui.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.ui.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Return the appropriate apiVersion for RBAC resources
*/}}
{{- define "chart-libs.rbac.apiVersion" -}}
{{- if .Capabilities.APIVersions.Has "rbac.authorization.k8s.io/v1" -}}
rbac.authorization.k8s.io/v1
{{- else -}}
rbac.authorization.k8s.io/v1beta1
{{- end -}}
{{- end -}}

{{/*
Return the appropriate apiVersion for HPA
*/}}
{{- define "chart-libs.hpa.apiVersion" -}}
{{- if .Capabilities.APIVersions.Has "autoscaling/v2" -}}
autoscaling/v2
{{- else if .Capabilities.APIVersions.Has "autoscaling/v2beta2" -}}
autoscaling/v2beta2
{{- else -}}
autoscaling/v2beta1
{{- end -}}
{{- end -}}

{{/*
Common annotations
*/}}
{{- define "chart-libs.annotations" -}}
{{- if .Values.commonAnnotations }}
{{- toYaml .Values.commonAnnotations }}
{{- end }}
{{- end }}

{{/*
Renders a value that contains template.
Usage:
{{ include "chart-libs.tplvalues.render" ( dict "value" .Values.path.to.the.Value "context" $) }}
*/}}
{{- define "chart-libs.tplvalues.render" -}}
{{- if typeIs "string" .value }}
  {{- tpl .value .context }}
{{- else }}
  {{- tpl (.value | toYaml) .context }}
{{- end }}
{{- end -}}

{{/*
Return the fully qualified image reference for an image block.

Digest wins over tag: when `digest` is set the reference is `repository@sha256:...`,
which is the only deployment identity that cannot be moved out from under a running
workload — neither Docker Hub nor GHCR can enforce tag immutability, so a redeployed
`:1.4.0` may resolve to different content than the release that was validated. The tag
form remains the default for local development and for charts wrapping upstream images
that are not yet digest-pinned.

Precedence: digest -> explicit tag -> .Chart.AppVersion.

Usage:
  {{ include "chart-libs.image" (dict "imageRoot" .Values.image "context" $) }}
  {{ include "chart-libs.image" (dict "imageRoot" .Values.ui.image "context" $) }}
*/}}
{{- define "chart-libs.image" -}}
{{- $img := .imageRoot -}}
{{- $ctx := .context -}}
{{- $repository := required "image.repository is required" $img.repository -}}
{{- $ref := $repository -}}
{{- with $img.registry -}}
{{- $ref = printf "%s/%s" . $repository -}}
{{- end -}}
{{- $digest := $img.digest | default "" | toString -}}
{{- if $digest -}}
{{- if not (regexMatch "^sha256:[a-f0-9]{64}$" $digest) -}}
{{- fail (printf "invalid image digest %q for %s (expected sha256:<64 lowercase hex>)" $digest $repository) -}}
{{- end -}}
{{- printf "%s@%s" $ref $digest -}}
{{- else -}}
{{- printf "%s:%s" $ref ($img.tag | default $ctx.Chart.AppVersion | toString) -}}
{{- end -}}
{{- end -}}

{{/*
Default resource limits for module charts.
Baseline = AuditFlow's audited values. Charts override via .Values.resources.
Usage: {{ include "chart-libs.defaultResources" . }}
*/}}
{{- define "chart-libs.defaultResources" -}}
{{- if not .Values.resources }}
resources:
  limits:
    cpu: 500m
    memory: 1Gi
  requests:
    cpu: 100m
    memory: 512Mi
{{- end -}}
{{- end -}}



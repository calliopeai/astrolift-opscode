{{/*
Expand the name of the chart.
*/}}
{{- define "astrolift.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "astrolift.fullname" -}}
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
{{- define "astrolift.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "astrolift.labels" -}}
helm.sh/chart: {{ include "astrolift.chart" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: astrolift
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Component-specific selector labels.
Accepts a dict with keys: root (the top-level context) and component (string).
*/}}
{{- define "astrolift.selectorLabels" -}}
app.kubernetes.io/name: {{ include "astrolift.name" .root }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{/*
Resolve image tag, defaulting to Chart.appVersion.
*/}}
{{- define "astrolift.imageTag" -}}
{{- if . }}{{ . }}{{- else }}{{ $.Chart.AppVersion }}{{- end }}
{{- end }}

{{/*
Service account name.
*/}}
{{- define "astrolift.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "astrolift.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

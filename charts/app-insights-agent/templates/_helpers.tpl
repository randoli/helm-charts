{{- define "app-insights-agent.namespace" -}}
  {{ .Values.namespace | default .Release.Namespace }}
{{- end -}}

{{- define "app-insights-agent.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "app-insights-agent.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "chartName" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Labels that should be added on each resource
*/}}
{{- define "labels" -}}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- if eq (default "helm" .Values.creator) "helm" }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ include "chartName" . }}
{{- end -}}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "app-insights-agent.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "app-insights-agent.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "prometheus-server-endpoint" -}}
  {{- if .Values.global.prometheus.install -}}
    {{- printf "http://%s-prometheus-server.%s.svc:80" .Release.Name .Release.Namespace -}}
  {{- else if .Values.global.prometheus.url -}}
    {{ tpl .Values.global.prometheus.url . }}
  {{- end -}}
{{- end -}}
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

{{- define "app-insights-satellite-agent.name" -}}
{{- printf "%s-%s" "satellite" (include "app-insights-agent.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "app-insights-agent-grpc-address.name" -}}
{{- (include "app-insights-agent.fullname" .) -}}.{{- (include "app-insights-agent.namespace" .) -}}:9090
{{- end -}}

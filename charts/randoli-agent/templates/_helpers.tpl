{{- define "randoli-agent.namespace" -}}
  {{ .Values.namespace | default .Release.Namespace }}
{{- end -}}

{{- define "randoli-agent.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "randoli-agent.fullname" -}}
  {{- printf "%s-agent" .Release.Name | trunc 63 | trimSuffix "-" -}}
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
{{- define "randoli-agent.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "randoli-agent.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "prometheus-server-endpoint" -}}
  {{- if .Values.global.prometheus.install -}}
    {{- printf "http://%s-prometheus.%s.svc:80" .Release.Name .Release.Namespace -}}
  {{- else if .Values.global.prometheus.url -}}
    {{ tpl .Values.global.prometheus.url . }}
  {{- end -}}
{{- end -}}


{{/*
Dependencies Logic for config map
*/}}

{{- define "enable.vpa.operator" -}}
{{- $vpaOperator := .Values.costManagement.vpaOperator | default dict }}
{{- if and (or (empty $vpaOperator) $vpaOperator.enabled ) .Values.tags.costManagement -}}
true
{{- else if eq (default false $vpaOperator.enabled) true  -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{- define "enable.pixie.operator" -}}
{{- $pixie := .Values.observability.pixie | default dict }}
{{- if and (or (empty $pixie) $pixie.enabled ) .Values.tags.observability -}}
true
{{- else if eq (default false $pixie.enabled) true  -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{- define "enable.security" -}}
{{- $security := .Values.observability.security | default dict }}
{{- if and (or (not (hasKey $security "enabled")) $security.enabled ) .Values.tags.observability -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}


{{- define "observability.secutiry.mode" -}}
{{- $security := .Values.observability.security | default dict }}
{{- if and (or (not (hasKey $security "enabled")) $security.enabled ) .Values.tags.observability -}}
{{.Values.observability.security.mode}}
{{- else -}}
OFF
{{- end -}}
{{- end -}}


{{- define "enable.vector" -}}
{{- $vector := .Values.observability.vector | default dict }}
{{- if and (or (empty $vector) $vector.enabled ) .Values.tags.observability -}}
true
{{- else if eq (default false $vector.enabled) true  -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

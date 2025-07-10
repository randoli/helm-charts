{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "prometheus.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "prometheus.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create labels for prometheus
*/}}
{{- define "prometheus.common.matchLabels" -}}
app.kubernetes.io/name: {{ include "prometheus.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Create unified labels for prometheus components
*/}}
{{- define "prometheus.common.metaLabels" -}}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
helm.sh/chart: {{ include "prometheus.chart" . }}
app.kubernetes.io/part-of: {{ include "prometheus.name" . }}
{{- with .Values.commonMetaLabels}}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "prometheus.server.labels" -}}
{{ include "prometheus.server.matchLabels" . }}
{{ include "prometheus.common.metaLabels" . }}
{{- end -}}

{{- define "prometheus.server.matchLabels" -}}
app.kubernetes.io/component: {{ .Values.server.name }}
{{ include "prometheus.common.matchLabels" . }}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "prometheus.fullname" -}}
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
Create a fully qualified ClusterRole name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "prometheus.clusterRoleName" -}}
{{- if .Values.server.clusterRoleNameOverride -}}
{{ .Values.server.clusterRoleNameOverride | trunc 63 | trimSuffix "-" }}
{{- else -}}
{{ include "prometheus.server.fullname" . }}
{{- end -}}
{{- end -}}

{{/*
Create a fully qualified alertmanager name for communicating and check to ensure that `alertmanager` exists before trying to use it with the user via NOTES.txt
*/}}
{{- define "prometheus.alertmanager.fullname" -}}
{{- if .Subcharts.alertmanager -}}
{{- template "alertmanager.fullname" .Subcharts.alertmanager -}}
{{- else -}}
{{- "alertmanager not found" -}}
{{- end -}}
{{- end -}}

{{/*
Create a fully qualified Prometheus server name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "prometheus.server.fullname" -}}
{{- if .Values.server.fullnameOverride -}}
{{- .Values.server.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- printf "%s-%s" .Release.Name .Values.server.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-%s" .Release.Name $name .Values.server.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Get KubeVersion removing pre-release information.
*/}}
{{- define "prometheus.kubeVersion" -}}
  {{- default .Capabilities.KubeVersion.Version (regexFind "v[0-9]+\\.[0-9]+\\.[0-9]+" .Capabilities.KubeVersion.Version) -}}
{{- end -}}

{{/*
Return the appropriate apiVersion for deployment.
*/}}
{{- define "prometheus.deployment.apiVersion" -}}
{{- print "apps/v1" -}}
{{- end -}}

{{/*
Return the appropriate apiVersion for networkpolicy.
*/}}
{{- define "prometheus.networkPolicy.apiVersion" -}}
{{- print "networking.k8s.io/v1" -}}
{{- end -}}

{{/*
Return the appropriate apiVersion for poddisruptionbudget.
*/}}
{{- define "prometheus.podDisruptionBudget.apiVersion" -}}
{{- if .Capabilities.APIVersions.Has "policy/v1" }}
{{- print "policy/v1" -}}
{{- else -}}
{{- print "policy/v1beta1" -}}
{{- end -}}
{{- end -}}

{{/*
Return the appropriate apiVersion for rbac.
*/}}
{{- define "rbac.apiVersion" -}}
{{- if .Capabilities.APIVersions.Has "rbac.authorization.k8s.io/v1" }}
{{- print "rbac.authorization.k8s.io/v1" -}}
{{- else -}}
{{- print "rbac.authorization.k8s.io/v1beta1" -}}
{{- end -}}
{{- end -}}

{{/*
Return the appropriate apiVersion for ingress.
*/}}
{{- define "ingress.apiVersion" -}}
  {{- if and (.Capabilities.APIVersions.Has "networking.k8s.io/v1") (semverCompare ">= 1.19.x" (include "prometheus.kubeVersion" .)) -}}
      {{- print "networking.k8s.io/v1" -}}
  {{- else if .Capabilities.APIVersions.Has "networking.k8s.io/v1beta1" -}}
    {{- print "networking.k8s.io/v1beta1" -}}
  {{- else -}}
    {{- print "extensions/v1beta1" -}}
  {{- end -}}
{{- end -}}

{{/*
Return if ingress is stable.
*/}}
{{- define "ingress.isStable" -}}
  {{- eq (include "ingress.apiVersion" .) "networking.k8s.io/v1" -}}
{{- end -}}

{{/*
Return if ingress supports ingressClassName.
*/}}
{{- define "ingress.supportsIngressClassName" -}}
  {{- or (eq (include "ingress.isStable" .) "true") (and (eq (include "ingress.apiVersion" .) "networking.k8s.io/v1beta1") (semverCompare ">= 1.18.x" (include "prometheus.kubeVersion" .))) -}}
{{- end -}}

{{/*
Return if ingress supports pathType.
*/}}
{{- define "ingress.supportsPathType" -}}
  {{- or (eq (include "ingress.isStable" .) "true") (and (eq (include "ingress.apiVersion" .) "networking.k8s.io/v1beta1") (semverCompare ">= 1.18.x" (include "prometheus.kubeVersion" .))) -}}
{{- end -}}

{{/*
Create the name of the service account to use for the server component
*/}}
{{- define "prometheus.serviceAccountName.server" -}}
{{- if .Values.serviceAccounts.server.create -}}
    {{ default (include "prometheus.server.fullname" .) .Values.serviceAccounts.server.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccounts.server.name }}
{{- end -}}
{{- end -}}

{{/*
Define the prometheus.namespace template if set with forceNamespace or .Release.Namespace is set
*/}}
{{- define "prometheus.namespace" -}}
  {{- default .Release.Namespace .Values.forceNamespace -}}
{{- end }}

{{/*
Define template prometheus.namespaces producing a list of namespaces to monitor
*/}}
{{- define "prometheus.namespaces" -}}
{{- $namespaces := list }}
{{- if and .Values.rbac.create .Values.server.useExistingClusterRoleName }}
  {{- if .Values.server.namespaces -}}
    {{- range $ns := join "," .Values.server.namespaces | split "," }}
      {{- $namespaces = append $namespaces (tpl $ns $) }}
    {{- end -}}
  {{- end -}}
  {{- if .Values.server.releaseNamespace -}}
    {{- $namespaces = append $namespaces (include "prometheus.namespace" .) }}
  {{- end -}}
{{- end -}}
{{ mustToJson $namespaces }}
{{- end -}}

{{/*
Define prometheus.server.remoteWrite producing a list of remoteWrite configurations with URL templating
*/}}
{{- define "prometheus.server.remoteWrite" -}}
{{- $remoteWrites := list }}
{{- range $remoteWrite := .Values.server.remoteWrite }}
  {{- $remoteWrites = tpl $remoteWrite.url $ | set $remoteWrite "url" | append $remoteWrites }}
{{- end -}}
{{ toYaml $remoteWrites }}
{{- end -}}

{{/*
Define prometheus.server.remoteRead producing a list of remoteRead configurations with URL templating
*/}}
{{- define "prometheus.server.remoteRead" -}}
{{- $remoteReads := list }}
{{- range $remoteRead := .Values.server.remoteRead }}
  {{- $remoteReads = tpl $remoteRead.url $ | set $remoteRead "url" | append $remoteReads }}
{{- end -}}
{{ toYaml $remoteReads }}
{{- end -}}

{{/*
RANDOLI - Define prometheus.opencost.url by getting the opencost url based on the agent installations 
*/}}
{{- define "prometheus.opencost.url" -}}
{{- if .Values.global.opencost.url -}}
{{- print .Values.global.opencost.url | replace "http://" ""  -}}
{{- else -}}
{{- printf "randoli-cmk-opencost.%s.svc:9003" .Release.Namespace -}}
{{- end -}}
{{- end -}}

{{/*
RANDOLI - Define prometheus.networkCostMetrics.url by getting the network cost metrics url based on the agent installations 
*/}}
{{- define "prometheus.networkCostMetrics.url" -}}
{{- if .Values.global.networkCostMetrics.url -}}
{{- print .Values.global.networkCostMetrics.url | replace "http://" ""  -}}
{{- else -}}
{{- printf "randoli-cmk-opencost.%s.svc:8080" .Release.Namespace -}}
{{- end -}}
{{- end -}}


# {{/*
# RANDOLI - Define AlertManager Route 
# */}}
{{- define "prometheus.alerts.route" -}}
{{- if and .Values.global.alerts.slack.channel .Values.global.alerts.slack.api_url  -}}
route:
  group_by: ["alertName", "cluster", "namespace", "deployment"]
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 3h
  receiver: "randoli-alerts-slack-channel"
  routes:
    - matchers:
        - prometheus=~".+"
      receiver: "null"
{{- else -}}
route:
  group_wait: 10s
  group_interval: 5m
  receiver: default-receiver
  repeat_interval: 3h
{{- end -}}
{{- end -}}


{{/*
RANDOLI - Define AlertManager Receiver 
*/}}
{{- define "prometheus.alerts.receiver" -}}
{{- if and .Values.global.alerts.slack.channel .Values.global.alerts.slack.api_url  -}}
receivers:
  - name: default-receiver
  - name: "randoli-alerts-slack-channel"
    slack_configs:
      - api_url: {{.Values.global.alerts.slack.api_url}}
        channel: {{.Values.global.alerts.slack.channel}}
        icon_url: "https://cdn.prod.website-files.com/66e2aa7f74a05584d1dc32d8/67b4ede66602c10c41838925_logo_48px.png"
        username: Randoli Alert Bot
        text: |-
          *Cluster:* {{ "{{" }} .CommonLabels.cluster {{ "}}" }}
          *Namespace:* {{ "{{" }} .CommonLabels.namespace {{ "}}" }}
          *Deployment:* {{ "{{" }} .CommonLabels.deployment {{ "}}" }}
          *Description:* {{ "{{" }} .CommonAnnotations.description {{ "}}" }}
        footer: "Occurred At {{ "{{" }} .CommonAnnotations.occurredAt {{ "}}" }}"
        actions:
          - type: "button"
            text: 'View {{ "{{" }} .CommonLabels.alertType {{ "}}" }}'
            url: '{{ "{{" }} .CommonAnnotations.sourceUrl {{ "}}" }}'
{{- else -}}
receivers:
  - name: default-receiver
    # slack_configs:
    #  - channel: '@you'
    #    send_resolved: true
{{- end -}}
{{- end -}}
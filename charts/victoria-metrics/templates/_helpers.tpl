{{/*
Builds the opencost scrape target URL.
Uses global.opencost.url if set; otherwise defaults to the randoli-cmk-opencost service.
(global is nil-safe so the standalone chart still lints/renders.)
*/}}
{{- define "victoria-metrics.opencost.url" -}}
{{- $opencost := (.Values.global).opencost | default dict -}}
{{- if $opencost.url -}}
{{- print $opencost.url | replace "http://" "" -}}
{{- else -}}
{{- printf "randoli-cmk-opencost.%s.svc:9003" .Release.Namespace -}}
{{- end -}}
{{- end -}}

{{/*
Builds the network-cost-metrics scrape target URL.
Uses global.networkCostMetrics.url if set; otherwise defaults to the randoli-cmk-opencost sidecar port.
*/}}
{{- define "victoria-metrics.networkCostMetrics.url" -}}
{{- $ncm := (.Values.global).networkCostMetrics | default dict -}}
{{- if $ncm.url -}}
{{- print $ncm.url | replace "http://" "" -}}
{{- else -}}
{{- printf "randoli-cmk-opencost.%s.svc:8080" .Release.Namespace -}}
{{- end -}}
{{- end -}}

{{/*
OpenShift host-metrics federation: vmsingle copies node_* series from the
platform Prometheus instead of running node-exporter. Mirrors
"prometheus.ocpFederation.*" in charts/prometheus/templates/_helpers.tpl.
*/}}
{{- define "victoria-metrics.ocpFederation.enabled" -}}
{{- $g := .Values.global | default dict -}}
{{- if and (dig "openshift" "enabled" false $g) (eq (dig "hostMetrics" "provider" "" $g) "openshift-monitoring") -}}
true
{{- end -}}
{{- end -}}

{{- define "victoria-metrics.ocpFederation.scrapeJob" -}}
{{- if eq (include "victoria-metrics.ocpFederation.enabled" .) "true" -}}
{{- $cfg := dig "hostMetrics" "openshiftMonitoring" dict (.Values.global | default dict) -}}
- job_name: 'ocp-node-exporter-federate'
  scrape_interval: {{ dig "scrapeInterval" "30s" $cfg }}
  scrape_timeout: {{ dig "scrapeTimeout" "25s" $cfg }}
  honor_labels: true
  honor_timestamps: true
  scheme: https
  metrics_path: /federate
  params:
    match[]:
      - '{{ dig "match" `{__name__=~"node_.+"}` $cfg }}'
  static_configs:
    - targets: ['{{ dig "target" "prometheus-k8s.openshift-monitoring.svc:9091" $cfg }}']
  authorization:
    credentials_file: /var/run/secrets/kubernetes.io/serviceaccount/token
  tls_config:
    ca_file: /etc/victoria-metrics/extra-volumes/ocp-service-ca/service-ca.crt
    server_name: {{ dig "serverName" "prometheus-k8s.openshift-monitoring.svc" $cfg }}
  metric_relabel_configs:
    # Copy node name from `instance` to `node`, matching node-exporter.
    - source_labels: [instance]
      target_label: node
{{- end }}
{{- end -}}

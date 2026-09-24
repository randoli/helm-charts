{{/*
Builds the opencost scrape target URL.
Uses global.opencost.url if set; otherwise defaults to the randoli-cmk-opencost service.
*/}}
{{- define "prometheus.opencost.url" -}}
{{- $oc := (.Values.global | default dict).opencost | default dict -}}
{{- if $oc.url -}}
{{- print $oc.url | replace "http://" "" -}}
{{- else -}}
{{- printf "randoli-cmk-opencost.%s.svc:9003" .Release.Namespace -}}
{{- end -}}
{{- end -}}

{{/*
Builds the network-cost-metrics scrape target URL.
Uses global.networkCostMetrics.url if set; otherwise defaults to the randoli-cmk-opencost sidecar port.
*/}}
{{- define "prometheus.networkCostMetrics.url" -}}
{{- $ncm := (.Values.global | default dict).networkCostMetrics | default dict -}}
{{- if $ncm.url -}}
{{- print $ncm.url | replace "http://" "" -}}
{{- else -}}
{{- printf "randoli-cmk-opencost.%s.svc:8080" .Release.Namespace -}}
{{- end -}}
{{- end -}}

{{/*
OpenShift host-metrics federation.

When global.openshift.enabled=true and
global.hostMetrics.provider="openshift-monitoring", the bundled Prometheus
federates the node_* series the OpenShift platform monitoring stack already
collects — no node-exporter DaemonSet runs in the cluster.

Wiring (everything keys off "prometheus.ocpFederation.enabled"):
  - values.yaml extraScrapeConfigs includes "prometheus.ocpFederation.scrapeJob",
    which scrapes https://<target>/federate using the server ServiceAccount
    token.
  - templates/clusterrolebinding-monitoring-view.yaml binds that
    ServiceAccount to OpenShift's cluster-monitoring-view ClusterRole, because
    /federate authorizes requests via SubjectAccessReview.
  - values.yaml server.extraVolumes mounts the auto-injected
    openshift-service-ca.crt configMap (optional: true, so a no-op on vanilla
    Kubernetes) for TLS verification of the platform Prometheus.
*/}}
{{- define "prometheus.ocpFederation.enabled" -}}
{{- $g := .Values.global | default dict -}}
{{- if and (dig "openshift" "enabled" false $g) (eq (dig "hostMetrics" "provider" "" $g) "openshift-monitoring") -}}
true
{{- end -}}
{{- end -}}

{{/*
Renders the /federate scrape job (at list-item indentation, for use with
nindent inside extraScrapeConfigs), or nothing when federation is off.
*/}}
{{- define "prometheus.ocpFederation.scrapeJob" -}}
{{- if eq (include "prometheus.ocpFederation.enabled" .) "true" -}}
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
    # ca_file is the values.yaml server.extraVolumes mount of the
    # auto-injected openshift-service-ca.crt configMap.
    ca_file: /etc/prometheus/extra-volumes/ocp-service-ca/service-ca.crt
    server_name: {{ dig "serverName" "prometheus-k8s.openshift-monitoring.svc" $cfg }}
  metric_relabel_configs:
    # Platform series carry node identity in `instance` (node name); the
    # node-exporter provider exposes it as the `node` label. Copy it so
    # queries joining on `node` behave identically with either provider.
    - source_labels: [instance]
      target_label: node
{{- end }}
{{- end -}}

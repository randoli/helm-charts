{{- define "randoli-agent.namespace" -}}
  {{ .Values.namespace | default .Release.Namespace }}
{{- end -}}

{{- define "randoli-agent.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "randoli-agent.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- printf "%s" $name | trunc 63 | trimSuffix "-" -}}
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
{{- define "randoli-agent.serviceAccountName" -}}
randoli-agent
{{- end -}}

{{/*
Metrics store READ endpoint (PromQL). Prometheus and VictoriaMetrics serve the
same /api/v1/query path, so every consumer (agent, tproxy, netobserv
flow-collector, OpenCost) uses this unchanged.
Precedence: bundled Prometheus → bundled VictoriaMetrics → external prometheus.url.

Only global values are used so subcharts can render it through `tpl`
(costManagement OpenCost endpoint, sreAgent).
*/}}
{{- define "prometheus-server-endpoint" -}}
  {{- if .Values.global.prometheus.install -}}
    {{- printf "http://randoli-obs-prometheus.%s.svc:80" .Release.Namespace -}}
  {{- else if (.Values.global.victoriaMetrics).install -}}
    {{- printf "http://randoli-obs-victoria-metrics.%s.svc:8428" .Release.Namespace -}}
  {{- else if .Values.global.prometheus.url -}}
    {{- tpl .Values.global.prometheus.url . -}}
  {{- end -}}
{{- end -}}

{{/*
Metrics store OTLP WRITE endpoint (OTel Collector otlphttp exporter, which
appends /v1/metrics). The ingest path differs by backend:
  Prometheus       → <endpoint>/api/v1/otlp   (→ /api/v1/otlp/v1/metrics)
  VictoriaMetrics  → <endpoint>/opentelemetry (→ /opentelemetry/v1/metrics)
VictoriaMetrics answers HTTP 400 on the Prometheus path and every metric is
dropped. For an external VictoriaMetrics set global.victoriaMetrics.external=true.
*/}}
{{- define "metrics-otlp-endpoint" -}}
  {{- $base := include "prometheus-server-endpoint" . | trim -}}
  {{- $vm := .Values.global.victoriaMetrics | default dict -}}
  {{- if and (not .Values.global.prometheus.install) (or $vm.install $vm.external) -}}
    {{- printf "%s/opentelemetry" $base -}}
  {{- else -}}
    {{- printf "%s/api/v1/otlp" $base -}}
  {{- end -}}
{{- end -}}

{{/*
True when a metrics store is bundled (Prometheus OR VictoriaMetrics). Drives the
agent's PROMETHEUS_INSTALL flag, which is about whether a store is shipped with
the agent — not specifically Prometheus.
*/}}
{{- define "metrics.install" -}}
  {{- if or .Values.global.prometheus.install (.Values.global.victoriaMetrics).install -}}
true
  {{- else -}}
false
  {{- end -}}
{{- end -}}

{{/*
Cluster endpoints of umbrella-owned services.

These helpers are referenced as template strings from values.yaml
(sreAgent.observability.* / sreAgent.dataPlane.*), which the sre-agent
subchart renders through `tpl`.

Note: Avoid using Parent-only .Values here as they are not visible in the
context of the referenced subchart.
*/}}
{{- define "otel-collector-grpc-endpoint" -}}
{{- printf "randoli-otel-collector.%s.svc.cluster.local:4317" .Release.Namespace -}}
{{- end -}}

{{/* the OTel SDK expects the http:// prefix eventhough the gRPC endpoint being used */}}
{{- define "otel-collector-grpc-endpoint-http-prefix" -}}
{{- printf "http://randoli-otel-collector.%s.svc.cluster.local:4317" .Release.Namespace -}}
{{- end -}}

{{- define "otel-collector-http-endpoint" -}}
{{- printf "http://randoli-otel-collector.%s.svc:4318" .Release.Namespace -}}
{{- end -}}

{{- define "agent-callback-url" -}}
{{- printf "http://randoli-agent.%s.svc:8080/" .Release.Namespace -}}
{{- end -}}

{{/*
DNS host of the randoli-fsqld Service (FlightSQL endpoint), without the port.
The service name is hardcoded so this is safe to render from subchart contexts as well.
*/}}
{{- define "agent-db-host" -}}
{{- printf "randoli-fsqld.%s.svc" .Release.Namespace -}}
{{- end -}}

{{- define "agent-flightsql-url" -}}
{{- printf "grpc+tcp://randoli-fsqld.%s.svc:31337" .Release.Namespace -}}
{{- end -}}

{{/*
HTTP endpoint of the OpenCost MCP server (streamable HTTP, served at the port
root on the OpenCost Service's mcp-server port, 8081).
*/}}
{{- define "opencost-mcp-url" -}}
{{- if .Values.global.opencost.mcpUrl -}}
{{- tpl .Values.global.opencost.mcpUrl . -}}
{{- else -}}
{{- printf "http://randoli-cmk-opencost.%s.svc:8081" .Release.Namespace -}}
{{- end -}}
{{- end -}}

{{/*
HTTP endpoint of the sre-agent Service (AI chatbot backend). Only referenced
when tags.sreAgent is enabled and the subchart is installed.
*/}}
{{- define "sre-agent-http-endpoint" -}}
{{- printf "http://randoli-sre-agent.%s.svc:80" .Release.Namespace -}}
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
{{- if and (or (not (hasKey $security "enabled")) $security.enabled ) .Values.tags.security -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}


{{- define "observability.security.mode" -}}
{{- $security := .Values.observability.security | default dict }}
{{- if or $security.enabled .Values.tags.security -}}
{{.Values.observability.security.mode }}
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


{{- define "apply-network-crs" -}}
{{- $netobserv := .Values.observability.netobserv | default dict }}
{{- if and (or (not (hasKey $netobserv "applyCRs")) $netobserv.applyCRs) (or .Values.tags.observability .Values.tags.costManagement) -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{/*
Tempo deployment mode: singleBinary (charts/tempo) or distributed (charts/tempo-distributed).
The two booleans below are mutually exclusive; the distributed branch wins when both are on.
*/}}
{{- define "tempo.distributed.enabled" -}}
{{- $distributed := (((.Values.observability).tempo).distributed) | default dict -}}
{{- if eq (default false $distributed.enabled) true -}}true{{- else -}}false{{- end -}}
{{- end -}}

{{/*
Read/query endpoint (telemetry-proxy & agent → Tempo). In distributed mode
this is the query-frontend Service; in single-binary mode all roles share
one Service. Honors observability.traceConfig.storage.tempo.readUrl when
set (external Tempo).
*/}}
{{- define "trace-storage-url" -}}
{{- $tempo := ((((.Values.observability).traceConfig).storage).tempo) | default dict -}}
{{- if not (empty $tempo.readUrl) -}}
{{ $tempo.readUrl }}
{{- else if eq (include "tempo.distributed.enabled" .) "true" -}}
{{- printf "http://randoli-obs-tempo-dist-query-frontend.%s.svc:3200" .Release.Namespace -}}
{{- else -}}
{{- printf "http://randoli-obs-tempo.%s.svc:3200" .Release.Namespace -}}
{{- end -}}
{{- end -}}

{{/*
Write/push endpoint (OTel Collector → Tempo, OTLP gRPC, no scheme). In
distributed mode this is the distributor Service; in single-binary mode
all roles share one Service. Honors
observability.traceConfig.storage.tempo.writeUrl when set (external Tempo).
*/}}
{{- define "trace-storage-url-otlp" -}}
{{- $tempo := ((((.Values.observability).traceConfig).storage).tempo) | default dict -}}
{{- if not (empty $tempo.writeUrl) -}}
{{ $tempo.writeUrl }}
{{- else if eq (include "tempo.distributed.enabled" .) "true" -}}
{{- printf "randoli-obs-tempo-dist-distributor.%s.svc:4317" .Release.Namespace -}}
{{- else -}}
{{- printf "randoli-obs-tempo.%s.svc:4317" .Release.Namespace -}}
{{- end -}}
{{- end -}}

{{/*
Loki deployment mode: singleBinary (charts/loki) or distributed (charts/loki-distributed).
The two booleans below are mutually exclusive; the distributed branch wins when both are on.
*/}}
{{- define "loki.distributed.enabled" -}}
{{- $distributed := (((.Values.observability).loki).distributed) | default dict -}}
{{- if eq (default false $distributed.enabled) true -}}true{{- else -}}false{{- end -}}
{{- end -}}

{{/*
Write/push endpoint (Vector → Loki). In distributed mode this is the
distributor Service; in single-binary mode all roles share one Service.
Honors observability.logs.loki.writeUrl when set (external Loki).
*/}}
{{- define "logs-loki-url" -}}
{{- $loki := (((.Values.observability).logs).loki) | default dict -}}
{{- if not (empty $loki.writeUrl) -}}
{{ $loki.writeUrl }}
{{- else if eq (include "loki.distributed.enabled" .) "true" -}}
{{- printf "http://randoli-obs-loki-dist-distributor.%s.svc:3100" .Release.Namespace -}}
{{- else -}}
{{- printf "http://randoli-obs-loki.%s.svc:3100" .Release.Namespace -}}
{{- end -}}
{{- end -}}

{{/*
Read/query endpoint (telemetry-proxy → Loki). In distributed mode this is
the query-frontend Service; in single-binary mode it shares the single
Loki Service with the write path. Honors observability.logs.loki.readUrl
when set, falling back to writeUrl for the single-binary external case.
*/}}
{{- define "logs-loki-read-url" -}}
{{- $loki := (((.Values.observability).logs).loki) | default dict -}}
{{- if not (empty $loki.readUrl) -}}
{{ $loki.readUrl }}
{{- else if not (empty $loki.writeUrl) -}}
{{ $loki.writeUrl }}
{{- else if eq (include "loki.distributed.enabled" .) "true" -}}
{{- printf "http://randoli-obs-loki-dist-query-frontend.%s.svc:3100" .Release.Namespace -}}
{{- else -}}
{{- printf "http://randoli-obs-loki.%s.svc:3100" .Release.Namespace -}}
{{- end -}}
{{- end -}}

{{/*
Legacy / fallback issuer URL for the tproxy. Installs whose agent secret has no
KEYCLOAK_URL + KEYCLOAK_REALM_TPROXY keep using this; the tproxy prefers the
URL + realm pair when both are present (see randoli-tproxy/deployment.yaml).
*/}}
{{- define "telemetry-proxy-keycloak-issuer" -}}
{{- if not (empty .Values.tproxy.keycloakIssuer)  -}}
{{ .Values.tproxy.keycloakIssuer }}
{{- else -}}
https://sso.randoli.io/auth/realms/sso
{{- end -}}
{{- end -}}

{{/*
Host-metrics provider. global.hostMetrics.provider is the standard location
(The OpenShift federation scrape job is rendered inside the prometheus subchart)
and overrides the legacy observability.hostMetrics.provider when set.

For the "openshift-monitoring" provider the mechanism, tunables
(global.hostMetrics.openshiftMonitoring.*) and RBAC live in the prometheus
wrapper chart.

Note: that chart always renders as a dependency of randoli-agent, i.e. in
subchart values scope, where only global.* is visible — never the parent's
observability.* values. Its copy of the predicate is therefore duplicated
there deliberately; keep the two in sync.
*/}}
{{- define "hostmetrics.provider" -}}
{{- $global := dig "hostMetrics" "provider" "" (.Values.global | default dict) -}}
{{- $local := dig "hostMetrics" "provider" "" (.Values.observability | default dict) -}}
{{- $global | default ($local | default "node-exporter") -}}
{{- end -}}

{{- define "enable.otel-host-metrics" -}}
{{- if and .Values.tags.observability (eq (include "hostmetrics.provider" .) "otel-host-metrics") -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

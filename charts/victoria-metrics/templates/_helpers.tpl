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

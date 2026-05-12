{{/*
Builds the opencost scrape target URL.
Uses global.opencost.url if set; otherwise defaults to the randoli-cmk-opencost service.
*/}}
{{- define "prometheus.opencost.url" -}}
{{- if .Values.global.opencost.url -}}
{{- print .Values.global.opencost.url | replace "http://" "" -}}
{{- else -}}
{{- printf "randoli-cmk-opencost.%s.svc:9003" .Release.Namespace -}}
{{- end -}}
{{- end -}}

{{/*
Builds the network-cost-metrics scrape target URL.
Uses global.networkCostMetrics.url if set; otherwise defaults to the randoli-cmk-opencost sidecar port.
*/}}
{{- define "prometheus.networkCostMetrics.url" -}}
{{- if .Values.global.networkCostMetrics.url -}}
{{- print .Values.global.networkCostMetrics.url | replace "http://" "" -}}
{{- else -}}
{{- printf "randoli-cmk-opencost.%s.svc:8080" .Release.Namespace -}}
{{- end -}}
{{- end -}}

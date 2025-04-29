{{- define "prometheus-server-endpoint" -}}
  {{- if .Values.global.prometheus.install -}}
    {{- printf "http://randoli-prometheus.%s.svc:80" .Release.Namespace -}}
  {{- else if .Values.global.prometheus.url -}}
    {{ tpl .Values.global.prometheus.url . }}
  {{- end -}}
{{- end -}}
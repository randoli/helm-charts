{{- define "vector.multilineLogs.transform" -}}
{{- $include := .include -}}
merge_multiline_logs:
  expire_after_ms: 2000
  group_by:
    - kubernetes.pod_name
    - kubernetes.container_name
    - stream
  inputs:
  {{- if gt (len $include) 0 }}
  {{- range $ns := $include }}
    - k8s_log_source_{{ $ns | replace "-" "_" }}
  {{- end }}
  {{- else }}
    - k8s_log_source
  {{- end }}
  merge_strategies:
    message: concat_newline
  starts_when: >-
    match(string!(.message),
    r'(^\d{4}-\d{2}-\d{2}|^\d{2}:\d{2}:\d{2}|^\{"|^[A-Z]+\s)')
  type: reduce
{{- end -}}
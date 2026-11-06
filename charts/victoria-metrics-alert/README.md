# victoria-metrics-alert (Randoli wrapper)

Thin wrapper around [`victoria-metrics/victoria-metrics-alert`](https://docs.victoriametrics.com/helm/victoria-metrics-alert/)
`0.42.1` (app `v1.145.0`). It provides alerting for the VictoriaMetrics metrics
backend, deploying two components from a single upstream chart:

- **vmalert** — evaluates alert rules against `vmsingle`
  (`http://randoli-obs-victoria-metrics:8428`) and forwards firing alerts to the
  Alertmanager below.
- **Alertmanager** — bundled by the upstream chart, exposed as the Service
  `randoli-obs-alerts:9093`. This matches the agent's existing
  `PROMETHEUS_ALERTMANAGER_URL`, so the same value works whether the backend is
  Prometheus or VictoriaMetrics. When `alertmanager.enabled` is true, vmalert's
  `--notifier.url` auto-targets it.

The Randoli email/slack notification templates (`files/randoli/`) are published
as the `randoli-alert-templates` ConfigMap (`templates/randoli-alerts-template-cm.yaml`)
and mounted into Alertmanager at `/randoli/templates`.

Alertmanager setup:

- **Config:** ConfigMap `randoli-obs-alerts`, key `alertmanager.yml`. The chart
  only seeds a `default-receiver`; the agent then owns it. `helm upgrade` keeps
  the live value.
- **Reload:** a `config-reloader` sidecar reloads on config or template changes.
- **Storage:** 50Mi PVC `randoli-obs-alerts`, so silences and the notification
  log survive restarts.

**Switching from Prometheus:** the Prometheus StatefulSet `randoli-obs-alerts` is
replaced by this Deployment, and `helm upgrade` keeps the agent's config (ArgoCD
needs `ignoreDifferences` on `/data/alertmanager.yml` with
`RespectIgnoreDifferences=true`). Afterwards, delete the leftover PVC
`storage-randoli-obs-alerts-0`; with ArgoCD, sync with pruning.

This chart installs only when the VictoriaMetrics backend is selected
(`global.victoriaMetrics.install=true`).

## Exposed values

Override upstream values through the `victoria-metrics-alert.victoria-metrics-alert.*`
path from the umbrella chart:

| Value | Default | Purpose |
|-------|---------|---------|
| `...server.datasource.url` | `http://randoli-obs-victoria-metrics:8428` | vmsingle query endpoint |
| `...server.config.alerts.groups` | `[]` | Alert rule groups (extensible) |
| `...server.configMap` | `""` | Existing ConfigMap with rules (alternative to inline groups) |
| `...alertmanager.enabled` | `true` | Deploy the bundled Alertmanager |
| `...alertmanager.fullnameOverride` | `randoli-obs-alerts` | Alertmanager Service name (keep it — the agent targets this) |
| `...alertmanager.config.route` / `receivers` | default-receiver | Initial config only; the agent manages it after install |
| `...alertmanager.config.templates` | `/randoli/templates/*.tmpl` | Notification templates glob |

See the [upstream values](https://github.com/VictoriaMetrics/helm-charts/blob/master/charts/victoria-metrics-alert/values.yaml)
for the full set.

### Adding alert rules

```yaml
victoria-metrics-alert:
  victoria-metrics-alert:
    server:
      config:
        alerts:
          groups:
            - name: example
              rules:
                - alert: HighMemoryUsage
                  expr: process_resident_memory_bytes > 1e9
                  for: 5m
                  labels: { severity: warning }
```

### Configuring notifications

Slack/email receivers are managed by the agent from the control plane, not chart
values. Its config references the mounted Randoli templates (e.g.
`{{ template "randoli.slack.text" . }}`).

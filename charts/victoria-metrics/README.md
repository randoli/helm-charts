# victoria-metrics (Randoli wrapper)

Thin wrapper around [`victoria-metrics/victoria-metrics-single`](https://docs.victoriametrics.com/helm/victoria-metrics-single/)
`0.40.1` (app `v1.145.0`). It deploys a single VictoriaMetrics node (`vmsingle`)
as the **scalability-oriented alternative to Prometheus** for metric storage and
querying.

`vmsingle` is PromQL-compatible, so the Randoli agent, telemetry-proxy, and
netobserv flow-collector query it unchanged. It serves three roles:

| Role | Endpoint |
|------|----------|
| PromQL query | `http://randoli-obs-victoria-metrics.<ns>.svc:8428/api/v1/query_range` |
| OTLP metric ingest (from the OTel Collector) | `http://randoli-obs-victoria-metrics.<ns>.svc:8428/opentelemetry/v1/metrics` |
| Self-scrape | via `-promscrape.config` from the `randoli-vm-scrape-config` ConfigMap |

The scrape ConfigMap (`templates/configmap-scrape-config.yaml`) mirrors the
Prometheus `scrape_configs` and discovers targets through the
`randoli.prometheus.io/*` annotations — including the shared node-exporter and
kube-state-metrics deployed by `charts/node-exporter` and
`charts/kube-state-metrics`.

## Selecting VictoriaMetrics

This chart only installs when the umbrella chart selects the VictoriaMetrics
backend:

```bash
helm install randoli charts/randoli-agent -n randoli-agents \
  --set global.metrics.provider=victoria-metrics \
  --set global.prometheus.install=false \
  --set global.victoriaMetrics.install=true
```

## Exposed values

Override upstream values through the `victoria-metrics.victoria-metrics-single.*`
path from the umbrella chart:

| Value | Default | Purpose |
|-------|---------|---------|
| `...server.retentionPeriod` | `30d` | Data retention window. Units `h`/`d`/`w`/`y` (bare number = months), min `24h`. e.g. `90d`, `1y` |
| `...server.persistentVolume.size` | `50Gi` | PVC size for the `/storage` data path |
| `...server.persistentVolume.storageClassName` | `""` | StorageClass (`""` = cluster default) |
| `...server.resources` | 2 CPU / 2Gi lim | Container resource requests/limits |
| `...server.scrape.enabled` | `true` | Enable self-scraping |
| `...server.scrape.configMap` | `randoli-vm-scrape-config` | ConfigMap holding `scrape.yml` |
| `...server.extraArgs."opentelemetry.usePrometheusNaming"` | `"true"` | Normalize OTLP names/labels to Prometheus style (see below) |
| `...server.tolerations` / `nodeSelector` / `affinity` | `[]` / `{}` / `{}` | Scheduling (not inherited from `global.*`) |

See the [upstream values](https://github.com/VictoriaMetrics/helm-charts/blob/master/charts/victoria-metrics-single/values.yaml)
for the full set.

### OTLP metric naming

`-opentelemetry.usePrometheusNaming=true` is enabled so OTLP-ingested metric and
label names are rewritten to Prometheus conventions (dots → underscores, unit /
`_total` suffixes) — matching Prometheus's OTLP receiver. Without it,
VictoriaMetrics would keep dotted OTLP names (e.g.
`randoli.metrics.otel.netobserv.cluster_external_egress_bytes_total`) and break
PromQL queries written against the underscore form. Only the OTLP write path is
affected; scraped metrics already use Prometheus naming. Requires app
≥ `v1.142.0` (the Unit-suffix fix); this chart ships `v1.145.0`.

### Retention

The 30-day default is set via `server.retentionPeriod: "30d"`. Make sure
`server.persistentVolume.size` is large enough to hold the retained data for your
ingestion rate; VictoriaMetrics uses far less disk per sample than Prometheus but
high-cardinality / high-churn workloads still need headroom.

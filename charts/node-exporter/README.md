# node-exporter (Randoli wrapper)

Thin wrapper around [`prometheus-community/prometheus-node-exporter`](https://github.com/prometheus-community/helm-charts/tree/main/charts/prometheus-node-exporter)
`4.42.0` (app `1.8.2`). It deploys the node-exporter DaemonSet that exposes
per-node hardware and OS metrics.

This chart used to be a nested sub-dependency of the bundled Prometheus chart.
It is now a standalone wrapper so that **both** metrics backends (Prometheus and
VictoriaMetrics) can scrape the same node-exporter. Its Service is named
`randoli-obs-prometheus-node-exporter` and is annotated with
`randoli.prometheus.io/scrape: "true"` so the active metrics store scrapes it.

## Enabling / disabling

Installation is controlled by the umbrella chart toggle (default enabled):

```bash
--set observability.nodeExporter.enabled=false
```

Disable it when using `observability.hostMetrics.provider: otel-host-metrics`
(the OTel host-metrics DaemonSet replaces node-exporter).

## Exposed values

Override upstream values through the `node-exporter.prometheus-node-exporter.*`
path from the umbrella chart. Commonly tuned:

| Value | Default | Purpose |
|-------|---------|---------|
| `node-exporter.prometheus-node-exporter.fullnameOverride` | `randoli-obs-prometheus-node-exporter` | Service/DaemonSet name (keep it — scrape jobs target this name) |
| `node-exporter.prometheus-node-exporter.service.annotations` | `randoli.prometheus.io/scrape: "true"` | Scrape opt-in annotation |
| `node-exporter.prometheus-node-exporter.tolerations` | `[]` | DaemonSet tolerations (typically permissive so it runs on every node) |
| `node-exporter.prometheus-node-exporter.resources` | `{}` | Container resource requests/limits |

See the [upstream values](https://github.com/prometheus-community/helm-charts/blob/main/charts/prometheus-node-exporter/values.yaml)
for the full set.

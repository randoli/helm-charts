# kube-state-metrics (Randoli wrapper)

Thin wrapper around [`prometheus-community/kube-state-metrics`](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-state-metrics)
`5.27.0` (app `2.14.0`). It exposes Kubernetes object-state metrics (pods,
deployments, nodes, jobs, …) consumed by both observability and cost management.

This chart used to be a nested sub-dependency of the bundled Prometheus chart.
It is now a standalone wrapper so that **both** metrics backends (Prometheus and
VictoriaMetrics) can scrape the same instance. Its Service is named
`randoli-obs-kube-state-metrics` and is annotated with
`randoli.prometheus.io/scrape: "true"` so the active metrics store scrapes it.

## Enabling / disabling

Installation is controlled by the umbrella chart toggle (default enabled):

```bash
--set observability.kubeStateMetrics.enabled=false
```

## Exposed values

Override upstream values through the `kube-state-metrics.kube-state-metrics.*`
path from the umbrella chart. Commonly tuned:

| Value | Default | Purpose |
|-------|---------|---------|
| `kube-state-metrics.kube-state-metrics.fullnameOverride` | `randoli-obs-kube-state-metrics` | Service/Deployment name (keep it — scrape jobs target this name) |
| `kube-state-metrics.kube-state-metrics.prometheusScrape` | `false` | Suppress the upstream `prometheus.io/scrape` annotation |
| `kube-state-metrics.kube-state-metrics.service.annotations` | `randoli.prometheus.io/scrape: "true"` | Scrape opt-in annotation |
| `kube-state-metrics.kube-state-metrics.resources` | `{}` | Container resource requests/limits |

See the [upstream values](https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-state-metrics/values.yaml)
for the full set.

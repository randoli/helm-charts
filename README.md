# Randoli Helm Chart Public Registry

## How to install the LocalControl Plane & Agent

### Prerequisits.
You need to setup an Account using the [Signup page](https://signup.randoli.io/?product=observability%2Bcost) 
For more information please check the [Getting Start Guide](https://docs.insights.randoli.io/getting-started/step-0)

[!Tip]
If it's your first time, we recommend you read the `Getting Started Guide` and follow **guided onboarding flow** when you sign up for the account

### Helm Chart Installation
Create the namespace & apply the secrets downloaded from the Console
```
kubectl create ns randoli-agents
kubectl create -f xxxx-credentials.yaml
```

Add the repository
```
helm repo add randoli https://randoli.github.io/helm-charts
```

Install the Helm Chart
```
helm install randoli randoli/randoli-agent -n randoli-agents --set tags.costManagement=true --set tags.observability=true
```

For more details see [Randoli Product Documentation](https://docs.randoli.io/getting-started/step-0).

## Tempo deployment mode

The chart ships two Tempo deployments and lets you pick exactly one at
install time:

| Mode           | Backing chart                  | Use it when                                                                                                                                  |
|----------------|--------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------|
| `singleBinary` | `grafana/tempo` (default)      | Small or single-tenant clusters. All Tempo components run in one pod; storage is a single PVC; quick to install with no external dependencies. |
| `distributed`  | `grafana/tempo-distributed`    | Production / higher trace volume. Distributor, ingester, querier, query-frontend, and compactor each run as separate workloads so they can be scaled and (with object storage) made HA. |

Selection is controlled by two booleans under `observability.tempo`. They
are mutually exclusive — set exactly one to `true`:

```yaml
observability:
  tempo:
    singleBinary:
      enabled: true   # default
    distributed:
      enabled: false
```

Switching to distributed mode:

```
helm install randoli randoli/randoli-agent -n randoli-agents \
  --set tags.observability=true \
  --set observability.tempo.singleBinary.enabled=false \
  --set observability.tempo.distributed.enabled=true
```

The agent's trace read/write endpoints follow the mode automatically:

| Mode           | OTLP ingest (gRPC)                                                  | HTTP query API                                                          |
|----------------|---------------------------------------------------------------------|-------------------------------------------------------------------------|
| `singleBinary` | `randoli-obs-tempo.<namespace>.svc:4317`                            | `http://randoli-obs-tempo.<namespace>.svc:3200`                         |
| `distributed`  | `randoli-obs-tempo-dist-distributor.<namespace>.svc:4317`           | `http://randoli-obs-tempo-dist-query-frontend.<namespace>.svc:3200`     |

To point the agent at a managed/external Tempo instead of either deployment,
set `observability.traceConfig.storage.url` (read API) and
`observability.traceConfig.storage.urlOtlp` (OTLP ingest). These overrides
take precedence over both modes.

Distributed mode defaults to local-filesystem storage on the ingester so the
chart installs out of the box, but production deployments should point it at
object storage (S3 / GCS / Azure):

```
helm install randoli randoli/randoli-agent -n randoli-agents \
  --set observability.tempo.singleBinary.enabled=false \
  --set observability.tempo.distributed.enabled=true \
  --set tempoDistributed.tempo-distributed.storage.trace.backend=s3 \
  --set tempoDistributed.tempo-distributed.storage.trace.s3.bucket=<bucket> \
  --set tempoDistributed.tempo-distributed.storage.trace.s3.endpoint=s3.<region>.amazonaws.com
```

See the [upstream tempo-distributed values reference](https://github.com/grafana/helm-charts/blob/main/charts/tempo-distributed/values.yaml)
for the full set of object-storage and per-component scaling knobs.

## Telemetry proxy

All telemetry signals (logs, traces, metrics) flow from the Randoli console
to the in-cluster Loki / Tempo / Prometheus stacks via the telemetry proxy
(`randoli-tproxy`), which also enforces auth via Keycloak. Its config lives
under `observability.telemetry.proxy.*`:

| Value | Purpose | Default |
|-------|---------|---------|
| `observability.telemetry.proxy.image` | Container image for the proxy Deployment | `docker.io/randoli/telemetry-proxy:0.1.2` |
| `observability.telemetry.proxy.cors` | `CORS_ALLOW_ORIGIN` — `*` or comma-separated origin list. Empty falls back to the default Randoli console origins. | `"*"` |
| `observability.telemetry.proxy.keycloakIssuer` | `KEYCLOAK_ISSUER_URL` — Keycloak realm issuer URL. Empty falls back to `https://sso.randoli.io/auth/realms/sso`. | unset |
| `observability.telemetry.proxy.tunnelServerUrl` | `TUNNEL_SERVER_URL` — only injected into the proxy ConfigMap when non-empty. | `""` |
| `observability.telemetry.proxy.mode` | `MODE` — only injected into the proxy ConfigMap when non-empty. | `""` |

`tunnelServerUrl` and `mode` are additive: leaving them empty omits the
corresponding env vars from the proxy's ConfigMap entirely, so the proxy
image's built-in defaults apply. Example:

```
helm install randoli randoli/randoli-agent -n randoli-agents \
  --set tags.observability=true \
  --set observability.telemetry.proxy.keycloakIssuer=https://sso.example.com/auth/realms/randoli \
  --set observability.telemetry.proxy.tunnelServerUrl=https://tunnel.example.com \
  --set observability.telemetry.proxy.mode=tunnel
```

## Storage and retention

Each observability backend (Prometheus, Loki, Tempo) exposes three knobs at
the umbrella chart level: data retention period, PVC size, and storage
class. The defaults set 7-day retention across all three.

| Backend                | Retention                                                                          | PVC size                                                                            | StorageClass                                                                          |
|------------------------|------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------|
| Prometheus             | `prometheus.prometheus.server.retention` (default `7d`)                            | `prometheus.prometheus.server.persistentVolume.size` (`50Gi`)                       | `prometheus.prometheus.server.persistentVolume.storageClass`                          |
| Loki                   | `loki.loki.loki.limits_config.retention_period` (default `168h`)                   | `loki.loki.singleBinary.persistence.size` (`100Gi`)                                 | `loki.loki.singleBinary.persistence.storageClass`                                     |
| Tempo (single-binary)  | `tempo.tempo.tempo.retention` (default `168h`)                                     | `tempo.tempo.persistence.size` (`50Gi`)                                             | `tempo.tempo.persistence.storageClassName`                                            |
| Tempo (distributed)    | `tempoDistributed.tempo-distributed.compactor.config.compaction.block_retention` (default `168h`) | `tempoDistributed.tempo-distributed.ingester.persistence.size` (`50Gi`, per ingester replica) | `tempoDistributed.tempo-distributed.ingester.persistence.storageClass`                |

Example: change Prometheus to 14 days, Loki to 30 days, Tempo to 3 days,
and target a specific storage class for each:

```
helm install randoli randoli/randoli-agent -n randoli-agents \
  --set tags.observability=true --set tags.costManagement=true \
  --set prometheus.prometheus.server.retention=14d \
  --set prometheus.prometheus.server.persistentVolume.storageClass=gp3-retain \
  --set loki.loki.loki.limits_config.retention_period=720h \
  --set loki.loki.singleBinary.persistence.storageClass=gp3-retain \
  --set tempo.tempo.tempo.retention=72h \
  --set tempo.tempo.persistence.storageClassName=gp3-retain
```

The Tempo row above is for `singleBinary` mode (the default). In
`distributed` mode the equivalent flags are
`tempoDistributed.tempo-distributed.compactor.config.compaction.block_retention`
and `tempoDistributed.tempo-distributed.ingester.persistence.storageClass`.

Notes:
- Prometheus also accepts a `retentionSize` cap (default `45GB`) which works
  as a disk-usage safety net independent of the time window.
- Loki retention is enforced by the compactor on the TSDB store; the chart
  enables `retention_enabled: true` automatically when retention is set.
- An empty StorageClass value means "use the cluster's default StorageClass".
  Use a StorageClass with `reclaimPolicy: Retain` if you want PVs to survive
  PVC deletion.
## Persistent storage retention

The charts deliberately **do not delete PersistentVolumeClaims** for the
randoli-agent, Loki, Tempo (single-binary and distributed-mode ingester),
or Prometheus on `helm uninstall`. Their PVCs (and the underlying PVs)
survive uninstall so data is not lost by accident.

If you no longer need the data, delete the PVCs manually after uninstall:

```
kubectl -n randoli-agents get pvc
kubectl -n randoli-agents delete pvc <name>
```

Whether the underlying PV is then deleted or retained depends on the
`reclaimPolicy` of the StorageClass that provisioned it (`Delete` is the
default for most cloud StorageClasses). Use a StorageClass with
`reclaimPolicy: Retain` if you want PVs to survive PVC deletion as well.

Note: because the PVCs are kept (`helm.sh/resource-policy: keep` /
`persistentVolumeClaimRetentionPolicy: Retain`), reinstalling into the same
namespace will fail with "object already exists" unless you adopt the
existing PVCs — use `helm install --take-ownership` (Helm 3.10+) or delete
the orphaned PVCs first.

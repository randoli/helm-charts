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
| `singleBinary` | `grafana/tempo` (default)      | Small or single-tenant clusters. All Tempo components run in one pod; storage is a single PVC; quick to install with no external dependencies. This mode should not be used in production |
| `distributed`  | `grafana/tempo-distributed`    | Production / higher trace volume. Distributor, ingester, querier, query-frontend, and compactor each run as separate workloads so they can be scaled and (with object storage) made HA. |

Selection is controlled by two booleans under `observability.tempo`. They are mutually exclusive — set exactly one to `true`

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

To point the agent at a managed/external Tempo instead of either bundled deployment, set both URLs under `observability.traceConfig.storage.tempo`. These overrides take precedence over the mode-derived defaults.

Tempo's push and query use different protocols and ports (OTLP gRPC on `:4317` vs HTTP on `:3200`), so external Tempo always requires **both** URLs:

```
--set observability.traceConfig.storage.tempo.writeUrl=my-tempo-distributor.example.svc:4317 \
--set observability.traceConfig.storage.tempo.readUrl=http://my-tempo-query-frontend.example.svc:3200
```

When both fields are left empty (the default), the chart uses the in-cluster Tempo it ships and routes the push/query endpoints from the table above automatically.

Distributed mode defaults to local-filesystem storage on the ingester so the chart installs out of the box, but production deployments should point it at object storage (S3 / GCS / Azure):

```
helm install randoli randoli/randoli-agent -n randoli-agents \
  --set observability.tempo.singleBinary.enabled=false \
  --set observability.tempo.distributed.enabled=true \
  --set tempoDistributed.tempo-distributed.storage.trace.backend=s3 \
  --set tempoDistributed.tempo-distributed.storage.trace.s3.bucket=<bucket> \
  --set tempoDistributed.tempo-distributed.storage.trace.s3.endpoint=s3.<region>.amazonaws.com
```

See the [upstream tempo-distributed values reference](https://github.com/grafana/helm-charts/blob/main/charts/tempo-distributed/values.yaml) for the full set of object-storage and per-component scaling knobs.

## Loki deployment mode

The chart ships two Loki deployments and lets you pick exactly one at
install time:

| Mode           | Backing chart                       | Use it when                                                                                                                                  |
|----------------|-------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------|
| `singleBinary` | `grafana/loki` (default)            | Small or single-tenant clusters. All Loki components run in one pod backed by a single PVC; quick to install with no external dependencies. This mode should not be used in production. |
| `distributed`  | `grafana/loki` (microservices mode) | Production / higher log volume. Distributor, ingester, querier, query-frontend, query-scheduler, compactor, and index-gateway each run as separate workloads so they can be scaled independently and (with object storage) made HA. |

Selection is controlled by two booleans under `observability.loki`. They are mutually exclusive — set exactly one to `true`

```yaml
observability:
  loki:
    singleBinary:
      enabled: true   # default
    distributed:
      enabled: false
```

Switching to distributed mode:

```
helm install randoli randoli/randoli-agent -n randoli-agents \
  --set tags.observability=true \
  --set observability.loki.singleBinary.enabled=false \
  --set observability.loki.distributed.enabled=true
```

The agent's log push (Vector → Loki) and query (telemetry-proxy → Loki) endpoints follow the mode automatically:

| Mode           | Push endpoint                                                  | Query endpoint                                                          |
|----------------|----------------------------------------------------------------|-------------------------------------------------------------------------|
| `singleBinary` | `randoli-obs-loki.<namespace>.svc:3100`                        | `randoli-obs-loki.<namespace>.svc:3100`                                 |
| `distributed`  | `randoli-obs-loki-dist-distributor.<namespace>.svc:3100`       | `randoli-obs-loki-dist-query-frontend.<namespace>.svc:3100`             |

To point the agent at an external Loki instead of either bundled deployment, set the URLs under `observability.logs.loki`. These overrides take precedence over the mode-derived defaults.

- **External distributed Loki** — set both endpoints (Vector pushes to the distributor, telemetry-proxy reads from the query-frontend):
  ```
  --set observability.logs.loki.writeUrl=http://my-loki-distributor.example.svc:3100 \
  --set observability.logs.loki.readUrl=http://my-loki-query-frontend.example.svc:3100
  ```
- **External single-binary Loki** — set only `writeUrl`; `readUrl` falls back to it:
  ```
  --set observability.logs.loki.writeUrl=http://my-loki.example.svc:3100
  ```

When both fields are left empty (the default), the chart uses the in-cluster Loki it ships and routes the push/query endpoints from the table above automatically.

Distributed mode requires real object storage — distributed Loki cannot use the local filesystem, and the bundled MinIO subchart is **off by default** so production installs aren't silently backed by an in-cluster PVC. You must point Loki at a cloud object store (S3 / GCS / Azure) at install time:

```
helm install randoli randoli/randoli-agent -n randoli-agents \
  --set observability.loki.singleBinary.enabled=false \
  --set observability.loki.distributed.enabled=true \
  --set lokiDistributed.loki.loki.storage.type=s3 \
  --set lokiDistributed.loki.loki.storage.s3.region=us-east-1 \
  --set lokiDistributed.loki.loki.storage.bucketNames.chunks=my-loki-chunks \
  --set lokiDistributed.loki.loki.storage.bucketNames.ruler=my-loki-ruler \
  --set lokiDistributed.loki.loki.storage.bucketNames.admin=my-loki-admin
```

GCS and Azure examples (with their auth knobs) live in the [wrapper values file](charts/loki-distributed/values.yaml). See the [upstream loki values reference](https://github.com/grafana/loki/blob/main/production/helm/loki/values.yaml) for the full set of object-storage and per-component scaling knobs.

## Telemetry proxy

The Telemetry Proxy (`randoli-tproxy`) acts as the bridge in between Cluster and the Randoli Platform and faciliates querying logs, traces and metrics on demand.
The config lives under `observability.telemetry.proxy.*`:

| Value | Purpose | Default |
|-------|---------|---------|
| `observability.telemetry.proxy.image` | Container image for the proxy Deployment | `docker.io/randoli/telemetry-proxy:0.1.2` |
| `observability.telemetry.proxy.cors` | `CORS_ALLOW_ORIGIN` — `*` or comma-separated origin list. Empty falls back to the default Randoli console origins. | `"*"` |
| `observability.telemetry.proxy.keycloakIssuer` | `KEYCLOAK_ISSUER_URL` — Keycloak realm issuer URL. Empty falls back to `https://sso.randoli.io/auth/realms/sso`. | unset |
| `observability.telemetry.proxy.tunnelServerUrl` | `TUNNEL_SERVER_URL` — only injected into the proxy ConfigMap when non-empty. | `""` |
| `observability.telemetry.proxy.mode` | `MODE` — only injected into the proxy ConfigMap when non-empty. | `""` |

`tunnelServerUrl` and `mode` are additive: leaving them empty omits the corresponding env vars from the proxy's ConfigMap entirely, 
so the proxy image's built-in defaults apply. Example:
```
helm install randoli randoli/randoli-agent -n randoli-agents \
  --set tags.observability=true \
  --set observability.telemetry.proxy.keycloakIssuer=https://sso.example.com/auth/realms/randoli \
  --set observability.telemetry.proxy.tunnelServerUrl=https://tunnel.example.com \
  --set observability.telemetry.proxy.mode=tunnel
```

## Storage and retention

Each observability backend (Prometheus, Loki, Tempo) exposes three config options at the umbrella chart level: data retention period, PVC size, and storage
class. The defaults set 30 days of retention across all three.

| Backend                | Retention                                                                          | PVC size                                                                            | StorageClass                                                                          |
|------------------------|------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------|
| Prometheus             | `prometheus.prometheus.server.retention` (default `7d`)                            | `prometheus.prometheus.server.persistentVolume.size` (`50Gi`)                       | `prometheus.prometheus.server.persistentVolume.storageClass`                          |
| Loki (single-binary)   | `loki.loki.loki.limits_config.retention_period` (default `168h`)                   | `loki.loki.singleBinary.persistence.size` (`100Gi`)                                 | `loki.loki.singleBinary.persistence.storageClass`                                     |
| Loki (distributed)     | `lokiDistributed.loki.loki.limits_config.retention_period` (default `720h`)        | `lokiDistributed.loki.ingester.persistence.claims[0].size` (`50Gi`, per ingester replica) | `lokiDistributed.loki.ingester.persistence.claims[0].storageClass`              |
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
  --set tempo.tempo.tempo.retention=720h \
  --set tempo.tempo.persistence.storageClassName=gp3-retain
```

The Tempo row above is for `singleBinary` mode (the default). In
`distributed` mode the equivalent flags are
`tempoDistributed.tempo-distributed.compactor.config.compaction.block_retention`
and `tempoDistributed.tempo-distributed.ingester.persistence.storageClass`.

Notes:
- Prometheus also accepts a `retentionSize` cap (default `45GB`) which works as a disk-usage safety net independent of the time window.
- Loki retention is enforced by the compactor on the TSDB store; the chart enables `retention_enabled: true` automatically when retention is set.
- An empty StorageClass value means "use the cluster's default StorageClass". Use a StorageClass with `reclaimPolicy: Retain` if you want PVs to survive PVC deletion.
## Persistent storage retention

The charts deliberately **do not delete PersistentVolumeClaims** for the randoli-agent, Loki, Tempo (single-binary and distributed-mode ingester), or Prometheus on `helm uninstall`. Their PVCs (and the underlying PVs) survive uninstall so data is not lost by accident.

If you no longer need the data, delete the PVCs manually after uninstall:

```
kubectl -n randoli-agents get pvc
kubectl -n randoli-agents delete pvc <name>
```

Whether the underlying PV is then deleted or retained depends on the `reclaimPolicy` of the StorageClass that provisioned it (`Delete` is the default for most cloud StorageClasses). Use a StorageClass with `reclaimPolicy: Retain` if you want PVs to survive PVC deletion as well.

Note: because the PVCs are kept (`helm.sh/resource-policy: keep` / `persistentVolumeClaimRetentionPolicy: Retain`), reinstalling into the same namespace will fail with "object already exists" unless you adopt the existing PVCs — use `helm install --take-ownership` (Helm 3.10+) or delete the orphaned PVCs first.

## Upgrading

`helm upgrade` may fail with a server-side-apply field-ownership conflict on the netobserv `FlowCollector`:

```
Error: UPGRADE FAILED: conflict occurred while applying object /cluster flows.netobserv.io/v1beta2,
Kind=FlowCollector: Apply failed with 1 conflict:
conflict with "manager" using flows.netobserv.io/v1beta2: .spec.exporters
```

The `FlowCollector` named `cluster` is templated by this chart, but the netobserv-operator reconciles the same CR and writes back to `.spec.exporters` under its own field-manager (`"manager"`). Once that happens, Kubernetes records the operator as the field owner and rejects a subsequent Helm apply that tries to overwrite it.

Pass `--force-conflicts` on upgrade (Helm 3.14+) to take ownership back and overwrite the operator's value:

```
helm upgrade randoli randoli/randoli-agent -n randoli-agents \
  --force-conflicts \
  --set tags.observability=true --set tags.costManagement=true --set tags.security=true
```

This is safe: the chart template is the intended source of truth for `.spec.exporters`; the netobserv-operator only writes defaults / normalization back into the field.

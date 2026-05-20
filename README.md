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

## Storage and retention

Each observability backend (Prometheus, Loki, Tempo) exposes three knobs at
the umbrella chart level: data retention period, PVC size, and storage
class. The defaults set 7-day retention across all three.

| Backend     | Retention                                                       | PVC size                                                    | StorageClass                                                       |
|-------------|-----------------------------------------------------------------|-------------------------------------------------------------|--------------------------------------------------------------------|
| Prometheus  | `prometheus.prometheus.server.retention` (default `7d`)         | `prometheus.prometheus.server.persistentVolume.size` (`50Gi`) | `prometheus.prometheus.server.persistentVolume.storageClass`       |
| Loki        | `loki.loki.loki.limits_config.retention_period` (default `168h`) | `loki.loki.singleBinary.persistence.size` (`100Gi`)         | `loki.loki.singleBinary.persistence.storageClass`                  |
| Tempo       | `tempo.tempo.tempo.retention` (default `168h`)                  | `tempo.tempo.persistence.size` (`50Gi`)                     | `tempo.tempo.persistence.storageClassName`                         |

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

Notes:
- Prometheus also accepts a `retentionSize` cap (default `45GB`) which works
  as a disk-usage safety net independent of the time window.
- Loki retention is enforced by the compactor on the TSDB store; the chart
  enables `retention_enabled: true` automatically when retention is set.
- An empty StorageClass value means "use the cluster's default StorageClass".
  Use a StorageClass with `reclaimPolicy: Retain` if you want PVs to survive
  PVC deletion.

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

## Persistent storage retention

The charts deliberately **do not delete PersistentVolumeClaims** for the
randoli-agent, Loki, Tempo, or Prometheus on `helm uninstall`. Their PVCs
(and the underlying PVs) survive uninstall so data is not lost by accident.

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

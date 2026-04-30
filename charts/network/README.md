# charts/network

Randoli wrapper chart for the [NetObserv Network Observability Operator](https://github.com/netobserv/network-observability-operator) (v1.11.3).

This chart installs the operator as a standard Helm dependency and handles TLS certificate provisioning **without requiring cert-manager** to be installed in the cluster.

---

## How it works

The netobserv operator and its sub-components require TLS certificates in several places. All resource names are hardcoded in the upstream chart:

| Resource | Kind | Namespace | Purpose |
|---|---|---|---|
| `webhook-server-cert` | Secret | release namespace | CRD conversion webhook |
| `manager-metrics-tls` | Secret | release namespace | Operator metrics endpoint |
| `flowlogs-pipeline-cert` | Secret | `netobserv` | TLS between eBPF agents and flowlogs-pipeline |
| `netobserv-ca` | ConfigMap | `netobserv` | CA bundle used by eBPF agents to verify FLP cert |
| `netobserv-ca` | ConfigMap | `netobserv-privileged` | CA bundle used by eBPF agents (privileged namespace) |

The upstream chart relies on cert-manager and its trust extension to create all of these. This wrapper disables that (`certManager.enable: false`) and instead offers two modes to provision certificates without cert-manager.

---

## TLS Mode A — Pre-existing Secret (recommended)

You generate all required certificates using `openssl`, bundle them into a single Kubernetes Secret, then reference it during `helm install`. Helm reads the Secret at render time and copies the material into all required resources above.

**Advantages:** No runtime Job, no cluster-side dependencies, fully deterministic install.

### Step 1 — Generate the certificate chain

Replace `<namespace>` with your install namespace (e.g. `randoli-agents`).

```bash
# 1. Self-signed CA
openssl req -x509 -nodes -newkey rsa:2048 -days 3650 \
  -subj "/CN=netobserv-ca" \
  -addext "basicConstraints=critical,CA:TRUE" \
  -addext "keyUsage=critical,keyCertSign,cRLSign" \
  -keyout ca.key -out ca.crt

# 2. Webhook + metrics cert (signed by CA)
#    SANs must cover both operator service DNS names.
openssl req -newkey rsa:2048 -nodes \
  -subj "/CN=netobserv-webhook-service.<namespace>.svc" \
  -addext "subjectAltName=DNS:netobserv-webhook-service.<namespace>.svc,DNS:netobserv-webhook-service.<namespace>.svc.cluster.local,DNS:netobserv-metrics-service.<namespace>.svc,DNS:netobserv-metrics-service.<namespace>.svc.cluster.local" \
  -keyout webhook.key -out webhook.csr

openssl x509 -req -in webhook.csr \
  -CA ca.crt -CAkey ca.key -CAcreateserial -days 3650 \
  -copy_extensions copy \
  -out webhook.crt

# 3. FlowLogs-Pipeline cert (signed by CA)
#    SAN must match the flowlogs-pipeline service in the netobserv namespace.
openssl req -newkey rsa:2048 -nodes \
  -subj "/CN=flowlogs-pipeline.netobserv.svc" \
  -addext "subjectAltName=DNS:flowlogs-pipeline.netobserv.svc,DNS:flowlogs-pipeline.netobserv.svc.cluster.local" \
  -keyout flp.key -out flp.csr

openssl x509 -req -in flp.csr \
  -CA ca.crt -CAkey ca.key -CAcreateserial -days 3650 \
  -copy_extensions copy \
  -out flp.crt
```

> **Note:** `-copy_extensions copy` requires OpenSSL 3.x. On older systems, use `-extfile` and `-extensions` flags instead.

### Step 2 — Create the Kubernetes Secret

Bundle all cert material into a single generic Secret (not `tls` type, as that only supports two keys):

```bash
kubectl create namespace <namespace>   # if it does not exist yet

kubectl create secret generic netobserv-tls-certs \
  --from-file=tls.crt=webhook.crt \
  --from-file=tls.key=webhook.key \
  --from-file=ca.crt=ca.crt \
  --from-file=flp.crt=flp.crt \
  --from-file=flp.key=flp.key \
  -n <namespace>
```

### Step 3 — Install the chart

```bash
# Standalone
helm install randoli-network charts/network \
  -n <namespace> \
  --set tls.existingSecret.name=netobserv-tls-certs

# Via randoli-agent umbrella chart
helm install randoli charts/randoli-agent \
  -n <namespace> \
  --set tags.observability=true \
  --set network.tls.existingSecret.name=netobserv-tls-certs
```

### Cert rotation / upgrade

Update the source Secret, then re-run `helm upgrade`:

```bash
kubectl create secret generic netobserv-tls-certs \
  --from-file=tls.crt=webhook.crt \
  --from-file=tls.key=webhook.key \
  --from-file=ca.crt=ca.crt \
  --from-file=flp.crt=flp.crt \
  --from-file=flp.key=flp.key \
  -n <namespace> --dry-run=client -o yaml | kubectl apply -f -

helm upgrade randoli charts/randoli-agent -n <namespace> ...
```

---

## TLS Mode B — Auto-generate via pre-install Job (fallback)

When cert pre-provisioning is not practical, set `tls.generateJob.enabled: true`. A Helm `pre-install`/`pre-upgrade` Job generates a self-signed CA, signs all required certificates, and creates all Secrets and ConfigMaps before the operator Deployment starts.

The Job also creates the `netobserv` and `netobserv-privileged` namespaces so the FLP cert and CA ConfigMaps can be placed there immediately.

**Trade-off:** The Job introduces a runtime dependency. If the Job fails (image pull error, RBAC delay, cluster pressure), `helm install` will time out and roll back.

### Install

```bash
# Standalone
helm install randoli-network charts/network \
  -n <namespace> \
  --set tls.generateJob.enabled=true

# Via randoli-agent umbrella chart
helm install randoli charts/randoli-agent \
  -n <namespace> \
  --set tags.observability=true \
  --set network.tls.generateJob.enabled=true
```

### Custom images

```yaml
# in your values override file
tls:
  generateJob:
    enabled: true
    certGeneratorImage: "your-registry/python:3.11-slim"  # needs bash + openssl
    kubectlImage: "your-registry/kubectl:latest"          # needs kubectl
```

---

## Values reference

| Key | Default | Description |
|---|---|---|
| `netobservNamespace` | `netobserv` | Must match `spec.namespace` in the FlowCollector CR |
| `tls.existingSecret.name` | `""` | Name of the pre-existing Secret containing all cert material |
| `tls.existingSecret.certKey` | `tls.crt` | Key for the webhook/metrics certificate |
| `tls.existingSecret.keyKey` | `tls.key` | Key for the webhook/metrics private key |
| `tls.existingSecret.caKey` | `ca.crt` | Key for the CA certificate (written to netobserv-ca ConfigMap) |
| `tls.existingSecret.flpCertKey` | `flp.crt` | Key for the flowlogs-pipeline certificate |
| `tls.existingSecret.flpKeyKey` | `flp.key` | Key for the flowlogs-pipeline private key |
| `tls.generateJob.enabled` | `false` | Enable the pre-install cert generation Job |
| `tls.generateJob.certGeneratorImage` | `python:3.11-slim` | Image for cert generation (needs bash + openssl) |
| `tls.generateJob.kubectlImage` | `bitnami/kubectl:latest` | Image for Secret/ConfigMap creation (needs kubectl) |
| `netobserv-operator.standaloneConsole.enable` | `false` | Enable the standalone web console |
| `netobserv-operator.operator.nodeAffinity` | `{}` | Node affinity for the operator Deployment |
| `clusterDomain` | `cluster.local` | Cluster DNS domain |

> **One of `tls.existingSecret.name` or `tls.generateJob.enabled` must be set.**
> The chart fails with a descriptive error if neither is configured.

---

## Upgrading the operator version

1. Check available versions: `helm search repo netobserv/netobserv-operator --versions`
2. Update `version` and `appVersion` in `Chart.yaml`
3. Update the `dependencies[0].version` in `Chart.yaml`
4. Run `helm dependency update charts/network`
5. Run `helm package charts/network -d charts/randoli-agent/charts/`
6. Update the `network` dependency version in `charts/randoli-agent/Chart.yaml`
7. Run `helm dependency update charts/randoli-agent`

---

## Architecture note

This chart follows the **thin wrapper pattern** used by all subchart wrappers in this repository:

- `Chart.yaml` declares the upstream chart as a `dependency` — no upstream templates are copied
- `values.yaml` provides Randoli-specific defaults nested under the `netobserv-operator:` key
- Custom templates in `templates/` cover only TLS provisioning, which the upstream chart delegates to cert-manager

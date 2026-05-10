# Install Astrolift on Vanilla Kubernetes (k8s-native)

End-to-end runbook for installing Astrolift on a Kubernetes cluster you
control — bare-metal, on-prem, a single-node lab, or `kind` for local
dev. No cloud-managed services assumed; the platform self-hosts via
operators (CloudNativePG for Postgres, Bitnami Redis Operator for Redis,
Longhorn for storage, Velero for backup, etc.).

> **When to use this path.** You have a Kubernetes cluster but no AWS /
> GCP / Azure account, or you specifically want to avoid managed
> services for sovereignty / cost / air-gap reasons. If you're on a
> cloud and just want the easy path, use that cloud's runbook instead
> — the cloud-managed services are cheaper to operate at scale.

---

## 1. Prerequisites

### Tools (operator workstation)

| Tool | Min version | Why |
|---|---|---|
| `kubectl` | 1.28 | Cluster operations |
| `helm` | 3.16 | Chart installs |
| `kind` | 0.24 | Local dev only |
| `astro` CLI | latest | Cluster registration + first app |

### Cluster

| Path | Cluster requirements |
|---|---|
| **Local dev (`kind`)** | Docker Desktop or compatible runtime |
| **Bare-metal / on-prem prod** | At least 3 nodes; CNI (Cilium/Calico) installed; storage available for Longhorn (one disk or path per node); load balancer (MetalLB / kube-VIP) for ingress |
| **Existing managed cluster** (EKS/GKE/AKS without our cloud-side IaC) | All of the above plus check that the cluster's StorageClass setup doesn't conflict with the tier-mapping below |

### DNS

Pick a base zone for the install before you start. **You bring your
own** — `astro.acme.internal`, `platform.acme.com`, `astrolift.lab`,
or anything you can resolve from clients that need to reach the
dashboard. For `kind` and air-gapped lab installs you can use a
`.local` / `.lab` suffix and stub it in `/etc/hosts`. Pass it to Helm
as `--set global.platformDomain=<your-zone>` when you reach § 6.

### Repo

```bash
git clone --recurse-submodules https://github.com/<your-fork>/astrolift.git
cd astrolift/astrolift-opscode
```

---

## 2. (Local dev only) Stand up `kind`

Skip this section if you already have a real cluster.

```bash
./kubernetes/base/install.sh kind dev
```

This script:
1. Creates a `kind` cluster named `astrolift-ci`
2. Installs the cluster baseline (cert-manager, Gateway API + Envoy
   Gateway, Fluent Bit, Loki, Prometheus, Grafana, Argo CD)
3. Skips cloud-specific bits (ALB controller, external-dns, external-
   secrets) automatically

To install only a subset, use `--skip <prereq>`:
```bash
./kubernetes/base/install.sh kind dev --skip argocd --skip loki
```

For non-kind clusters, omit the `kind` argument and pass the matching
cloud (`aws`/`gcp`/`azure`) — the script then skips kind-specific
helpers and includes cloud add-ons.

---

## 3. Install the prereqs umbrella chart

The platform expects certain operators to be available before you install
the chart. They live in `helm/astrolift-prereqs/` as an umbrella chart
with toggleable subcharts.

```bash
# Pull subchart deps once
helm dependency update helm/astrolift-prereqs

# Edit a values file to pick what you want installed
cat > prereqs.values.yaml <<EOF
# Cluster essentials
certManager:
  enabled: true
externalDns:
  enabled: false   # only useful with a real DNS provider
ingressNginx:
  enabled: true
metallb:
  enabled: true    # bare-metal LB; skip on cloud or kind

# Storage operators — pick ONE of longhorn or rook-ceph
longhorn:
  enabled: true
rookCeph:
  enabled: false

# Storage classes (defines astrolift-{standard,balanced,high-iops,extreme,rwx})
storageClasses:
  enabled: true
  longhorn:
    enabled: true
    rwxEnabled: true

# Managed-service operators (match astrolift-providers/k8s_native preflight)
cnpg:
  enabled: true   # Postgres
strimzi:
  enabled: false  # Kafka — leave off unless you're using it
redisOperator:
  enabled: true   # Redis
vault:
  enabled: true   # secrets

# Backup
velero:
  enabled: true

# Observability — kube-prometheus-stack covers Prom + Grafana + Alertmanager
kube-prometheus-stack:
  enabled: true
loki:
  enabled: true
tempo:
  enabled: false  # enable when you start using OTel traces
opentelemetry-collector:
  enabled: false  # enable alongside tempo
EOF

helm install astrolift-prereqs ./helm/astrolift-prereqs \
  -f prereqs.values.yaml \
  --namespace astrolift-prereqs --create-namespace \
  --wait --timeout 15m
```

The `--wait --timeout 15m` is important: cert-manager + Vault take a
few minutes to come up healthy, and downstream installs depend on them.

### Storage class tier mapping

After install, you should see four StorageClasses + the RWX one:

```bash
kubectl get storageclass | grep astrolift-
# astrolift-standard   driver.longhorn.io   ...
# astrolift-balanced   driver.longhorn.io   (default)
# astrolift-high-iops  driver.longhorn.io   ...
# astrolift-extreme    driver.longhorn.io   ...
# astrolift-rwx        driver.longhorn.io   ...
```

Tenant workloads bind by tier (`astrolift-balanced` is default). Switch
provisioners by setting `storageClasses.longhorn.enabled=false` and
adding your own SCs in your values.

---

## 4. Configure the platform install

Set up a `values.k8s.yaml` for the `astrolift` chart with your install's
specifics:

```yaml
# values.k8s.local.yaml
ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod   # or your CA
    nginx.ingress.kubernetes.io/ssl-redirect: "true"

# Use the CNPG cluster you'll create separately, or external Postgres
api:
  env:
    DATABASE_URL: "postgres://astrolift:CHANGEME@platform-db-rw.astrolift-system:5432/astrolift"
    REDIS_URL:    "redis://platform-cache.astrolift-system:6379"
    PLATFORM_DOMAIN: "astrolift.example.local"

# Same env on worker
worker:
  env:
    DATABASE_URL: "postgres://astrolift:CHANGEME@platform-db-rw.astrolift-system:5432/astrolift"
    REDIS_URL:    "redis://platform-cache.astrolift-system:6379"
    PLATFORM_DOMAIN: "astrolift.example.local"

# UI talks to API via the in-cluster service
ui:
  env:
    NEXT_PUBLIC_API_URL: "https://api.astrolift.example.local"
    NEXT_PUBLIC_PLATFORM_DOMAIN: "astrolift.example.local"
```

Apply secrets via Vault or sealed-secrets — don't commit raw passwords.

---

## 5. Provision the platform's own data services

The control plane needs Postgres + Redis. With the operators installed,
create the instances via CR:

```yaml
# platform-db.yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: platform-db
  namespace: astrolift-system
spec:
  instances: 3
  storage:
    size: 50Gi
    storageClass: astrolift-balanced
  bootstrap:
    initdb:
      database: astrolift
      owner: astrolift
  monitoring:
    enablePodMonitor: true
```

```yaml
# platform-cache.yaml
apiVersion: redis.redis.opstreelabs.in/v1beta2
kind: Redis
metadata:
  name: platform-cache
  namespace: astrolift-system
spec:
  kubernetesConfig:
    image: quay.io/opstree/redis:v7.0.15
  storage:
    volumeClaimTemplate:
      spec:
        storageClassName: astrolift-balanced
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 10Gi
```

```bash
kubectl create namespace astrolift-system
kubectl apply -f platform-db.yaml -f platform-cache.yaml
kubectl wait --for=condition=Ready cluster/platform-db --timeout=10m
```

---

## 6. Install the platform Helm chart

```bash
helm install astrolift ./helm/astrolift \
  --namespace astrolift-system \
  -f ./helm/astrolift/values.k8s.yaml \
  -f values.k8s.local.yaml \
  --set global.platformDomain="astrolift.example.local" \
  --wait --timeout 10m
```

If the install fails on missing CRDs, your prereqs install hasn't finished
applying CRDs yet. `kubectl get crd | grep -E 'cnpg|redis|cert-manager|gateway'`
should show the relevant CRDs.

---

## 7. Register the cluster with itself

Even on a self-hosted install, the platform registers itself as the
tenant cluster (it manages tenant workloads on the same cluster the
control plane lives on, or a separate one — operator's choice).

```bash
cat > k8s-cluster.yaml <<EOF
plugin: k8s
name: local-tenant
kubeconfig: |
$(cat ~/.kube/config | sed 's/^/  /')
storage_class_default: astrolift-balanced
ingress_class: nginx
cluster_issuer: letsencrypt-prod
EOF

astro cluster register --config k8s-cluster.yaml
```

The platform validates the cluster's capabilities (preflight checks
that CNPG / Redis Operator / Strimzi / etc. are installed per tenant
requirements) and starts managing tenant deploys.

---

## 8. Deploy a first app

Same as the cloud paths:

```bash
astro app new --template python-fastapi --org demo --name hello
astro app register --org demo --name hello
astro app deploy --org demo --name hello --env staging
```

Hit `https://hello.demo.astrolift.example.local` to see it live.

---

## Operator selection cheatsheet

If you don't know which managed-service operator to enable, here's
roughly what tenants need each one for:

| Tenant kind | Operator (toggle) |
|---|---|
| `postgres` | `cnpg` (CloudNativePG) |
| `redis` | `redisOperator` (OT-Container-Kit) |
| `kafka` | `strimzi` |
| `mysql` | (none ships by default; add yourself) |
| `s3-compatible-blob` | (none — bring MinIO if needed) |

Tenant workload preflight (`astrolift-providers/k8s_native/preflight.py`)
fails fast at provision time when the matching operator isn't on the
cluster — error tells you which Helm install command to run.

---

## Storage tier reference

The `astrolift-prereqs` chart's `storageClasses` block defines the
StorageClasses that tenant PVCs bind to. Defaults assume Longhorn:

| Tier | Default | Use for |
|---|---|---|
| `astrolift-standard` | Longhorn 1 replica | Disposable scratch, dev DBs |
| `astrolift-balanced` | Longhorn 2 replicas (default) | General-purpose tenant data |
| `astrolift-high-iops` | Longhorn 3 replicas + best-effort locality | High-throughput Postgres / Kafka |
| `astrolift-extreme` | Longhorn strict-local + 1 replica | Local NVMe; not HA |
| `astrolift-rwx` | Longhorn share-manager | Shared filesystem (RWX) |

Operators using Rook Ceph or TopoLVM swap the provisioner via values:

```yaml
storageClasses:
  longhorn:
    enabled: false  # turn off Longhorn-backed classes
  rookCeph:
    enabled: true   # bring your own SC defs (chart doesn't auto-generate yet)
```

---

## Troubleshooting

### Pods stuck pending — no PVC binding
Likely no default StorageClass set, or the requested class doesn't exist.
```bash
kubectl get sc                        # is there a default? (annotated)
kubectl describe pvc -n astrolift-system platform-db-1
```

### Vault stuck sealed
Vault HA + Raft starts sealed by default. Either:
- Manually unseal via `vault operator unseal` (3 of 5 keys), or
- Configure auto-unseal via cloud KMS (uncomment the `seal "awskms"`
  block in `helm/astrolift-prereqs/values.yaml` under `vault.server.ha`)

### `kind` cluster runs out of disk
Default kind disk is small. Mount an external disk or use:
```bash
kind create cluster --config kind-config-with-mounts.yaml
```

### Ingress hostnames don't resolve (kind)
kind doesn't have a real LoadBalancer. Two options:
- `cloud-provider-kind` — install separately
- Port-forward via `kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8443:443`
  and add hosts entries

### CNPG Cluster CR not found
Prereqs install didn't complete or wasn't run. Re-run:
```bash
helm dependency update helm/astrolift-prereqs
helm upgrade --install astrolift-prereqs ./helm/astrolift-prereqs \
  -f prereqs.values.yaml -n astrolift-prereqs --wait
```

---

## Tear down

```bash
helm uninstall astrolift -n astrolift-system
kubectl delete cluster.postgresql.cnpg.io/platform-db -n astrolift-system
kubectl delete redis.redis.redis.opstreelabs.in/platform-cache -n astrolift-system
helm uninstall astrolift-prereqs -n astrolift-prereqs
kubectl delete namespace astrolift-system astrolift-prereqs
```

For kind:
```bash
kind delete cluster --name astrolift-ci
```

---

## What's outside this runbook

- **Multi-cluster operation** — register additional tenant clusters via
  `astro cluster register` after the first install
- **Air-gapped install** — bundle the Helm chart + vendored subcharts
  via `make package` from the workspace metarepo
- **HA control plane** — scale `api`/`worker`/`ui` replica counts in
  `values.k8s.yaml`; the chart already supports HA, just bump
  `replicaCount`
- **Backup target configuration** — Velero needs an object-store target
  (S3, GCS, MinIO, etc.); see `helm/astrolift-prereqs/values.yaml`
  Velero config block

For ongoing operations, see `bootstrap.md` and the parent metarepo's
specs.

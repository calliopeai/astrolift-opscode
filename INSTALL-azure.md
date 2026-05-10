# Install Astrolift on Azure

End-to-end runbook for a customer-operator installing Astrolift onto an
Azure subscription. Walks from zero (no infra) to first tenant app
deployed on a tenant AKS cluster managed by an Astrolift control plane
on Container Apps.

> **Architectural note** — Astrolift's Azure topology splits responsibilities:
> Container Apps hosts the platform's own control-plane services (api,
> ui, worker, status); AKS hosts the tenant runtime. Both run in the
> same VNet; the platform talks to AKS via the cluster connection info
> emitted from Terraform. Disable either via toggles; default enables
> both.

---

## 1. Prerequisites

### Tools (operator workstation)

| Tool | Min version | Why |
|---|---|---|
| Terraform | 1.9 | Provisioning |
| `az` CLI | 2.60 | Azure ops + auth |
| `kubectl` | 1.28 | AKS verification |
| `helm` | 3.16 | Platform chart install |
| `astro` CLI | latest | Cluster registration + first app |
| `jq` | any | Output parsing |

### Azure subscription

- A subscription per environment (recommended) or one shared
- A user/role with `Owner` or `User Access Administrator` to bootstrap
  the infra service principal (one-time)
- A registered Azure DNS zone you own. **You bring your own zone** —
  anything you control (e.g. `dev.acme.com`, `platform.acme.io`).
  You'll pass it to Terraform as `base_domain` (see § 5). Astrolift
  creates per-env subdomains under it. If your zone lives at another
  registrar, NS-delegate it to Azure DNS first
- Quota for: at least 4 vCPUs in the chosen region, 1 Postgres
  Flexible Server, 1 Cache for Redis, 1 AKS cluster
- The subscription's resource providers will be auto-registered by
  Terraform (17 of them: `Microsoft.ContainerService`, `Microsoft.
  DBforPostgreSQL`, `Microsoft.Cache`, etc.) — this requires the
  bootstrap principal to have `Microsoft.Resources/providers/register/action`

### Repo

```bash
git clone --recurse-submodules https://github.com/<your-fork>/astrolift.git
cd astrolift/astrolift-opscode
```

---

## 2. Configure `azure/config.env`

```bash
PROJECT="astrolift"
AZURE_LOCATION="westus2"
AZURE_SUBSCRIPTION_ID="00000000-0000-0000-0000-000000000000"
AZURE_TENANT_ID="00000000-0000-0000-0000-000000000000"
OWNER="astrolift"
```

---

## 3. One-time: bootstrap the infra service principal

Terraform runs as a scoped service principal, not as your `Owner` user.
Create one per subscription:

```bash
SUBSCRIPTION_ID="00000000-0000-0000-0000-000000000000"

az ad sp create-for-rbac \
  --name "astrolift-infra" \
  --role "Contributor" \
  --scopes "/subscriptions/$SUBSCRIPTION_ID" \
  --years 1

# Add the User Access Administrator role so Terraform can manage role
# assignments (needed for Workload Identity + ACR pulls)
SP_OBJECT_ID=$(az ad sp list --display-name "astrolift-infra" --query "[0].id" -o tsv)
az role assignment create \
  --assignee-object-id "$SP_OBJECT_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "User Access Administrator" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"

# Capture the credentials in env vars Terraform reads
export ARM_CLIENT_ID="<appId from create-for-rbac>"
export ARM_CLIENT_SECRET="<password from create-for-rbac>"
export ARM_TENANT_ID="<tenant from create-for-rbac>"
export ARM_SUBSCRIPTION_ID="$SUBSCRIPTION_ID"
```

For multi-subscription setups, repeat per subscription.

---

## 4. Bootstrap the Terraform state backend

Each environment gets its own Storage Account container:

```bash
./run.sh bootstrap azure dev
./run.sh bootstrap azure stg
./run.sh bootstrap azure prd
```

This creates:
- Resource group `astrolift-tfstate-rg`
- Storage account `astrolifttfstate`
- Containers `tfstate-dev` / `tfstate-stg` / `tfstate-prd`

---

## 5. Configure environment variables (toggles + sizing)

```hcl
# azure/environments/dev/terraform.tfvars  (copy from terraform.tfvars.example)
location    = "westus2"
base_domain = "dev.acme.com"   # YOU bring this — must be an Azure DNS zone you own

# Runtime toggles
enable_container_apps        = true   # control plane
enable_aks                   = true   # tenant runtime

# Observability
enable_fluent_bit            = true
enable_managed_prom_grafana  = false  # default false in dev; true in prd
enable_otel_azuremonitor     = true

# Backup
enable_velero                = false  # default false in dev
enable_postgres_geo_backup   = false  # GRS replication; default false in dev
enable_blob_lifecycle        = false  # Cool/Archive transitions
enable_azure_backup_vault    = false  # Recovery Services Vault
```

> Each env ships a `terraform.tfvars.example` you can copy. The real
> `terraform.tfvars` is gitignored.

---

## 6. Plan + review

```bash
./run.sh plan azure dev
```

Read it. Look for:
- 17 resource provider registrations
- VNet with `aks` and `container_apps` subnets
- AKS with `oidc_issuer_enabled = true` and `workload_identity_enabled
  = true`
- ACR with system-assigned identity

---

## 7. Apply

```bash
./run.sh apply azure dev
```

First-apply takes ~25-35 min. Milestones:

1. Resource providers register (1-3 min)
2. Resource group + VNet + NAT (2-3 min)
3. Postgres Flexible Server (10-15 min — slowest)
4. AKS cluster (10-15 min)
5. Cache for Redis (5-8 min)
6. ACR + Key Vault + Storage Account (2-3 min)
7. Observability + backup (gated by toggles, 2-5 min each)

---

## 8. Verify

```bash
./azure/scripts/cold-boot.sh dev
```

---

## 9. Install the platform Helm chart

```bash
./azure/scripts/build-env.sh dev   # writes azure/outputs/dev.env

helm install astrolift ./helm/astrolift \
  -f ./helm/astrolift/values.azure.yaml \
  --set global.platformDomain="$BASE_DOMAIN" \
  --set serviceAccount.annotations."azure\.workload\.identity/client-id"="$UAMI_CLIENT_ID" \
  --set podLabels."azure\.workload\.identity/use"="true" \
  --set api.image.repository="$ACR_LOGIN_SERVER/astrolift/api" \
  --set ui.image.repository="$ACR_LOGIN_SERVER/astrolift/ui" \
  --set worker.image.repository="$ACR_LOGIN_SERVER/astrolift/worker" \
  --set status.image.repository="$ACR_LOGIN_SERVER/astrolift/status" \
  --set api.env.DATABASE_URL="$DATABASE_URL" \
  --set api.env.REDIS_URL="$REDIS_URL"
```

---

## 10. Register the cluster

```bash
cat > azure-dev-cluster.yaml <<EOF
plugin: azure
name: dev-astrolift-tenant
subscription_id: $(az account show --query id -o tsv)
tenant_id: $(az account show --query tenantId -o tsv)
location: westus2
resource_group: dev-astrolift-rg
cluster_name: dev-astrolift
oidc_issuer_url: $(az aks show --resource-group dev-astrolift-rg --name dev-astrolift --query "oidcIssuerProfile.issuerUrl" -o tsv)
acr_name: $(terraform -chdir=azure/environments/dev output -raw acr_name 2>/dev/null)
EOF

astro cluster register --config azure-dev-cluster.yaml
```

---

## 11. Deploy a first app

```bash
astro app new --template python-fastapi --org demo --name hello
astro app register --org demo --name hello
astro app deploy --org demo --name hello --env staging
```

---

## Multi-environment

| | dev | stg | prd |
|---|---|---|---|
| VNet CIDR | `10.0.0.0/16` | `10.50.0.0/16` | `10.100.0.0/16` |
| NAT topology | single NAT Gateway | per-zone | per-zone |
| Postgres | `B_Standard_B1ms`, single-AZ | `GP_Standard_D2s_v3`, zone-redundant | `GP_Standard_D4s_v3`, zone-redundant + read replica |
| Redis | Basic C0 | Standard C1 | Premium P1 (clustered) |
| Postgres backup retention | 7 days | 14 days | 35 days |
| `enable_managed_prom_grafana` | false | false | true |
| `enable_velero` | false | true | true |
| `enable_postgres_geo_backup` | false | false | true |

---

## Toggle reference

### Runtime
| Toggle | Effect |
|---|---|
| `enable_container_apps` | Container Apps environment + UAMI for the platform control plane |
| `enable_aks` | AKS cluster + Workload Identity + OIDC issuer |

### Observability
| Toggle | Effect |
|---|---|
| `enable_fluent_bit` | Fluent Bit DaemonSet → Log Analytics |
| `enable_managed_prom_grafana` | Azure Monitor Workspace (Managed Prometheus) + Managed Grafana |
| `enable_otel_azuremonitor` | OTel collector → Azure Monitor (metrics + logs); optional App Insights for traces |
| `enable_workload_identity` | Provision platform UAMI + role assignments (KV / Storage / ACR) |

### Backup
| Toggle | Effect |
|---|---|
| `enable_velero` | Velero with azure-pv-backup add-on |
| `enable_postgres_geo_backup` | GRS replication on Postgres backups (in addition to default LRS) |
| `enable_blob_lifecycle` | Cool / Archive lifecycle on Storage account blob versions |
| `enable_azure_backup_vault` | Recovery Services Vault + AKS Backup (preview) |

---

## Troubleshooting

### `terraform apply` fails on resource provider registration
Resource provider registration requires `Microsoft.Resources/providers/register/action`
on the bootstrap SP. If your SP only has `Contributor`, add it:
```bash
az role assignment create --assignee "$ARM_CLIENT_ID" \
  --role "Reader and Data Access" --scope "/subscriptions/$SUBSCRIPTION_ID"
```

### Postgres Flexible stuck "Creating" past 20 min
Private DNS zone propagation can take a while. Check
`az network private-dns zone show -g $RG -n $ZONE`.

### AKS reachable but `kubectl` returns 403
Workload Identity OIDC issuer URL not yet propagated. Wait 5-10 min,
then re-fetch credentials:
```bash
az aks get-credentials --resource-group dev-astrolift-rg --name dev-astrolift
```

### Helm install fails on missing UAMI annotation
Run `./azure/scripts/build-env.sh dev`; it pulls the platform UAMI's
client ID from Terraform outputs into the env file.

---

## Tear down

```bash
./run.sh destroy azure dev
az group delete --name dev-astrolift-rg --yes  # if Terraform missed anything
```

---

## What's outside this runbook

- App Gateway / AGIC ingress (toggle TODO; current default uses webapprouting addon or nginx via prereqs)
- Customer-managed CMEK on Postgres / Storage
- Air-gapped install with vendored Helm charts

For ongoing operations, see `astrolift-opscode/bootstrap.md`.

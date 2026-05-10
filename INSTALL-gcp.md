# Install Astrolift on GCP

End-to-end runbook for a customer-operator installing Astrolift onto a
Google Cloud project. Walks from zero (no infra) to first tenant app
deployed on a tenant GKE cluster managed by an Astrolift control plane
on Cloud Run.

> **Architectural note** — Astrolift's GCP topology splits responsibilities:
> Cloud Run hosts the platform's own control-plane services (api, ui,
> worker, status); GKE hosts the tenant runtime. Both are in the same
> VPC; the platform talks to GKE via the cluster connection info
> emitted from Terraform. Disable either via toggles, but the default
> install enables both.

---

## 1. Prerequisites

### Tools (operator workstation)

| Tool | Min version | Why |
|---|---|---|
| Terraform | 1.9 | Provisioning |
| `gcloud` | 488.0 | Project ops + auth |
| `kubectl` | 1.28 | GKE verification + helm install |
| `helm` | 3.16 | Platform chart install |
| `astro` CLI | latest | Cluster registration + first app |
| `jq` | any | Output parsing |

### GCP project

- A dedicated project per environment (recommended) **or** a shared
  project where dev/stg/prd run in separate VPCs
- A user/SA with `roles/owner` on the project to bootstrap the infra
  service account
- A registered Cloud DNS zone you own. **You bring your own zone** —
  anything you control (e.g. `dev.acme.com`, `platform.acme.io`).
  You'll pass it to Terraform as `base_domain` (see § 5). Astrolift
  creates per-env subdomains under it. If your zone lives at another
  registrar, NS-delegate it to Cloud DNS first
- Quota for: at least 4 vCPUs in the chosen region, 1 Cloud SQL
  instance, 1 Memorystore Redis, 1 GKE Autopilot cluster

### Repo

```bash
git clone --recurse-submodules https://github.com/<your-fork>/astrolift.git
cd astrolift/astrolift-opscode
```

---

## 2. Configure `gcp/config.env`

Edit before bootstrapping:

```bash
PROJECT="astrolift"           # used in resource naming + registry paths
GCP_REGION="us-west1"          # default region for envs
GCP_PROJECT_ID="my-project"    # the actual GCP project ID
OWNER="astrolift"              # label value
```

`PROJECT` and `OWNER` are conventions; `GCP_REGION` and `GCP_PROJECT_ID`
need to match your account's reality.

---

## 3. One-time: bootstrap the infra service account

Astrolift's Terraform doesn't run as your `roles/owner` identity — it
runs as a scoped `astrolift-infra` service account. Create once per
project:

```bash
PROJECT_ID="my-project"

gcloud iam service-accounts create astrolift-infra \
  --display-name="Astrolift Infrastructure" \
  --project="$PROJECT_ID"

# Grant the roles needed for Terraform to provision the platform
for role in \
  roles/compute.admin \
  roles/container.admin \
  roles/iam.serviceAccountAdmin \
  roles/iam.workloadIdentityPoolAdmin \
  roles/cloudsql.admin \
  roles/redis.admin \
  roles/dns.admin \
  roles/secretmanager.admin \
  roles/storage.admin \
  roles/cloudkms.admin \
  roles/artifactregistry.admin \
  roles/serviceusage.serviceUsageAdmin \
  roles/resourcemanager.projectIamAdmin
do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:astrolift-infra@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="$role"
done

# Generate a key for local Terraform use
gcloud iam service-accounts keys create ~/.config/gcloud/astrolift-infra-key.json \
  --iam-account="astrolift-infra@${PROJECT_ID}.iam.gserviceaccount.com"

export GOOGLE_APPLICATION_CREDENTIALS=~/.config/gcloud/astrolift-infra-key.json
```

For multi-project setups (dev/stg/prd in separate projects), repeat
per project with the matching `PROJECT_ID`.

---

## 4. Bootstrap the Terraform state backend

Each environment gets its own GCS bucket. The `bootstrap` subcommand
creates them:

```bash
./run.sh bootstrap gcp dev
./run.sh bootstrap gcp stg
./run.sh bootstrap gcp prd
```

Buckets are named `tf-state-${PROJECT_ID}` and use object versioning
+ uniform bucket-level access.

---

## 5. Configure environment variables (toggles + sizing)

Each `gcp/environments/<env>/variables.tf` exposes runtime + obs +
backup toggles. Override in `terraform.tfvars`:

```hcl
# gcp/environments/dev/terraform.tfvars  (copy from terraform.tfvars.example)
region      = "us-west1"
project_id  = "my-project"
base_domain = "dev.acme.com"   # YOU bring this — must be a Cloud DNS zone you own

# Runtime toggles
enable_cloud_run            = true   # control plane on Cloud Run
enable_gke                  = true   # tenant runtime
enable_managed_prom         = false  # GKE Managed Prometheus + Cloud Monitoring (default false in dev)
enable_otel_cloudtrace      = true   # OTel collector → Cloud Trace
enable_velero               = false  # cluster snapshots (default false in dev; true in stg/prd)
enable_gcs_lifecycle        = false  # Coldline/Archive transitions
enable_cloudsql_pitr        = true   # Cloud SQL point-in-time recovery
```

> Each env ships a `terraform.tfvars.example` you can copy. The real
> `terraform.tfvars` is gitignored.

See **§ Toggle reference** below.

---

## 6. Plan + review

```bash
./run.sh plan gcp dev
```

Read it. Look for:
- Resource counts that match expectations (~80-150 for dev)
- API enablement: 17 Google APIs should appear (compute, container,
  iam, secretmanager, cloudkms, artifactregistry, dns, sqladmin, redis,
  pubsub, storage, monitoring, logging, cloudtrace, servicenetworking,
  aiplatform)
- VPC secondary ranges for pods + services on the private subnet
- Workload Identity pool format: `${PROJECT_ID}.svc.id.goog`

---

## 7. Apply

```bash
./run.sh apply gcp dev
```

First-apply takes ~25-35 min depending on toggles. Milestones:

1. API enablement (1-2 min)
2. VPC + Cloud NAT + secondary ranges (3-5 min)
3. Cloud SQL instance + Memorystore (10-15 min — slowest)
4. GKE Autopilot cluster (8-12 min)
5. KMS keyring + Artifact Registry + Cloud DNS (1-3 min)
6. Cloud Run service + IAM (3-5 min)
7. Observability + backup (gated by toggles, 2-5 min each)

---

## 8. Verify

```bash
./gcp/scripts/cold-boot.sh dev
```

Validates:
- GKE API reachable; nodes ready
- Cloud SQL accepting connections via Private Service Connect
- Memorystore endpoint resolves
- Cloud DNS zone delegated correctly
- Artifact Registry accessible

---

## 9. Install the platform Helm chart

```bash
./gcp/scripts/build-env.sh dev    # writes gcp/outputs/dev.env

helm install astrolift ./helm/astrolift \
  -f ./helm/astrolift/values.gcp.yaml \
  --set global.platformDomain="$BASE_DOMAIN" \
  --set serviceAccount.annotations."iam\.gke\.io/gcp-service-account"="$WI_GSA_EMAIL" \
  --set api.image.repository="$ARTIFACT_REGISTRY/astrolift/api" \
  --set ui.image.repository="$ARTIFACT_REGISTRY/astrolift/ui" \
  --set worker.image.repository="$ARTIFACT_REGISTRY/astrolift/worker" \
  --set status.image.repository="$ARTIFACT_REGISTRY/astrolift/status" \
  --set api.env.DATABASE_URL="$DATABASE_URL" \
  --set api.env.REDIS_URL="$REDIS_URL"
```

For repeat installs, write the env vars into a `values.dev.yaml` and
load with `-f`.

---

## 10. Register the cluster

```bash
cat > gcp-dev-cluster.yaml <<EOF
plugin: gcp
name: dev-astrolift-tenant
project_id: $(gcloud config get-value project)
region: us-west1
cluster_name: dev-astrolift
wi_pool: $(terraform -chdir=gcp/environments/dev output -raw eks_oidc_provider_arn 2>/dev/null || echo "${PROJECT_ID}.svc.id.goog")
artifact_registry: us-west1-docker.pkg.dev/${PROJECT_ID}/astrolift
EOF

astro cluster register --config gcp-dev-cluster.yaml
```

---

## 11. Deploy a first app

```bash
astro app new --template python-fastapi --org demo --name hello
astro app register --org demo --name hello
astro app deploy --org demo --name hello --env staging
```

Hit `https://hello.demo.<your-base-domain>` to see it live (e.g.
`https://hello.demo.dev.acme.com` for the values above).

---

## Multi-environment

| | dev | stg | prd |
|---|---|---|---|
| VPC CIDR | `10.0.0.0/16` | `10.50.0.0/16` | `10.100.0.0/16` |
| Cloud NAT | single | per-zone | per-zone |
| Cloud SQL | `db-f1-micro`, single zone | `db-custom-2-7680`, regional HA | regional HA + read replicas |
| Memorystore | 1 GB Basic tier | 4 GB Standard tier (multi-zone) | 8 GB Standard tier (multi-zone) |
| Cloud SQL backup retention | 7 days | 14 days | 30 days |
| `enable_managed_prom` | false | false | true |
| `enable_velero` | false | true | true |
| `enable_gcs_lifecycle` | false | true | true |

Run apply per-env in order: dev → stg → prd.

---

## Toggle reference

All toggles live in `gcp/environments/<env>/variables.tf`.

### Runtime
| Toggle | Effect |
|---|---|
| `enable_cloud_run` | Cloud Run runtime + IAM bindings for the platform control plane |
| `enable_gke` | GKE Autopilot cluster + Workload Identity pool |

### Observability
| Toggle | Effect |
|---|---|
| `enable_fluent_bit` | Fluent Bit DaemonSet → Cloud Logging |
| `enable_managed_prom` | GKE Managed Prometheus + Cloud Monitoring scraping |
| `enable_otel_cloudtrace` | OTel collector → Cloud Trace + Cloud Monitoring + Cloud Logging |
| `enable_workload_identity` | Bind GKE Workload Identity for tenant pods |

### Backup
| Toggle | Effect |
|---|---|
| `enable_velero` | Velero with gcp-pv-backup plugin |
| `enable_cloudsql_pitr` | Cloud SQL point-in-time recovery |
| `enable_gcs_lifecycle` | Coldline / Archive lifecycle on artifact bucket |
| `enable_cloud_logging_router` | Cloud Logging sink for long-term retention |

---

## Troubleshooting

### `terraform apply` fails on API enablement timeout
Some APIs (`servicenetworking.googleapis.com`, `aiplatform.googleapis.com`)
take a few minutes to fully activate. Re-run apply; Terraform picks up
where it left off.

### Cloud SQL stuck on "creating" past 20 min
Cloud SQL with private IP requires the Service Networking peering to
be fully established first. Check `gcloud services vpc-peerings list
--network=$VPC_NAME`.

### GKE cluster reachable but kubectl returns 403
Workload Identity pool not yet propagated. Wait 5-10 min and retry, or
manually re-run:
```bash
gcloud container clusters get-credentials dev-astrolift --region us-west1
```

### Helm install fails on missing GSA annotation
Run `./gcp/scripts/build-env.sh dev` after apply; it pulls the
Workload Identity GSA email from Terraform outputs into the env file.

---

## Tear down

```bash
./run.sh destroy gcp dev
gcloud storage rm --recursive gs://tf-state-${PROJECT_ID}  # be careful, irreversible
```

---

## What's outside this runbook

- Multi-region setup (one install per region; cross-region failover is per-flow)
- Customer-managed CMEK on Cloud SQL (use `kms_key_name` overrides — TODO)
- BigQuery / Vertex AI driver bindings (drivers ship in `astrolift-providers/gcp`; opscode bootstrap doesn't yet provision them by default)
- Air-gapped install with vendored Helm charts — see `make package` in the workspace metarepo

For ongoing operations, see `astrolift-opscode/bootstrap.md`.

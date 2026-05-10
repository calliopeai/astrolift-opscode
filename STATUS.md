# Status

Honest map of what's complete, what's partial, what's stub, and what's
known-limited. Updated continuously; check `git log -p STATUS.md` for
history.

This file exists so deployers + contributors don't have to reverse-
engineer state from the tree. Look here **before** you fork / file an
issue / start contributing.

Legend:
- ✅ **Complete** — implemented and exercised
- ⚠️ **Unvalidated** — code is there; not yet run end-to-end against a
  live target
- 🚧 **Partial** — dev path works; stg/prd or ancillary pieces still
  missing
- 📋 **Stub** — scaffolding only; resources or logic not filled in
- 🚫 **Known limit** — intentional gap; contributions welcome

---

## AWS

| Path | Status | Notes |
|---|---|---|
| `aws/tf-backend/` | ✅ | S3 + DynamoDB lock backend bootstrap |
| `aws/cloudformation/infra-user.yml` | ✅ | One-time IAM user for Terraform; least-privilege |
| `aws/environments/dev/` | ⚠️ | Full env-root: VPC, RDS, ElastiCache, ECS, EKS, S3, ACM, Route53, Secrets, KMS endpoints, ECR, observability + backup wiring, outputs.tf, env-root locals. **Not yet apply-tested against a live AWS account** — first-apply is the next milestone |
| `aws/environments/stg/` | ⚠️ | Same as dev with stg-tier sizing (multi-AZ NAT, db.t4g.small, 14d retention). Same first-apply caveat |
| `aws/environments/prd/` | ⚠️ | Same with prd-tier sizing (Aurora Serverless v2, 30+ day retention, AMP+AMG on). Same first-apply caveat |
| `aws/modules/tf-backend-bootstrap/` | ✅ | |
| `aws/modules/app-deployment-ecs/` | ✅ | All-in-one ECS deployment template, used by env-roots |
| `aws/modules/bastion/` | ✅ | SSH jump host (optional via env toggle) |
| `aws/modules/dns-exposure/` | ✅ | Route53 + Cloudflare delegation |
| `aws/modules/observability-fluent-bit/` | ⚠️ | IRSA role + log group; in-cluster Fluent Bit Helm release ships separately via `kubernetes/base/install.sh` or the operator's own deploy |
| `aws/modules/observability-amp/` | ⚠️ | AMP workspace + IRSA write role |
| `aws/modules/observability-amg/` | ⚠️ | AMG workspace with PROMETHEUS+CLOUDWATCH+XRAY data sources |
| `aws/modules/observability-otel-xray/` | ⚠️ | IRSA role for OTel collector → X-Ray |
| `aws/modules/backup-velero/` | ⚠️ | S3 bucket + IRSA + IAM (snapshots + bucket access) |
| `aws/modules/backup-aws-backup/` | ⚠️ | Vault + plan + selections (RDS / EFS / DynamoDB) |
| `aws/scripts/cold-boot.sh` | ✅ | Post-apply health check |
| `aws/scripts/build-env.sh` | ✅ | Generates `aws/outputs/<env>.env` from tf state + Secrets Manager |
| `aws/environments/dev/eks/main.tf` | 🚫 | **Container Insights** cluster addon not flipped on. EKS sends control-plane logs to CloudWatch; pod-level metrics still rely on Fluent Bit. Trivial follow-up — add `amazon-cloudwatch-observability` addon if you want Container Insights |

**Missing**: `INSTALL-aws.md` references `aws/scripts/build-env.sh` and that exists, but the helm install in §9 still uses `--set` flags rather than rendering a values file. A `helm-values.sh` script generating a populated `values.dev.yaml` would close the loop.

---

## GCP

| Path | Status | Notes |
|---|---|---|
| `gcp/tf-backend/` | ✅ | GCS bucket backend bootstrap |
| `gcp/environments/dev/` | ⚠️ | Full env-root: VPC + secondary ranges, Cloud SQL (Postgres + private VPC), Memorystore Redis, GCS, Cloud DNS, Secret Manager, GKE Autopilot + Workload Identity, ACR, KMS, Artifact Registry, observability + backup. Wired but not yet apply-tested |
| `gcp/environments/stg/` | 📋 | **Skeleton.** Just `terraform { }` block. Copy `dev/` files and adjust sizing. Same shape as AWS stg |
| `gcp/environments/prd/` | 📋 | **Skeleton.** Same |
| `gcp/modules/observability-fluent-bit-cloudlogging/` | ⚠️ | GSA + Workload Identity binding for Cloud Logging |
| `gcp/modules/observability-managed-prom/` | ⚠️ | GSA + WI for in-cluster Prom collectors |
| `gcp/modules/observability-otel-cloudtrace/` | ⚠️ | GSA + WI for OTel → Cloud Trace |
| `gcp/modules/backup-velero-gcp/` | ⚠️ | GCS backup bucket + GSA + WI |

**Missing**:
- `INSTALL-gcp.md` runbook (template `INSTALL-aws.md`)
- `gcp/scripts/cold-boot.sh` and `build-env.sh` equivalents (template AWS ones)
- `gcp/environments/{stg,prd}/` parity with `dev/`
- `helm/astrolift/values.gcp.yaml` exists but minimally populated (operator fills DATABASE_URL etc. from outputs)

---

## Azure

| Path | Status | Notes |
|---|---|---|
| `azure/tf-backend/` | ✅ | Storage Account backend |
| `azure/environments/dev/` | ⚠️ | Full env-root: VNet + subnets + NAT, Postgres Flex (private DNS), Redis Cache, Storage, Azure DNS, Key Vault, Log Analytics, AKS scaffold, Container Apps with UAMI, ACR, platform UAMI, observability + backup. Wired but not apply-tested |
| `azure/environments/stg/` | 📋 | **Skeleton** |
| `azure/environments/prd/` | 📋 | **Skeleton** |
| `azure/modules/observability-fluent-bit-loganalytics/` | ⚠️ | UAMI + federated credential for Log Analytics ingestion |
| `azure/modules/observability-managed-prom-grafana/` | ⚠️ | Monitor Workspace + Managed Grafana |
| `azure/modules/observability-otel-azuremonitor/` | ⚠️ | UAMI for OTel → Azure Monitor |
| `azure/modules/backup-velero-azure/` | ⚠️ | Storage container + UAMI + Disk Snapshot Contributor |
| `azure/modules/backup-recovery-vault/` | ⚠️ | Recovery Services Vault + daily VM backup policy |

**Missing**:
- `INSTALL-azure.md` runbook
- `azure/scripts/` helpers
- `azure/environments/{stg,prd}/` parity
- **App Gateway** for AKS Ingress — currently no `enable_app_gateway` toggle wired; use ingress-nginx via `astrolift-prereqs` or roll your own

---

## Vanilla Kubernetes (k8s-native)

| Path | Status | Notes |
|---|---|---|
| `kubernetes/base/install.sh` | ✅ | Cloud-aware baseline installer (kind / aws / gcp / azure profiles) with per-prereq `--skip` flags |
| `helm/astrolift-prereqs/` | ✅ | Umbrella chart with 15 subcharts (cert-manager, external-dns, ingress-nginx, MetalLB, Longhorn, Rook Ceph, CNPG, Strimzi, Bitnami Redis Operator, Vault, Velero, OTel collector, kube-prometheus-stack, Loki, Tempo). Each toggleable. Storage-tier `astrolift-{standard,balanced,high-iops,extreme,rwx}` StorageClasses ship as glue templates |
| `INSTALL-k8s-native.md` | ✅ | Full runbook from kind dev to bare-metal install |
| Kind dev profile sub-5-min target | ⚠️ | Spec #11 wants <5min on a clean machine. `install.sh kind dev` works but takes ~7-10min depending on prereq toggles. Optimize by pre-pulling images or skipping non-essential prereqs |

---

## Cross-cutting (CI / GitOps / Tenant Telemetry)

| Path | Status | Notes |
|---|---|---|
| `ci-templates/github-actions/deploy.yml` | ✅ | Reusable workflow; OIDC reg auth + BuildKit cache + monorepo selective build |
| `ci-templates/github-actions/style-gates.yml` | ✅ | Reusable style gate workflow (auto-detects languages) |
| `ci-templates/gitlab/deploy.yml` | ✅ | Same shape via GitLab include |
| `ci-templates/buildkite/deploy.yml` | ✅ | Buildkite plugin pipeline |
| `ci-templates/shared/path-filter.sh` | ✅ | Reads `astrolift.toml`, emits filter spec per CI system |
| `ci-templates/shared/pre-commit-config.yaml` | ✅ | Drop-in `.pre-commit-config.yaml` template |
| CircleCI / Jenkins | 🚫 | Deferred (`v.later`). Closed as out-of-scope; reopen with a concrete user request |
| `gitops/argocd/` | ✅ | AppProject + ApplicationSet + Application + repo-creds-via-ExternalSecret |
| `gitops/flux/` | ✅ | GitRepository + Kustomization + HelmRelease + ImageAutomation |
| `helm/tenant-telemetry/fluent-bit/values-{aws,gcp,azure,kind}.yaml` | ✅ | Per-cloud fluent-bit values |
| `helm/tenant-telemetry/otel-collector/values-{aws,gcp,azure,kind}.yaml` | ✅ | Per-cloud OTel values |

---

## Self-CI for opscode

| Path | Status | Notes |
|---|---|---|
| `.github/workflows/ci-pr.yml` | ✅ | Cheap tier: fmt + offline validate + tflint + helm lint/template + scripts/yaml + path-filter smoke. Green on main |
| `.github/workflows/ci-main.yml` | ✅ | Medium tier: reuses ci-pr.yml + checkov + helm template artifact upload. Green on main |
| `.github/workflows/ci-release.yml` | 🚧 | Heavy tier triggered by tags + workflow_dispatch. Has structural skeleton + a minimal kind smoke test |
| `ci-release.yml` kind smoke extensions | 📋 | Stub — installs cert-manager + storage classes only. Should install the platform via `kubernetes/base/install.sh kind dev`, deploy a sample app, assert healthy. Tracked in [issue #18](https://github.com/&lt;your-fork&gt;/astrolift-opscode/issues/18) |
| `ci-release.yml` localstack apply | 📋 | Stub — `workflow_dispatch` opt-in only. Defer until a real need surfaces |
| `terraform plan` in `ci-main.yml` | 🚫 | Not wired — needs OIDC federation for cloud creds. Tracked in [issue #18](https://github.com/&lt;your-fork&gt;/astrolift-opscode/issues/18) |
| `.tflint.hcl` | ✅ | Pinned aws/google/azurerm plugins; `terraform_unused_declarations` rule disabled (we ship public-API vars even when internally unused) |
| checkov | 🚧 | Currently `--soft-fail` with **409 untriaged findings** (310 AWS, 30 GCP, 69 Azure). Tracked in [issue #19](https://github.com/&lt;your-fork&gt;/astrolift-opscode/issues/19). Real fixes + `.checkov.yml` suppressions needed before flipping to hard-fail |

---

## Known limits + intentional gaps

| Topic | Status | Why |
|---|---|---|
| Customer-managed KMS keys | 🚫 | `kms_key_id` overrides not yet wired across all resources. Default uses AWS-managed / GCP-managed / Azure-managed keys. Add as a toggle per resource group when needed |
| Cross-region failover | 🚫 | Out of scope at the topology layer. Per spec, federation is per-flow, never synchronous. One install per region; cross-install coordination is application-level |
| Air-gapped install | 🚧 | Helm chart deps fetch from public registries. For air-gapped, vendor the `.tgz` files via `make package` from the parent metarepo. Operators commit those to a private mirror |
| Multi-account AWS topologies | ⚠️ | Supported via per-env profiles (see `INSTALL-aws.md` §3) but not yet validated against a real AWS Organizations setup |
| EKS access for engineer accounts beyond the bootstrap user | 🚫 | Currently only the `astrolift-infra` user gets cluster admin. Add `aws_eks_access_entry` resources for your engineers. Add a `engineer_admin_arns` variable in `eks/variables.tf` if you want it driven by config |
| GCP / Azure outputs.tf | 📋 | AWS has `aws/environments/<env>/outputs.tf`; GCP and Azure don't yet. Template from AWS |

---

## How to update this file

When you ship something that moves a row from 🚧 to ✅, edit the
matching row + commit the change in the same PR. When a deploy surfaces
a new known limitation, add a row to **Known limits**. The honesty here
is the point — overstated readiness is worse than blank cells.

# Astrolift Opscode -- Infrastructure Bootstrap

Technical reference for agents + contributors working in this repo. The
operator-facing install runbooks live in `INSTALL-<cloud>.md`; this
file is for **how to work on the code**, not how to deploy it.

> **Read [STATUS.md](STATUS.md) before changing anything** — canonical
> truth on what's complete vs partial vs stub. Don't mark something
> done if STATUS.md still calls it ⚠️.

**GitHub:** https://github.com/<your-fork>/astrolift-opscode (replace with the actual fork)
**Companion repos** (each is a sibling submodule of the parent metarepo): `astrolift-app`, `astrolift-cli`, `astrolift-providers`, `astrolift-mobile`, `astrolift-status`, `astrolift-templates`, `astrolift-docs`, `astrolift-config`, `astrolift-site`

---

## What is this

Terraform + Helm IaC for installing the Astrolift platform on AWS, GCP,
Azure, or vanilla Kubernetes. Per-cloud `<cloud>/` trees follow the
same shape; cross-cutting `helm/`, `ci-templates/`, and `gitops/` trees
ship reusable assets that work on any of them.

Per [STATUS.md](STATUS.md): AWS is structurally complete with a full
operator runbook ([INSTALL-aws.md](INSTALL-aws.md)) but not yet
validated end-to-end against a live account. GCP / Azure ship a
working `dev` environment; `stg` and `prd` are skeletons. The
k8s-native path (Longhorn + CNPG + friends, no managed cloud) targets
local `kind` dev clusters and bare-metal installs.

---

## Agent + contributor rules

Non-negotiables (apply to humans + AI agents alike):

- **No rebases.** New commits only. Merge conflicts → resolve via
  merge commits or fresh commits, never `git rebase`.
- **No AI / co-author attribution** in commit messages or PR bodies.
  Generated content is fine; attribution lines are not.
- **Push submodules before the parent metarepo.** This repo is a
  submodule of `astrolift`; if you bump opscode, push it first, then
  bump the parent metarepo's gitlink and push that.
- **No `terraform apply` from an agent session against a live cloud
  account.** Plan-only is fine for review. Apply runs from a human's
  shell.
- **Run `terraform fmt -recursive` + `terraform validate` per env
  before commit.** CI catches it on PR but local-fast-feedback beats
  CI cycles. `helm lint` for chart edits.
- **Push only the user's branch.** Never `git push --force` to `main`
  without explicit human approval. If history rewrite is asked for,
  confirm scope (commits, branches, force-push impact) first.
- **No cross-project references** in code, docs, or commit messages.
  Reference repos shared as learning sources stay as learnings only —
  don't link or cite them from this repo.

---

## Conventions

### Naming

`{env}-{project}-{component}` everywhere. `project` is `PROJECT` from
`<cloud>/config.env`; default `astrolift`. Examples:

- `dev-astrolift-vpc`, `prd-astrolift-eks`, `stg-astrolift-redis`
- ECR / Artifact Registry / ACR repos: `astrolift/{api,ui,worker,status}`
- IAM role path: `/astrolift/` (provider plugin assumes this)
- Secrets path: `/astrolift/<env>/<...>` (Secrets Manager / Secret
  Manager / Key Vault prefix)

### Tags (mandatory on every resource)

```hcl
tags = {
  Name        = local.name
  Service     = local.service_name
  Owner       = local.owner
  Environment = local.env
  Region      = local.region
  ManagedBy   = "terraform"
}
```

`merge(local.tags, { ... })` for resource-specific additions.

### Toggle pattern (every optional component is gated)

Every component an operator might want to disable is a `bool` variable
named `enable_<component>` with a default per env. Module calls and
inline resources gate via `count`:

```hcl
module "fluent_bit" {
  count  = var.enable_eks && var.enable_fluent_bit ? 1 : 0
  source = "../../modules/observability-fluent-bit"
  ...
}

resource "aws_opensearch_domain" "logs" {
  count = var.enable_opensearch ? 1 : 0
  ...
}
```

Defaults follow a **dev=light / stg=most / prd=full** ladder. New
optional components add a toggle; don't ship "always on" features.

### Module conventions

Every module has `main.tf` + `variables.tf` + `outputs.tf` + `versions.tf`.

`versions.tf` pins `required_version` and the cloud's provider:

```hcl
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"   # match the env-root pin
    }
  }
}
```

Modules ship public-API variables even when internally unused (callers
depend on the contract). The `terraform_unused_declarations` tflint
rule is disabled in `.tflint.hcl` for this reason — don't churn the
var list to silence it.

### Region defaults

Region variables (`region`, `gcp_region`, `azure_location`) ship with
no `default = "..."` line. Operators set the region explicitly via
`<cloud>/config.env` or `terraform.tfvars`. Internal Astrolift envs
pin `us-west-2`.

---

## Pre-commit validation

Run before pushing:

```bash
./run.sh fmt                                         # terraform fmt -recursive
./run.sh validate                                    # terraform validate per dir
helm lint helm/astrolift -f helm/astrolift/values.aws.yaml
helm lint helm/astrolift -f helm/astrolift/values.gcp.yaml
helm lint helm/astrolift -f helm/astrolift/values.azure.yaml
helm lint helm/astrolift-prereqs                    # if prereqs changed
```

CI re-runs all of the above plus `tflint`, `checkov` (soft-fail), and
helm template artifact rendering. See `.github/workflows/ci-pr.yml`.

---

## Git workflow

```bash
# 1. Branch from main
git checkout -b feature/<area>-<short>   # or fix/, chore/

# 2. Make changes; run pre-commit checks above

# 3. Commit (no co-author trailer; descriptive body)
git commit -m "feat(aws): scaffold modular observability + backup toggles for #5/#6"

# 4. Push the branch
git push origin feature/<area>-<short>

# 5. Open PR; CI runs ci-pr.yml's tier
# 6. Merge via squash; CI runs ci-main.yml on main

# 7. (Submodule case) bump the parent metarepo's gitlink + push that too
cd ../  # into the metarepo
git add astrolift-opscode
git commit -m "chore(workspace): bump astrolift-opscode for <reason>"
git push origin main
```

---

## Configuration

All settings live in `aws/config.env`:

```bash
PROJECT="astrolift"        # Used in all resource naming
AWS_REGION="us-west-2"     # Default region for all environments
OWNER="astrolift"          # Owner tag value
```

Edit this file before bootstrapping. Every script and command reads from it.

## AWS Account Setup

### Step 0: Create the Infrastructure IAM User

Before Terraform can run, you need an IAM user with provisioning permissions. Deploy the CloudFormation template:

```bash
aws cloudformation deploy \
  --template-file aws/cloudformation/infra-user.yml \
  --stack-name astrolift-infra-user \
  --parameter-overrides ProjectSlug=astrolift \
  --capabilities CAPABILITY_NAMED_IAM
```

Then configure your local AWS profile with the output credentials:

```bash
aws configure --profile astrolift-infra
# Enter AccessKeyId and SecretAccessKey from CloudFormation outputs
```

For multi-account setups (AWS Organizations), repeat per account:

```bash
# Dev account
AWS_PROFILE=admin aws cloudformation deploy ... --stack-name astrolift-dev-infra-user
aws configure --profile astrolift-dev-infra

# Prd account
AWS_PROFILE=prd-admin aws cloudformation deploy ... --stack-name astrolift-prd-infra-user
aws configure --profile astrolift-prd-infra
```

### Step 1: Bootstrap State Backends

Each environment gets its own S3 bucket + DynamoDB table:

```bash
# Single account -- bootstrap all environments at once
./run.sh bootstrap aws all

# Multi-account -- bootstrap each with the right profile
AWS_PROFILE=astrolift-dev-infra ./run.sh bootstrap aws dev
AWS_PROFILE=astrolift-stg-infra ./run.sh bootstrap aws stg
AWS_PROFILE=astrolift-prd-infra ./run.sh bootstrap aws prd
```

This creates:
- `tf-state.astrolift-dev.net` / `astrolift-dev-tfstate-lock`
- `tf-state.astrolift-stg.net` / `astrolift-stg-tfstate-lock`
- `tf-state.astrolift-prd.net` / `astrolift-prd-tfstate-lock`

### Step 2: Plan and Apply

```bash
./run.sh plan aws dev       # Review what will be created
./run.sh apply aws dev      # Create the infrastructure
./aws/scripts/cold-boot.sh dev   # Verify deployment health
```

## Environment Topology

```
AWS Account(s)
+-- dev environment
|   +-- VPC: 10.0.0.0/16, 3 AZs, single NAT
|   +-- container_runtime.tf -> ecs/ (enabled) or eks/ (disabled)
|   |   +-- ECS Fargate: 512 CPU, 1 GiB, min 1 / max 4
|   |       +-- ALB (HTTPS + redirect)
|   |       +-- Target group -> :8000/health/
|   |       +-- Auto-scaling (CPU 70%, memory 70%)
|   +-- RDS: PostgreSQL 16, db.t4g.micro, 7-day backups
|   +-- ElastiCache: Redis 7.1, single node
|   +-- S3: {name}-files (versioned, encrypted, CORS)
|   +-- Secrets Manager: db-credentials, app-secrets
|   +-- ACM: wildcard cert (*.${var.base_domain})
|   +-- Route53: ${var.base_domain}  (operator-supplied per-env zone)
|   +-- CloudWatch: 7-day log retention, CPU/memory/5xx alarms
|   +-- SNS: alerts topic
|
+-- stg environment
|   +-- VPC: 10.50.0.0/16, 3 AZs, NAT per AZ
|   +-- ECS Fargate: 1024 CPU, 2 GiB, min 2 / max 6
|   +-- RDS: PostgreSQL 16, db.t4g.small, multi-AZ, 14-day backups
|   +-- ElastiCache: Redis 7.1, 2 nodes multi-AZ
|   +-- CloudWatch: 14-day log retention
|
+-- prd environment
    +-- VPC: 10.100.0.0/16, 3 AZs, NAT per AZ
    +-- ECS Fargate: 1024 CPU, 2 GiB, min 2 / max 10
    +-- RDS: Aurora Serverless v2, 0.5-16 ACU, 30-day backups
    +-- ElastiCache: Redis 7.1, 3 nodes multi-AZ
    +-- CloudWatch: 30-day log retention
```

## Container Runtime

Each environment has `container_runtime.tf` that loads `ecs/` and/or `eks/` as submodules:

```hcl
# variables.tf
enable_ecs = true    # ECS Fargate (default)
enable_eks = false   # EKS Kubernetes (opt-in)
```

Both can coexist. Each runtime brings its own ALB, security groups, IAM roles, log groups, and DNS records. Shared infrastructure (VPC, RDS, Redis, S3, Secrets, ACM) is in the environment root.

To add a second ECS service: copy the `module "ecs"` block in `container_runtime.tf`, change the name and inputs.

### ECS Runtime

- ECS Fargate cluster + service + task definition
- ALB with HTTPS (TLS 1.3) + HTTP->HTTPS redirect
- Target group health check on `/health/`
- Auto-scaling on CPU + memory
- IAM: execution role (pull images, read secrets) + task role (S3, SES, logs)
- CI/CD IAM role for deployments
- CloudWatch log group + CPU/memory/5xx alarms
- Route53 A records (root + wildcard) -> ALB

### EKS Runtime

- EKS cluster (Kubernetes 1.33) with managed spot node groups
- CoreDNS, kube-proxy, vpc-cni addons with IRSA
- ALB controller IRSA for Ingress management
- EFS with KMS encryption for persistent storage
- aws-auth ConfigMap bootstrap
- CloudWatch log group

## Helm Chart

The `helm/astrolift/` directory contains the platform Helm chart for Kubernetes-native installation of the Astrolift control plane. See chart README for values documentation.

## Terraform Structure

```
aws/
  config.env                    # PROJECT, AWS_REGION, OWNER
  cloudformation/
    infra-user.yml              # IAM user for Terraform (run first)
  tf-backend/                   # Layer 0: state backend resources
  environments/
    {dev,stg,prd}/
      main.tf                   # Backend config (empty -- injected at init)
      versions.tf               # Provider constraints
      variables.tf              # enable_ecs, enable_eks, region, etc.
      container_runtime.tf      # Loader for ecs/ and eks/ submodules
      {env}-vpc.tf              # VPC, subnets, NAT, VPC endpoints
      {env}-rds.tf              # PostgreSQL / Aurora
      {env}-elasticache.tf      # Redis
      {env}-s3.tf               # File storage
      {env}-secrets.tf          # Secrets Manager
      {env}-acm.tf              # TLS certificates
      {env}-route53.tf          # DNS zone
      {env}-sg.tf               # Shared security groups (RDS, Redis, bastion)
      {env}-cloudwatch.tf       # SNS alerts topic
      {env}-bastion.tf          # Optional SSH jump host
      ecs/                      # ECS Fargate submodule
        main.tf, variables.tf, outputs.tf
      eks/                      # EKS Kubernetes submodule
        main.tf, variables.tf, outputs.tf
  modules/
    tf-backend-bootstrap/       # S3 + DynamoDB for a new account
    app-deployment-ecs/         # All-in-one ECS deployment module
    bastion/                    # SSH jump host
    dns-exposure/               # Route53 + Cloudflare delegation
  scripts/
    bootstrap.sh                # Create backend + init environments
    cold-boot.sh                # Post-deploy health verification

helm/
  astrolift/                    # Platform Helm chart
    Chart.yaml
    values.yaml
    values.aws.yaml
    templates/
```

## Naming Convention

All resources: `{env}-{project}-{component}`

| Resource | Example |
|----------|---------|
| ECS cluster | `dev-astrolift` |
| ALB | `dev-astrolift-alb` |
| RDS | `dev-astrolift-db` |
| Redis | `dev-astrolift-redis` |
| S3 bucket | `dev-astrolift-files` |
| Log group | `/aws/ecs/dev-astrolift` |
| IAM role | `dev-astrolift-ecs-exec` |

## Tags (mandatory on every resource)

```hcl
tags = {
  Name        = "dev-astrolift"
  Service     = "astrolift"
  Owner       = "astrolift"
  Environment = "development"
  Region      = "us-west-2"
  ManagedBy   = "terraform"
}
```

## Security Model

```
Internet -> ALB (public subnets, 80/443)
             -> ECS/EKS (private subnets)
                -> RDS (database subnets, 5432 from VPC)
                -> Redis (cache subnets, 6379 from VPC)
```

- No hardcoded AWS account IDs -- use `data.aws_caller_identity`
- No secrets in code -- use Secrets Manager
- `lifecycle { ignore_changes }` on secrets and task definitions
- TLS 1.3 on all ALBs
- Storage encryption on RDS, Redis, S3, EFS

## Common Commands

```bash
# Terraform
./run.sh init aws dev           # Initialize (configures backend)
./run.sh plan aws dev           # Preview changes
./run.sh apply aws dev          # Apply changes
./run.sh fmt                    # Format all .tf files
./run.sh validate               # Validate all directories

# Bootstrap
./run.sh bootstrap aws dev      # Create backend + init for dev
./run.sh bootstrap aws all      # All environments

# Verify
./aws/scripts/cold-boot.sh dev  # Health check after deploy

# Switch runtime
terraform -chdir=aws/environments/dev apply -var="enable_eks=true"
```

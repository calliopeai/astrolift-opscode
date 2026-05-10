# Install Astrolift on AWS

End-to-end runbook for a customer-operator installing Astrolift onto an
AWS account. Walks from zero (no infra) to first tenant app deployed
on a tenant EKS cluster managed by an Astrolift control plane on ECS
Fargate.

> **Architectural note** — Astrolift's AWS topology splits responsibilities:
> ECS Fargate hosts the platform's own control plane services (api, ui,
> worker, status); EKS hosts the tenant runtime. They sit in the same
> VPC; the platform talks to the tenant cluster via the EKS access
> entries provisioned during `apply`. You can disable either runtime
> via toggles, but the default install enables both.

---

## 1. Prerequisites

### Tools (operator workstation)

| Tool | Min version | Why |
|---|---|---|
| Terraform | 1.9 | Provisioning |
| AWS CLI v2 | 2.15 | CloudFormation, EKS, IAM ops |
| `kubectl` | 1.28 | EKS verification + helm install |
| `helm` | 3.16 | Platform chart install |
| `astro` CLI | latest | Cluster registration + first app |
| `jq` | any | Output parsing in `cold-boot.sh` |

### AWS account

- A dedicated account per environment (recommended) **or** a shared
  account where you'll run dev/stg/prd in separate VPCs.
- A user/role with `AdministratorAccess` (or equivalent) to run the
  CloudFormation stack in §3 — this only happens once and provisions a
  scoped-down `astrolift-infra` user that Terraform uses.
- A registered Route53 hosted zone for the install's base zone (e.g.
  `myastrolift.net`) — Astrolift creates per-env subdomains under it.

### Repo

```bash
git clone --recurse-submodules https://github.com/<your-fork>/astrolift.git
cd astrolift/astrolift-opscode
```

---

## 2. Configure `aws/config.env`

This file is the single source of truth for project naming + region
across the AWS subtree. Edit before bootstrapping:

```bash
PROJECT="astrolift"
AWS_REGION="us-west-2"
OWNER="astrolift"
```

Constraints:
- `PROJECT` is used in resource names (`{env}-{PROJECT}-{component}`)
  and ECR repo paths (`astrolift/{api,ui,worker,status}`).
- `AWS_REGION` becomes the default for every env unless overridden via
  `terraform.tfvars`.
- `OWNER` is a tag applied to every resource.

---

## 3. One-time: bootstrap the infra IAM user

Astrolift's Terraform doesn't run as your `AdministratorAccess`
identity — it runs as a scoped `{PROJECT}-infra` user provisioned by
CloudFormation. Deploy that user once per account:

```bash
aws cloudformation deploy \
  --template-file aws/cloudformation/infra-user.yml \
  --stack-name astrolift-infra-user \
  --parameter-overrides ProjectSlug=astrolift \
  --capabilities CAPABILITY_NAMED_IAM

# Get the credentials from the stack outputs
aws cloudformation describe-stacks \
  --stack-name astrolift-infra-user \
  --query 'Stacks[0].Outputs'

# Configure a local AWS profile with those credentials
aws configure --profile astrolift-infra
# AWS Access Key ID:     <from stack output>
# AWS Secret Access Key: <from stack output>
# Default region:        us-west-2
# Default output:        json
```

For multi-account operators (dev/stg/prd in separate accounts), repeat
per account using `--profile <account-admin>` to deploy the stack and
`--profile astrolift-{env}-infra` to name the resulting profiles.

---

## 4. Bootstrap the Terraform state backend

Each environment gets its own S3 bucket + DynamoDB lock table for
Terraform state. The `bootstrap` subcommand runs the CloudFormation-style
`tf-backend-bootstrap` module:

```bash
# Single-account: bootstrap all environments at once
AWS_PROFILE=astrolift-infra ./run.sh bootstrap aws all

# Multi-account: bootstrap per environment with the matching profile
AWS_PROFILE=astrolift-dev-infra ./run.sh bootstrap aws dev
AWS_PROFILE=astrolift-stg-infra ./run.sh bootstrap aws stg
AWS_PROFILE=astrolift-prd-infra ./run.sh bootstrap aws prd
```

This creates per-env `tf-state.{project}-{env}.net` S3 buckets and
`{project}-{env}-tfstate-lock` DynamoDB tables, then injects the
backend config into each environment's Terraform init.

---

## 5. Configure environment variables (toggles + sizing)

Each `aws/environments/{env}/variables.tf` exposes the runtime + obs +
backup toggles. Defaults are dev=light / stg=most / prd=full. Override
in a `terraform.tfvars` file inside the env directory:

```hcl
# aws/environments/dev/terraform.tfvars
region = "us-west-2"

# Runtime toggles
enable_ecs                    = true   # control plane on Fargate
enable_eks                    = true   # tenant runtime
enable_amp_amg                = false  # in-cluster Prom by default; flip on for Managed Prom + Grafana
enable_opensearch             = false  # large; flip on for stg/prd

# Backup toggles
enable_velero                 = true
enable_aws_backup             = true
enable_dynamodb_pitr          = true
enable_s3_glacier_lifecycle   = true

# Observability
enable_fluent_bit             = true
enable_otel_xray              = true
```

See **§ Toggle reference** below for the full matrix.

---

## 6. Plan + review

```bash
AWS_PROFILE=astrolift-infra ./run.sh plan aws dev
```

Save the plan output. **Read it.** Look for:
- Resource counts that match what you expect (~150-250 for dev, more for prd)
- Any IAM role with `Path` other than `/astrolift/` — that's a bug; the
  AWS provider plugin assumes roles live under `/astrolift/`
- VPC CIDR conflicts with existing peerings
- Route53 zone — confirm you own the parent zone if delegating

If the plan looks wrong, edit `terraform.tfvars` or the env-root files
and re-plan.

---

## 7. Apply

```bash
AWS_PROFILE=astrolift-infra ./run.sh apply aws dev
```

First-apply takes 25-40 min depending on toggles. Order is enforced by
Terraform's resource graph; key milestones:

1. VPC + subnets + NAT + VPC endpoints (3-4 min)
2. RDS / ElastiCache / S3 / Secrets / KMS (10-15 min)
3. EKS cluster + node groups (15-20 min — slowest)
4. ECS cluster + services + ALB (5 min)
5. Route53 records + ACM cert validation (1-3 min, ACM may need DNS validation propagation)
6. Observability + backup modules (gated by toggles, 2-5 min each)

---

## 8. Verify with `cold-boot.sh`

After apply succeeds:

```bash
./aws/scripts/cold-boot.sh dev
```

This script validates:
- ALB targets are healthy (waits up to 10 min by default)
- ECS service tasks are running
- DNS records resolve
- EKS API responds
- Health endpoints return 200

If any check fails, the script prints the AWS CLI command you can run
to inspect that resource directly.

---

## 9. Install the platform Helm chart

Once the cluster is up, populate the Helm values from Terraform outputs
and install:

```bash
# Pull outputs into an env file (one-shot, gitignored)
cd aws/environments/dev
terraform output -json > /tmp/dev-outputs.json
# Generate aws/outputs/dev.env from the json + the dev.env.example template
# (a small jq pipeline; see scripts/build-env.sh in a follow-up)

cd ../../../
helm install astrolift ./helm/astrolift \
  -f ./helm/astrolift/values.aws.yaml \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="$IRSA_ROLE_ARN" \
  --set api.image.repository="$ECR_REGISTRY/astrolift/api" \
  --set ui.image.repository="$ECR_REGISTRY/astrolift/ui" \
  --set worker.image.repository="$ECR_REGISTRY/astrolift/worker" \
  --set status.image.repository="$ECR_REGISTRY/astrolift/status" \
  --set api.env.DATABASE_URL="$DATABASE_URL" \
  --set api.env.REDIS_URL="$REDIS_URL"
```

(For repeat installs, write the env vars into a `values.dev.yaml` and
load with `-f`.)

---

## 10. Register the cluster with the Astrolift control plane

The control plane needs to know about the tenant cluster you just
provisioned. Generate the cluster registration config:

```bash
cat > aws-dev-cluster.yaml <<EOF
plugin: aws
name: dev-astrolift-tenant
region: us-west-2
cluster_name: dev-astrolift
account_id: $(aws sts get-caller-identity --query Account --output text --profile astrolift-infra)
oidc_provider_arn: <from terraform output oidc_provider_arn>
ecr_registry: <ACCOUNT>.dkr.ecr.us-west-2.amazonaws.com
EOF

astro cluster register --config aws-dev-cluster.yaml
```

The platform will validate the cluster, exchange a token, and start
managing tenant deploys on it.

---

## 11. Deploy a first app

```bash
# From a tenant repo containing astrolift.toml
astro app new --template python-fastapi --org demo --name hello
astro app register --org demo --name hello
astro app deploy --org demo --name hello --env staging
```

If everything is wired up, `astro app status --org demo --name hello`
shows the deploy progressing through `building → pushing → applying →
ready`. Hit `https://hello.demo.dev.astrolift.app` to see it live.

---

## Multi-environment (dev / stg / prd)

The three env-roots have different defaults:

| | dev | stg | prd |
|---|---|---|---|
| VPC CIDR | `10.0.0.0/16` | `10.50.0.0/16` | `10.100.0.0/16` |
| NAT topology | single | per-AZ | per-AZ |
| RDS | `db.t4g.micro`, single-AZ | `db.t4g.small`, multi-AZ | Aurora Serverless v2 |
| ElastiCache | single node | 2-node multi-AZ | 3-node multi-AZ |
| RDS backup retention | 7 days | 14 days | 30+ days |
| CloudWatch retention | 7 days | 14 days | 30 days |
| `enable_opensearch` | false | true | true |
| `enable_amp_amg` | false | false | true |
| `enable_velero` | false | true | true |
| `enable_aws_backup` | false | true | true |

Run apply per-env in order: dev → stg → prd. Each is independent — no
cross-env state.

---

## Toggle reference

All toggles are in `aws/environments/{env}/variables.tf`. Override per
env via `terraform.tfvars`.

### Runtime
| Toggle | Effect |
|---|---|
| `enable_ecs` | Provision the ECS Fargate runtime + ALB for the platform control plane |
| `enable_eks` | Provision the EKS tenant runtime + node groups |

### Observability
| Toggle | Effect | Pairs with |
|---|---|---|
| `enable_fluent_bit` | DaemonSet → CloudWatch Logs | observability-fluent-bit module |
| `enable_amp_amg` | AMP workspace + AMG dashboard | observability-amp + observability-amg |
| `enable_otel_xray` | OTel collector → X-Ray | observability-otel-xray |
| `enable_in_cluster_prom` | Prometheus + Grafana via Helm | astrolift-prereqs chart |
| `enable_opensearch` | OpenSearch domain for log aggregation | inline in `{env}-opensearch.tf` |

### Backup
| Toggle | Effect |
|---|---|
| `enable_velero` | Velero install + S3 backup bucket + IRSA |
| `enable_aws_backup` | AWS Backup vault + plan + RDS/EFS selection |
| `enable_dynamodb_pitr` | Enable PITR on managed DynamoDB tables |
| `enable_s3_glacier_lifecycle` | Glacier transition lifecycle on artifact bucket |

---

## Troubleshooting

### `terraform apply` fails on EKS create timeout
Cluster create can hit 15 min; node group can hit another 10. Re-run
apply — Terraform picks up where it left off.

### ACM certificate stuck in `PENDING_VALIDATION`
The DNS validation CNAME records get added by Terraform automatically,
but DNS propagation can take 5-15 min. If it stays pending past 30 min,
check that your Route53 zone is delegated correctly from the parent.

### `cold-boot.sh` says targets unhealthy
Check ECS service events via:
```bash
aws ecs describe-services \
  --cluster dev-astrolift \
  --services dev-astrolift-api \
  --query 'services[0].events[:10]' \
  --profile astrolift-infra
```
Most common cause: image not yet pushed to ECR. Push placeholder images
to all 4 ECR repos before the first apply.

### Helm install fails on missing IRSA role
The `serviceAccount.annotations.eks\.amazonaws\.com/role-arn` value
needs to come from the Terraform output `irsa_role_arn` for whichever
service it annotates. If you skipped step 9's templating, that value is
empty and pod creation will fail with `WebIdentityErr`.

### `astro cluster register` fails on `oidc:assume-role`
The cluster's OIDC provider ARN must match what's in the registration
config. Re-fetch via `terraform output oidc_provider_arn`.

---

## Tear down

```bash
./run.sh destroy aws dev
# Then delete the state backend if you're done with the environment:
# (manual — be careful, this is irreversible)
aws s3 rb --force s3://tf-state.astrolift-dev.net --profile astrolift-infra
aws dynamodb delete-table --table-name astrolift-dev-tfstate-lock --profile astrolift-infra
```

If you want to keep the IAM user but tear down the rest:
```bash
./run.sh destroy aws all
```

---

## What's outside this runbook

- Multi-region setup (one install per region; cross-region failover is
  per-flow, not topology)
- Custom KMS keys (default uses AWS-managed; bring your own via
  `kms_key_id` overrides per resource group — TODO)
- Self-hosted observability backends (Datadog, Honeycomb) — see
  `helm/tenant-telemetry/` for OTel collector value templates that ship
  to those backends instead of CloudWatch / X-Ray
- Air-gapped install with vendored Helm charts — see `make package`
  in the workspace metarepo

For ongoing operations after install, see `astrolift-opscode/bootstrap.md`.

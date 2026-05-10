# astrolift-opscode

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Terraform](https://img.shields.io/badge/terraform-%3E%3D1.5-7B42BC.svg)](https://www.terraform.io/)
[![Helm](https://img.shields.io/badge/helm-%3E%3D3.16-0F1689.svg)](https://helm.sh/)

Terraform + Helm infrastructure-as-code for installing the
[Astrolift](https://astrolift.app) platform on a cloud you control.
Fork this, set a few config values, and you have an opinionated
multi-tenant PaaS install path.

> **Status posture (be honest about it).** AWS is structurally complete
> with a full operator runbook ([INSTALL-aws.md](INSTALL-aws.md)) and is
> the recommended starting point for production deploys, though it has
> not yet been validated against a live AWS account end-to-end. GCP and
> Azure ship a working `dev` environment but `stg`/`prd` are still
> skeletons. The k8s-native path (no managed cloud — vanilla Kubernetes
> + Longhorn + CNPG + friends) targets local `kind` dev clusters and
> bare-metal installs.
>
> **Read [STATUS.md](STATUS.md) before forking or filing an issue** —
> it's the canonical map of what's complete, partial, stub, and
> intentionally limited.

---

## What's inside

| Path | Contains |
|---|---|
| `aws/`, `gcp/`, `azure/` | Per-cloud Terraform — `tf-backend/` for state, `environments/{dev,stg,prd}/` for per-env stacks, `modules/` for reusable + observability + backup pieces |
| `kubernetes/` | Cloud-agnostic baseline installer (cert-manager, external-dns, Fluent Bit, Loki, Prometheus, Argo CD, Gateway API + Envoy) |
| `helm/astrolift/` | Helm chart for the Astrolift control plane (api / ui / worker / status) with per-cloud `values.<cloud>.yaml` overrides |
| `helm/astrolift-prereqs/` | Umbrella chart of operators a vanilla cluster needs — cert-manager, ingress-nginx, Longhorn, Rook Ceph, CNPG, Strimzi, Bitnami Redis Operator, Vault, Velero, kube-prometheus-stack, Loki, Tempo, OTel collector. Each subchart toggleable. |
| `helm/tenant-telemetry/` | Per-cloud values files for tenant-side fluent-bit + OpenTelemetry collector (CloudWatch / Cloud Logging / Log Analytics / in-cluster Loki+Tempo) |
| `ci-templates/` | Reusable CI workflow templates: GitHub Actions reusable workflow, GitLab CI include, Buildkite plugin pipeline. Plus a tenant-facing **style-gates** workflow + shared `pre-commit-config.yaml`. Monorepo selective build via `path-filter.sh`. |
| `gitops/` | ArgoCD AppProject + ApplicationSet + Application + repo-creds templates; Flux GitRepository + Kustomization + HelmRelease + ImageAutomation templates. Operators pick one engine per cluster. |
| `INSTALL-<cloud>.md` | Per-cloud customer-operator runbooks (AWS shipped, k8s-native shipped, GCP/Azure pending) |

---

## Quick start

### Cloud install (production-bound)

Pick a cloud and follow its runbook end-to-end:

- **[INSTALL-aws.md](INSTALL-aws.md)** — full runbook, ~30-40 min for first apply
- **[INSTALL-k8s-native.md](INSTALL-k8s-native.md)** — vanilla Kubernetes + bare-metal
- **INSTALL-gcp.md** — TODO (template in INSTALL-aws.md; the GCP `dev/`
  Terraform tree exists; runbook follows the same shape)
- **INSTALL-azure.md** — TODO (same)

Each runbook walks: prerequisites → IAM/identity bootstrap → state backend
→ Terraform plan/apply → Helm chart install → cluster registration →
first tenant app deploy.

### Local dev (kind, no cloud account)

If you just want to see the platform run on your laptop:

```bash
# Stand up a kind cluster + the prereqs astrolift expects
./kubernetes/base/install.sh kind dev

# Install the platform itself
helm install astrolift ./helm/astrolift -f ./helm/astrolift/values.k8s.yaml

# (Tenant app registration via the astro CLI — see astrolift docs)
```

Sub-5-minute target on a clean machine; some prereq installs (Loki,
Prometheus) take a bit longer.

---

## Configuration

Each cloud has a `<cloud>/config.env` file with project naming + region.
Edit before first apply:

```bash
# aws/config.env
PROJECT="astrolift"        # used in resource names + ECR paths
AWS_REGION="us-west-2"
OWNER="astrolift"          # tag value
```

Per-environment toggles live in `<cloud>/environments/<env>/variables.tf`
and override via `terraform.tfvars`. Defaults follow a
**dev=light / stg=most / prd=full** ladder for optional components
(observability backends, backup, OpenSearch, lifecycle policies).

See each cloud's INSTALL runbook for the full toggle reference.

---

## Common commands

```bash
./run.sh bootstrap aws dev      # one-time state backend setup
./run.sh init      aws dev      # terraform init
./run.sh plan      aws dev      # plan against real backend
./run.sh apply     aws dev      # apply
./run.sh destroy   aws dev      # tear down
./run.sh fmt                    # terraform fmt -recursive
./run.sh validate               # terraform validate per-dir

./aws/scripts/cold-boot.sh dev          # post-apply health checks
./aws/scripts/build-env.sh dev          # generate env file for Helm install
```

CI (`.github/workflows/`) runs the same commands plus `tflint`,
`helm lint/template`, `checkov` security scan, path-filter smoke test,
and helm template artifact rendering. See [bootstrap.md](bootstrap.md)
for the full conventions doc.

---

## Architecture in one paragraph

A single Astrolift "install" = one DNS zone + one database. Inside the
install, control-plane replicas (api/ui/workers) scale horizontally for
HA. The control plane manages tenant clusters across one or more
clouds via a typed driver protocol — AWS via EKS, GCP via GKE, Azure
via AKS, vanilla via the k8s-native plugin. The control plane itself
runs on whatever runtime makes sense for each cloud (ECS Fargate on
AWS, Cloud Run on GCP, Container Apps on Azure, in-cluster on k8s
native). You can run **N independent installs** across regions and
clouds; there is no master orchestrating across them — federation and
cross-install flows are per-flow, never synchronous.

Full topology + driver contract docs live in
[bootstrap.md](bootstrap.md) here, plus the spec set in the parent
metarepo.

---

## Forking

This repo is MIT-licensed and designed to be forked. Likely customizations:

| What | Where |
|---|---|
| Project slug (default `astrolift`) | `<cloud>/config.env` |
| Region | `<cloud>/config.env` + `terraform.tfvars` |
| Per-env sizing (DB tier, replica counts, retention) | `<cloud>/environments/<env>/variables.tf` |
| Toggle defaults (which optional pieces install) | `<cloud>/environments/<env>/variables.tf` |
| ECR / Artifact Registry / ACR repo names | matches `PROJECT` slug from `config.env` |
| DNS base zone | `base_domain` in `<cloud>/environments/<env>/terraform.tfvars` (required, no default — bring your own zone) |
| KMS keys | TODO — `kms_key_id` overrides not yet wired |
| Observability backend (Datadog / Honeycomb / etc.) | `helm/tenant-telemetry/otel-collector/values-<cloud>.yaml` |

Most things you'll want to customize are already variables; the rest
fall out cleanly from the toggle pattern.

If you find a hardcoded `astrolift` reference that should be a variable,
file an issue or PR — the goal is to keep this fork-friendly.

---

## Status snapshot

| Path | Status | Notes |
|---|---|---|
| AWS | Structurally complete; runbook shipped | Not yet end-to-end validated against a live account; first-apply pending |
| GCP | `dev/` complete; `stg`/`prd` skeleton | Runbook pending; same shape as AWS |
| Azure | `dev/` complete; `stg`/`prd` skeleton | Runbook pending; same shape as AWS |
| k8s-native | umbrella chart + kind dev profile + runbook | Spec #11 sub-5-min target not yet enforced |
| CI templates (GHA / GitLab / Buildkite) | Shipped | Style-gates + deploy + monorepo selective build all work |
| GitOps templates (ArgoCD / Flux) | Shipped | Substituted server-side per tenant |
| Self-CI for opscode | Green end-to-end | Tiered (cheap PR / medium main / heavy release) |

Open follow-ups tracked in GitHub Issues.

---

## Documentation

- **[STATUS.md](STATUS.md)** — what's complete / partial / stub / known-limited (read this first)
- **[bootstrap.md](bootstrap.md)** — infrastructure topology + first-time setup conventions
- **[INSTALL-aws.md](INSTALL-aws.md)** — AWS customer-operator runbook
- **[INSTALL-k8s-native.md](INSTALL-k8s-native.md)** — vanilla Kubernetes / bare-metal runbook
- **[CONTRIBUTING.md](CONTRIBUTING.md)** — fork + PR flow + style requirements
- **[SECURITY.md](SECURITY.md)** — vulnerability disclosure
- **[CLAUDE.md](CLAUDE.md)**, **[AGENTS.md](AGENTS.md)**, **[GEMINI.md](GEMINI.md)** — agent shims (all point at bootstrap.md)
- **[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)** — community standards
- **[LICENSE](LICENSE)** — MIT

---

## License

MIT. See [LICENSE](LICENSE).

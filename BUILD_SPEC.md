# Build Spec -- Astrolift Opscode (Infrastructure Templates)

## Context

Terraform + Helm infrastructure-as-code for deploying the Astrolift platform. AWS-first with GCP and Azure structured for future expansion.

## Architecture

```
astrolift-opscode/
+-- README.md
+-- CLAUDE.md
+-- bootstrap.md
+-- AGENTS.md
+-- run.sh                          # Command center
+-- Makefile
|
+-- aws/                            # AWS infrastructure
|   +-- tf-backend/                 # Layer 0: S3 + DynamoDB state backend
|   +-- environments/
|   |   +-- dev/                    # Development environment
|   |   +-- stg/                    # Staging environment
|   |   +-- prd/                    # Production environment
|   +-- modules/                    # Reusable modules
|   +-- scripts/
|       +-- bootstrap.sh
|       +-- cold-boot.sh
|
+-- gcp/                            # GCP infrastructure (structured, minimal)
+-- azure/                          # Azure infrastructure (structured, minimal)
+-- kubernetes/                     # Kubernetes base platform
+-- helm/                           # Platform Helm chart
|   +-- astrolift/
|       +-- Chart.yaml
|       +-- values.yaml
|       +-- values.aws.yaml
|       +-- templates/
|
+-- .github/
+-- LICENSE
+-- CODE_OF_CONDUCT.md
+-- SECURITY.md
+-- CONTRIBUTING.md
```

## Naming Convention

All resources follow: `{env}-{project}-{component}`
- ECS cluster: `dev-astrolift`
- S3 bucket: `dev-astrolift-files`
- RDS: `dev-astrolift-db`
- Log group: `/aws/ecs/dev/astrolift`

## Tags (mandatory on every resource)

```hcl
locals {
  tags = {
    Name        = "dev-astrolift"
    Service     = "astrolift"
    Owner       = "astrolift"
    Environment = "development"
    Region      = "us-west-2"
    ManagedBy   = "terraform"
  }
}
```

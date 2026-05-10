# Astrolift CI Templates

Reusable CI/CD workflow templates for deploying tenant apps to Astrolift.
Each template handles: checkout → OIDC registry auth → BuildKit build with
registry cache → push → `astro ci deploy` → wait → status report.

Path filtering for monorepo selective builds is built in: only workloads
whose `build_context` had changes get rebuilt. Override with
`force_build_all=true`.

## Quick start

### GitHub Actions

```yaml
# .github/workflows/deploy.yml
name: deploy
on:
  push:
    branches: [main]
jobs:
  deploy:
    uses: astrolift/actions/.github/workflows/deploy.yml@v1
    with:
      app_name: my-app
      environment: production
    secrets:
      astrolift_token: ${{ secrets.ASTROLIFT_TOKEN }}
```

### GitLab CI

```yaml
# .gitlab-ci.yml
include:
  - remote: https://templates.astrolift.dev/gitlab/deploy.yml

variables:
  ASTROLIFT_APP: my-app
  ASTROLIFT_ENVIRONMENT: production
```

### Buildkite

```yaml
# .buildkite/pipeline.yml
steps:
  - plugins:
      - astrolift/deploy#v1:
          app_name: my-app
          environment: production
```

## OIDC registry auth

All templates use OIDC federation — no static cloud credentials in CI.
The `astro ci registry-login` subcommand detects the target cluster's
cloud (from `astrolift.toml` + cluster registration) and exchanges the
CI provider's OIDC token for a short-lived registry credential.

Operators must grant the CI provider's OIDC subject the relevant
registry-write role:
- AWS: trust policy on the ECR push role for `repo:<org>/<repo>:ref:refs/heads/main` (etc.)
- GCP: Workload Identity Pool federation for the GitHub Actions / GitLab issuer
- Azure: Federated credential on a UAMI bound to AcrPush

See `specs/14-ci-cd-and-build.md` §5 for the full setup matrix.

## Monorepo support

Two patterns supported (per spec 14 §13):

1. **One app per service** — each `RegisteredApp` has its own `manifest_path`
   pointing to a sub-path. CI filters changes by the workload's
   `build_context`.
2. **One app, multiple workloads** — one `astrolift.toml` declares all
   services. The template builds each workload whose `build_context` had
   changes; unchanged workloads retain their current image tag.

The shared `path-filter.sh` script reads `astrolift.toml` and emits the
filter spec each CI system understands (`dorny/paths-filter` YAML for
GHA, `rules.changes` patterns for GitLab, diff-based shell for Buildkite).

## Build cache

BuildKit registry-backed cache is on by default with `mode=max`:
- cache-from: `type=registry,ref=<repo>:buildcache`
- cache-to: `type=registry,ref=<repo>:buildcache,mode=max`

Operators with a self-hosted cache (e.g. ECR pull-through) can override
the cache repo via the `cache_repo` input.

## Style gates (#16)

Reusable workflow that auto-detects which languages are present and runs
the matching linter — no-op for languages not in the repo, so the same
template works for any tenant stack.

```yaml
# .github/workflows/style.yml
name: style
on: [pull_request, push]
jobs:
  style:
    uses: astrolift/actions/.github/workflows/style-gates.yml@v1
```

Languages covered: ruff (Python), biome (TypeScript/JavaScript),
golangci-lint (Go), terraform fmt + tflint (HCL), helm lint (charts),
shellcheck (bash). Each toggleable via inputs (e.g. `python_paths`,
`go_paths`).

## Pre-commit hooks

Drop `ci-templates/shared/pre-commit-config.yaml` into a tenant repo as
`.pre-commit-config.yaml` and run `pre-commit install`. Same toolchain
as the style-gates workflow so local + CI agree.

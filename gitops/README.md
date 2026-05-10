# GitOps configuration templates

ArgoCD + Flux templates the Astrolift platform renders into tenant
GitOps repos (typically `astrolift-config`) when an operator enables
GitOps mode for an org. Templates use shell-style `${VAR}` placeholders
that the platform substitutes per tenant.

## Layout

```
gitops/
  argocd/
    appproject.yaml          # Per-org AppProject scoping which repos/clusters/namespaces it can access
    applicationset.yaml      # ApplicationSet generating one Application per tenant app + env
    application.yaml         # Standalone Application template for one app
    repo-creds.yaml          # ExternalSecret pulling repo creds from cloud secret store
  flux/
    gitrepository.yaml       # Source GitRepository (per-org)
    kustomization.yaml       # Per-app Kustomization sync
    helmrelease.yaml         # Per-app HelmRelease (when tenant ships a chart)
    image-automation.yaml    # ImageRepository + ImagePolicy + ImageUpdateAutomation
```

## Substitution variables

The platform substitutes these per render:

| Variable | Example | Source |
|---|---|---|
| `ORG` | `acme` | tenant org slug |
| `APP` | `frontend` | tenant app slug |
| `ENV` | `production` / `staging` / `preview-42` | tenant deploy env |
| `REPO_URL` | `git@github.com:acme/frontend.git` | tenant app's source repo |
| `REPO_REVISION` | `main` / a branch / tag | per-deploy |
| `CLUSTER_NAME` | `prd-us-west-2-tenant` | astrolift cluster registration |
| `BASE_ZONE` | `acme.myastrolift.net` | per-install + per-org config |
| `SECRET_STORE_REF` | `cloud-secret-store` | ExternalSecrets ClusterSecretStore name |

Substitution happens server-side in the platform; these YAMLs are
templates, not directly applyable. For local hand-render use `envsubst`:

```bash
ORG=acme APP=frontend ENV=staging REPO_URL=... \
  envsubst < gitops/argocd/application.yaml > /tmp/rendered-app.yaml
```

## Both vs. either-or

ArgoCD and Flux are alternatives — operators pick one per cluster. The
platform's GitOps mode reads `astrolift-config/<cluster>/gitops_engine`
and renders only the matching template set into the config repo.

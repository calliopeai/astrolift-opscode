# CODEX.md — Astrolift Opscode

Technical reference for AI agents working in this repo lives in
**[`bootstrap.md`](./bootstrap.md)**. Read it first.

Then check **[`STATUS.md`](./STATUS.md)** for what's complete vs partial
vs stub before adding new scope or marking work done.

## Top-of-mind rules

1. **No rebases.** New commits only.
2. **No AI / co-author attribution** in commits.
3. **Push submodules before parent metarepo.**
4. **No `terraform apply`** from an agent session.
5. **`terraform fmt -recursive` + `terraform validate` + `helm lint`
   before commit.**
6. **Don't push --force to main** without explicit human approval.
7. **No cross-project references** in code or docs.

## Conventions quick-glance

- Naming: `{env}-{project}-{component}`
- Tags mandatory; `merge(local.tags, { ... })` for additions
- Toggle pattern: every optional component is `enable_<x>` gated by `count`
- Region vars carry no default; operators set via `config.env` or tfvars
- New modules need `versions.tf` (pinned `required_version` + provider)

Full conventions, git workflow, pre-commit checks, and topology in
`bootstrap.md`.

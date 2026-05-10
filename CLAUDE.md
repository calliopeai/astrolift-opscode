# CLAUDE.md — Astrolift Opscode

Technical reference for AI agents working in this repo lives in
**[`bootstrap.md`](./bootstrap.md)**. Read it first.

Then check **[`STATUS.md`](./STATUS.md)** for what's complete vs partial
vs stub before adding new scope or marking work done.

## Top-of-mind rules

These also live in `bootstrap.md` § Agent + contributor rules; surfacing
here so a quick-glance agent sees them:

1. **No rebases.** New commits only. No `git rebase`.
2. **No AI / co-author attribution** in commits or PR bodies.
3. **Push submodules before the parent metarepo.** This repo is a
   submodule of `astrolift`.
4. **No `terraform apply` from an agent session.** Plan-only is fine
   for review; apply runs from a human's shell.
5. **`terraform fmt -recursive` + `terraform validate` + `helm lint`
   before commit.** CI catches the rest.
6. **Don't push --force to main without explicit human approval.** If
   history rewrite is requested, confirm scope first.
7. **No cross-project references** — reference repos are learning
   sources only; don't link or cite them from this repo.

## Conventions quick-glance

- Naming: `{env}-{project}-{component}`
- Tags mandatory; `merge(local.tags, { ... })` for additions
- Toggle pattern: every optional component is `enable_<x>` gated by `count`
- Region vars carry no default; operators set via `config.env` or tfvars
- New modules need `versions.tf` (pinned `required_version` + provider)

For everything else, see `bootstrap.md`.

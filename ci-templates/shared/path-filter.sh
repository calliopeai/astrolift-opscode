#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Astrolift path-filter
#
# Reads astrolift.toml and emits filter specs in three formats:
#   --format=dorny     (default)  → dorny/paths-filter YAML for GHA
#   --format=gitlab    → newline-separated paths for `rules.changes:`
#   --format=changed   → JSON list of workload names whose build_context
#                        intersects the diff (used by Buildkite + as a
#                        post-process for GHA + GitLab)
#
# When --format=changed and --diff-base=<ref> is provided, computes the
# git diff against <ref> and intersects with each workload's build_context.
# -----------------------------------------------------------------------------

set -euo pipefail

MANIFEST="astrolift.toml"
FORMAT="dorny"
DIFF_BASE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --manifest)   MANIFEST="$2"; shift 2 ;;
    --format)     FORMAT="$2"; shift 2 ;;
    --diff-base)  DIFF_BASE="$2"; shift 2 ;;
    *)            echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ ! -f "$MANIFEST" ]]; then
  echo "manifest not found: $MANIFEST" >&2
  exit 2
fi

# Extract workloads + build_context from astrolift.toml using Python
# (tomllib is stdlib in 3.11+; tomli is the back-port).
WORKLOADS_JSON=$(python3 - "$MANIFEST" <<'PY'
import sys
import json
try:
    import tomllib
except ImportError:  # py < 3.11
    import tomli as tomllib

with open(sys.argv[1], "rb") as f:
    manifest = tomllib.load(f)

workloads = manifest.get("workloads", {})
out = []
for name, cfg in workloads.items():
    ctx = cfg.get("build_context", f"./{name}")
    out.append({"name": name, "build_context": ctx.rstrip("/")})

# If no [workloads.*] tables, treat the whole repo as one default workload.
if not out:
    out = [{"name": "default", "build_context": "."}]

print(json.dumps(out))
PY
)

case "$FORMAT" in
  dorny)
    echo "$WORKLOADS_JSON" | python3 -c "
import json, sys
for w in json.load(sys.stdin):
    name = w['name']
    ctx = w['build_context']
    print(f'{name}:')
    if ctx == '.':
        print('  - \"**\"')
    else:
        print(f'  - {ctx}/**')
"
    ;;

  gitlab)
    echo "$WORKLOADS_JSON" | python3 -c "
import json, sys
for w in json.load(sys.stdin):
    ctx = w['build_context']
    if ctx == '.':
        print('**/*')
    else:
        print(f'{ctx}/**/*')
"
    ;;

  changed)
    if [[ -z "$DIFF_BASE" ]]; then
      # No diff base = everything changed (force-build mode).
      echo "$WORKLOADS_JSON" | python3 -c "
import json, sys
print(json.dumps([w['name'] for w in json.load(sys.stdin)]))
"
      exit 0
    fi

    # Compute changed files relative to DIFF_BASE.
    CHANGED=$(git diff --name-only "$DIFF_BASE"...HEAD)

    echo "$WORKLOADS_JSON" | CHANGED="$CHANGED" python3 -c "
import json, os, sys

changed = [p for p in os.environ.get('CHANGED', '').splitlines() if p]
workloads = json.load(sys.stdin)

def matches(ctx, files):
    if ctx == '.':
        return bool(files)
    ctx_prefix = ctx.lstrip('./').rstrip('/') + '/'
    return any(f.startswith(ctx_prefix) for f in files)

names = [w['name'] for w in workloads if matches(w['build_context'], changed)]
print(json.dumps(names))
"
    ;;

  *)
    echo "unknown format: $FORMAT (expected dorny|gitlab|changed)" >&2
    exit 2
    ;;
esac

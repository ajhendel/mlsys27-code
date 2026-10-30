#!/usr/bin/env bash
# Publish docs.anon.example and anon.example: one command, run by hand (nothing schedules it).
#
#   tools/publish_sites.sh [--dry-run]
#
# Builds from the LATEST origin/main of both repos, in this command's own build worktrees, so the state of
# your checkouts never matters:
#   1. fetch both repos; reset the build worktrees to origin/main; print both commits
#   2. version: the latest anonlib on PyPI (warns if python/anonlib/_version.py at origin/main differs)
#   3. docs: install that release (and docs-site/requirements.txt) into the docs venv, then
#      docs-site/tools/build.sh -> <anonlib worktree>/docs-site/_site
#   4. site: anon.example tools/build.sh -> measurements.json from the anonlib origin/main boards,
#      astro build -> <anon.example worktree>/dist
#   5. build record (version, both commits, UTC time) as /build.json on both sites and in the run's log dir
#   6. deploy both with wrangler (skipped by --dry-run)
#
# Settings (environment, with defaults):
#   ANONLIB_SITES_WORK   ~/.cache/anonlib-sites   build worktrees, docs venv, logs/<UTC stamp>/
#   ANONLIB_ORG_REPO     <anonlib main checkout>/../anon.example   a clone of anon.example (git objects only)
#   ANONLIB_DOCS_PYTHON  python3                    interpreter that creates the docs venv
# wrangler uses your Cloudflare login (wrangler login) or CLOUDFLARE_API_TOKEN.
set -euo pipefail

usage() { sed -n 2,22p "$0"; }
DRY=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

HERE="$(cd "$(dirname "$0")" && pwd)"
ML_REPO="$(git -C "$HERE" rev-parse --show-toplevel)"
ML_MAIN="$(git -C "$ML_REPO" worktree list --porcelain | sed -n '1s/^worktree //p')"
ORG_REPO="${ANONLIB_ORG_REPO:-$(dirname "$ML_MAIN")/anon.example}"
WORK="${ANONLIB_SITES_WORK:-$HOME/.cache/anonlib-sites}"
DOCS_PY="${ANONLIB_DOCS_PYTHON:-python3}"
ML_WT="$WORK/anonlib"
ORG_WT="$WORK/anon.example"
VENV="$WORK/docs-venv"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
LOGS="$WORK/logs/$STAMP"
mkdir -p "$LOGS"

[ -d "$ORG_REPO/.git" ] || [ -f "$ORG_REPO/.git" ] || { echo "publish_sites: no anon.example clone at $ORG_REPO (set ANONLIB_ORG_REPO)" >&2; exit 2; }

# step <name> <command...>: full output to $LOGS/<name>.log; on failure, its last lines and the log path.
# The command runs in a subshell with errexit on (not under `if`, where bash would ignore errexit).
step() {
  local name=$1 rc; shift
  printf '== %-15s ' "$name"
  set +e
  ( set -e; "$@" ) > "$LOGS/$name.log" 2>&1
  rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    echo "ok"
  else
    echo "FAILED (rc=$rc), log: $LOGS/$name.log"
    tail -n 20 "$LOGS/$name.log" | cut -c1-240
    exit "$rc"
  fi
}

# A build worktree of <repo> at <dir>, detached at a freshly fetched origin/main, with nothing else in it.
# <sparse...>: directories to check out (the whole tree when none are given).
fresh_worktree() {
  local repo=$1 dir=$2; shift 2
  git -C "$repo" fetch --quiet --tags origin main
  git -C "$repo" worktree prune
  if [ ! -e "$dir/.git" ]; then
    rm -rf "$dir"
    git -C "$repo" worktree add --quiet --detach --no-checkout "$dir" origin/main
    if [ "$#" -gt 0 ]; then git -C "$dir" sparse-checkout set "$@"; fi
  fi
  git -C "$dir" checkout --quiet --detach --force origin/main
  git -C "$dir" reset --quiet --hard origin/main
  git -C "$dir" clean -ffdxq
}

echo "publish_sites: $( [ "$DRY" = 1 ] && echo DRY RUN, no deploy || echo build and deploy ); logs in $LOGS"
step fetch-anonlib fresh_worktree "$ML_REPO" "$ML_WT" docs-site python/anonlib
step fetch-org fresh_worktree "$ORG_REPO" "$ORG_WT"
ML_SHA="$(git -C "$ML_WT" rev-parse HEAD)"
ORG_SHA="$(git -C "$ORG_WT" rev-parse HEAD)"
echo "   anonlib     origin/main $ML_SHA"
echo "   anon.example origin/main $ORG_SHA"

VERSION="$(curl -fsS --max-time 30 https://pypi.org/pypi/anonlib/json | python3 -I -c 'import json,sys; print(json.load(sys.stdin)["info"]["version"])')"
REPO_VERSION="$(git -C "$ML_WT" show "$ML_SHA:python/anonlib/_version.py" | python3 -I -c 'import re,sys; m = re.search(r"^__version__ *= *[\x27\x22]([^\x27\x22]+)", sys.stdin.read(), re.M); print(m.group(1) if m else "")')"
echo "   release       $VERSION (PyPI); origin/main _version.py says ${REPO_VERSION:-?}"
if [ "$VERSION" != "$REPO_VERSION" ]; then
  echo "   note: the docs and site describe the PyPI release $VERSION; origin/main is at ${REPO_VERSION:-?}"
fi

python3 -I - "$WORK/build.json" "$VERSION" "$ML_SHA" "$ORG_SHA" <<'PY'
import datetime, json, sys
out, version, ml, org = sys.argv[1:]
json.dump({"version": version, "anonlib_commit": ml, "anonlib_org_commit": org, "boards_commit": ml,
           "built_utc": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
           "built_by": "anonlib tools/publish_sites.sh"}, open(out, "w"), indent=2)
PY
cp "$WORK/build.json" "$LOGS/build.json"

docs_venv() {
  [ -x "$VENV/bin/python" ] || "$DOCS_PY" -m venv "$VENV"
  "$VENV/bin/python" -m pip install --quiet --upgrade pip
  "$VENV/bin/python" -m pip install --quiet -r "$ML_WT/docs-site/requirements.txt" "anonlib==$VERSION"
  local got
  got="$("$VENV/bin/python" -I -c 'import anonlib; print(anonlib.__version__)')"
  [ "$got" = "$VERSION" ] || { echo "docs venv has anonlib $got, expected $VERSION"; return 1; }
}
step docs-venv docs_venv
step docs-build bash "$ML_WT/docs-site/tools/build.sh" "$VENV/bin/python"
cp "$WORK/build.json" "$ML_WT/docs-site/_site/build.json"
echo "   docs: $(find "$ML_WT/docs-site/_site" -type f | wc -l | tr -d ' ') files; Sphinx warnings: $(wc -l < "$ML_WT/docs-site/_build/warnings.log" | tr -d ' ') ($ML_WT/docs-site/_build/warnings.log)"
step site-build bash "$ORG_WT/tools/build.sh" "$ML_WT" "$ML_SHA" "$WORK/build.json"
grep -h -i -E 'warn' "$LOGS/site-build.log" | grep -v -i -E 'npm warn (deprecated|config)' | head -n 5 | cut -c1-240 || true

if [ "$DRY" = 1 ]; then
  echo "publish_sites: dry run done, nothing deployed. Outputs: $ML_WT/docs-site/_site and $ORG_WT/dist; record $LOGS/build.json"
  exit 0
fi

WRANGLER="$ORG_WT/node_modules/.bin/wrangler"
step deploy-docs bash -c "cd '$ML_WT/docs-site' && '$WRANGLER' deploy"
step deploy-site bash -c "cd '$ORG_WT' && '$WRANGLER' deploy"
grep -h -m 1 'Current Version ID' "$LOGS/deploy-docs.log" "$LOGS/deploy-site.log" | sed 's/^/   /' || true
echo "publish_sites: deployed anonlib $VERSION (anonlib $ML_SHA, anon.example $ORG_SHA)."
echo "   https://docs.anon.example/build.json and https://anon.example/build.json carry the record; logs: $LOGS"

#!/usr/bin/env bash
# Post-build verification for the Honcho HA add-on.
# Run from the repo root (e.g. /config/honcho-ha-addon).
# Exit code: 0 if everything checks out, non-zero on any failure.
# Catches pitfalls: secret-redactor artefacts, missing push, default branch.

set -uo pipefail

REPO="${REPO:-mliradelc/honcho-ha-addon}"
fail=0
ok()  { echo "  $*"; }
good(){ echo "✓ $*"; }
bad() { echo "✗ $*"; fail=1; }

if [ -z "${GITHUB_TOKEN:-}" ] && [ -f /config/.hermes/.env ]; then
  # shellcheck disable=SC1091
  source /config/.hermes/.env
fi

echo "=== P1: secret-redactor artefacts ==="
hits=$(grep -rn '\*\*\*' . --include='*.sh' --include='*.yaml' --include='*.tpl' --include='*.json' 2>/dev/null || true)
if [ -n "$hits" ]; then
  bad "redaction artefacts found:"
  printf '%s\n' "$hits"
else
  good "no '***' artefacts in tracked files"
fi

echo "=== P1b: run.sh shell syntax ==="
if [ -f honcho/run.sh ]; then
  if bash -n honcho/run.sh 2>/dev/null; then good "honcho/run.sh parses"; else bad "honcho/run.sh has syntax errors"; fi
fi

echo "=== YAML validity ==="
for f in honcho/config.yaml honcho/build.yaml repository.yaml \
         .github/workflows/upstream-watch.yml .github/workflows/release.yml \
         .github/dependabot.yml honcho/translations/en.yaml; do
  [ -f "$f" ] || continue
  if python3 -c "import yaml,sys; yaml.safe_load(open('$f'))" 2>/dev/null; then
    good "$f"
  else
    bad "$f failed YAML parse"
  fi
done

echo "=== P2: git state ==="
dirty=$(git status --porcelain 2>/dev/null)
if [ -n "$dirty" ]; then
  bad "uncommitted changes:"
  printf '%s\n' "$dirty"
else
  good "working tree clean"
fi

echo "=== P2b: remote has all local commits ==="
if [ -n "${GITHUB_TOKEN:-}" ]; then
  local_sha=$(git rev-parse HEAD 2>/dev/null || true)
  remote_sha=$(curl -fsS -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$REPO/commits/main" 2>/dev/null \
    | python3 -c "import json,sys; print(json.load(sys.stdin).get('sha',''))" 2>/dev/null || true)
  if [ -z "$remote_sha" ]; then
    bad "could not fetch remote HEAD for $REPO (token? repo exists?)"
  elif [ "$local_sha" = "$remote_sha" ]; then
    good "remote main == local HEAD ($local_sha)"
  else
    bad "remote main ($remote_sha) != local HEAD ($local_sha) — push missing"
  fi
else
  ok "skipped: GITHUB_TOKEN not set"
fi

echo "=== P4: default branch is main ==="
if [ -n "${GITHUB_TOKEN:-}" ]; then
  default=$(curl -fsS -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$REPO" 2>/dev/null \
    | python3 -c "import json,sys; print(json.load(sys.stdin).get('default_branch',''))" 2>/dev/null || true)
  if [ "$default" = "main" ]; then good "default_branch=main"
  else bad "default_branch=$default — run: curl -X PATCH -d '{\"default_branch\":\"main\"}'"; fi
fi

echo "=== expected files present ==="
for f in repository.yaml LICENSE README.md CHANGELOG.md .gitignore \
         honcho/config.yaml honcho/build.yaml honcho/Dockerfile honcho/run.sh \
         honcho/icon.png honcho/nginx.conf.tpl honcho/landing.html.tpl \
         honcho/translations/en.yaml honcho/.upstream-versions.json \
         .github/workflows/upstream-watch.yml .github/workflows/release.yml \
         .github/dependabot.yml; do
  if [ -e "$f" ]; then good "$f"; else bad "missing $f"; fi
done

echo "=== Dockerfile: no Hermes-specific junk ==="
if grep -q 'ttyd\|nodejs\|chromium\|Homebrew\|go1\.26\|agent-browser\|playwright' honcho/Dockerfile 2>/dev/null; then
  bad "Dockerfile still contains Hermes-specific packages"
else
  good "Dockerfile is Honcho-clean"
fi

echo "=== Dockerfile: has required deps ==="
for dep in postgresql-15 postgresql-15-pgvector redis-server nginx python3 python3-venv uv; do
  if grep -q "$dep" honcho/Dockerfile 2>/dev/null; then good "  $dep present"; else bad "  $dep missing from Dockerfile"; fi
done

echo
if [ "$fail" -eq 0 ]; then
  echo "BUILD VERIFICATION: PASS"
  exit 0
else
  echo "BUILD VERIFICATION: FAIL ($fail check(s) failed)"
  exit 1
fi
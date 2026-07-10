#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

die() { echo "ERROR: $*" >&2; exit 1; }
info() { echo "  -> $*"; }
step() { echo; echo "== $*"; }

SKIP_TESTS=false
NO_TAG=false
NEW=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-tests) SKIP_TESTS=true; shift ;;
    --no-tag) NO_TAG=true; shift ;;
    -h|--help)
      cat <<EOF
Usage: $(basename "$0") [--skip-tests] [--no-tag] <major|minor|patch|X.Y.Z>
EOF
      exit 0
      ;;
    -*) die "unknown option: $1" ;;
    *)
      [[ -z "$NEW" ]] || die "unexpected argument: $1"
      NEW="$1"
      shift
      ;;
  esac
done

[[ -n "$NEW" ]] || die "version is required"
[[ "$NEW" =~ ^(major|minor|patch|[0-9]+\.[0-9]+\.[0-9]+)$ ]] || die "version must be major|minor|patch or X.Y.Z"

OLD=$(node -p "require('./package.json').version")
[[ -n "$OLD" ]] || die "cannot read package.json version"

case "$NEW" in
  major|minor|patch)
    IFS='.' read -r MA MI PA <<< "$OLD"
    [[ "$MA" =~ ^[0-9]+$ && "$MI" =~ ^[0-9]+$ && "$PA" =~ ^[0-9]+$ ]] || die "cannot parse current version '$OLD'"
    case "$NEW" in
      major) MA=$((MA + 1)); MI=0; PA=0 ;;
      minor) MI=$((MI + 1)); PA=0 ;;
      patch) PA=$((PA + 1)) ;;
    esac
    NEW="${MA}.${MI}.${PA}"
    ;;
esac

[[ "$OLD" != "$NEW" ]] || die "already at $NEW"
info "Release: $OLD -> $NEW"

step "Pre-flight"
[[ "$(git branch --show-current)" == "main" ]] || die "must be on main"
[[ -z "$(git status --porcelain)" ]] || die "working tree dirty"
git fetch --quiet origin main
[[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] || die "branch not up to date with origin/main"

if git tag --list "v${NEW}" | grep -q .; then
  die "tag v${NEW} already exists"
fi
if git ls-remote --tags origin "v${NEW}" | grep -q "refs/tags/v${NEW}"; then
  die "tag v${NEW} already exists on origin"
fi

if [[ "$SKIP_TESTS" == false ]]; then
  npm run test
  info "templates json validation OK"
fi

step "Bump version"
npm version --no-git-tag-version "$NEW"

step "Commit + push"
git add package.json scripts/validate-templates.mjs scripts/release.sh scripts/release.ps1 .github/workflows/publish-npm.yml README.md
if git diff --cached --quiet; then
  die "nothing to commit"
fi
git commit -m "chore(release): @kitsy/gutenkit v${NEW}"
info "commit created"

git push origin main

if [[ "$NO_TAG" == false ]]; then
  git tag "v${NEW}"
  git push origin "v${NEW}"
  info "tag v${NEW} pushed"
else
  echo "Use: git tag v${NEW} && git push origin v${NEW}"
fi

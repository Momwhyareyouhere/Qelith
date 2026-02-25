#!/usr/bin/env bash
set -euo pipefail

# Public repo settings (docs + workflows + installer script)
PUBLIC_REMOTE="${PUBLIC_REMOTE:-origin}"
PUBLIC_BRANCH="${PUBLIC_BRANCH:-main}"

# Private backup repo settings (full workspace sync)
PRIVATE_REPO_URL="${PRIVATE_REPO_URL:-git@github.com:Momwhyareyouhere/flux-data.git}"
PRIVATE_BRANCH="${PRIVATE_BRANCH:-main}"

timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "publish.sh: missing command: $1" >&2
    exit 1
  }
}

for cmd in git rsync mktemp date; do
  require_cmd "$cmd"
done

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "publish.sh: run this inside a git repository" >&2
  exit 1
}

echo "[1/2] Publishing public docs/workflow/installer updates..."

# Stage only public-facing paths.
git add docs .github/workflows scripts/install-latest.sh

# Commit only these paths (if changed), without pulling in other files.
if ! git diff --quiet -- docs .github/workflows scripts/install-latest.sh || ! git diff --cached --quiet -- docs .github/workflows scripts/install-latest.sh; then
  git commit -m "Publish docs/workflow/installer update ${timestamp}" -- docs .github/workflows scripts/install-latest.sh
else
  echo "No docs/workflow/installer changes to commit."
fi

git push "$PUBLIC_REMOTE" "$PUBLIC_BRANCH"

echo "[2/2] Backing up full workspace to private repo..."

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

git clone --branch "$PRIVATE_BRANCH" "$PRIVATE_REPO_URL" "$tmpdir/backup"
rsync -a --delete --exclude ".git" ./ "$tmpdir/backup/"

(
  cd "$tmpdir/backup"
  git add -A
  if git diff --cached --quiet; then
    echo "No backup changes to push."
  else
    git commit -m "Backup sync ${timestamp}"
    git push origin "$PRIVATE_BRANCH"
  fi
)

echo "Done."
echo "Public: ${PUBLIC_REMOTE}/${PUBLIC_BRANCH}"
echo "Private backup: ${PRIVATE_REPO_URL} (${PRIVATE_BRANCH})"

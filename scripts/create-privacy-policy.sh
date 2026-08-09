#!/usr/bin/env bash
#
# create-privacy-policy.sh
#
# One-shot flow for adding a privacy policy for a new Android app:
#   1. generates "<slug>-privacy-policy.html" from the template
#   2. updates index.html (auto)
#   3. creates a branch, commits, pushes, and opens a pull request via `gh`
#
# Usage:
#   scripts/create-privacy-policy.sh "App Display Name" [app|game]
#
# Requirements:
#   - git
#   - GitHub CLI (https://cli.github.com), authenticated (gh auth login)
#   - clean working tree (untracked files are fine)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="${1:-}"
APP_TYPE="${2:-app}"

if [[ -z "$APP_NAME" ]]; then
    echo "ERROR: App name is required." >&2
    echo "Usage: $0 \"App Display Name\" [app|game]" >&2
    exit 1
fi

# ---- preflight checks -------------------------------------------------------
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "ERROR: Not inside a git repository." >&2
    exit 1
fi
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "ERROR: Working tree has uncommitted changes to tracked files." >&2
    echo "Commit or stash them first (new/untracked files are fine)." >&2
    exit 1
fi
if ! command -v gh >/dev/null 2>&1; then
    echo "ERROR: GitHub CLI (gh) is required. Install: https://cli.github.com" >&2
    exit 1
fi
if ! gh auth status >/dev/null 2>&1; then
    echo "ERROR: Not authenticated with GitHub. Run: gh auth login" >&2
    exit 1
fi

# ---- generate page + update index ------------------------------------------
bash "$SCRIPT_DIR/generate-privacy-policy.sh" "$APP_NAME" "$APP_TYPE"

# ---- branch / commit / push / PR -------------------------------------------
SLUG="$(printf '%s' "$APP_NAME" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
BRANCH="add-privacy-policy-$SLUG"

if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
    echo "ERROR: Branch '$BRANCH' already exists." >&2
    exit 1
fi

git checkout -b "$BRANCH"
git add -A
git commit -m "Add privacy policy for $APP_NAME"
git push -u origin "$BRANCH"

BODY=$(cat <<-EOF
Automated creation of the privacy policy page for **$APP_NAME**.

- Adds \`${SLUG}-privacy-policy.html\` generated from \`privacy-policy-template.html\`
- Adds a link on \`index.html\`

Generated via \`scripts/create-privacy-policy.sh\` (or the \`create-privacy-policy\` GitHub Action workflow).
EOF
)

gh pr create --title "Add privacy policy for $APP_NAME" --body "$BODY" --base main

echo ""
echo "Done: pull request opened for '$APP_NAME'."

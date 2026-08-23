#!/usr/bin/env bash
# Create scarlett-midi-control on Origin and push this project.
# Run on your Mac (not in the Cloud Agent VM): the agent session token cannot create repos.
set -euo pipefail

REPO_OWNER="${REPO_OWNER:-catkins}"
REPO_NAME="${REPO_NAME:-scarlett-midi-control}"
REMOTE_URL="https://origin.cursor.com/git/${REPO_OWNER}/${REPO_NAME}.git"

if ! command -v origin >/dev/null 2>&1; then
  echo "Install the Origin CLI: curl -fsSL https://downloads.cursor.com/origin/install.sh | sh"
  exit 1
fi

echo "Creating Origin repo ${REPO_OWNER}/${REPO_NAME}..."
origin repo create "${REPO_OWNER}/${REPO_NAME}" || origin repo view "${REPO_OWNER}/${REPO_NAME}"

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if git remote get-url origin >/dev/null 2>&1; then
    git remote set-url origin "${REMOTE_URL}"
  else
    git remote add origin "${REMOTE_URL}"
  fi
  git push -u origin main
else
  echo "Not inside a git repo. Clone and push manually:"
  echo "  origin repo clone ${REPO_OWNER}/${REPO_NAME}"
  echo "  # copy files, commit, git push -u origin main"
fi

echo "Done: https://origin.cursor.com/${REPO_OWNER}/${REPO_NAME}"

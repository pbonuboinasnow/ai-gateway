#!/usr/bin/env bash
# Copyright Envoy AI Gateway Authors
# SPDX-License-Identifier: Apache-2.0
# The full text of the Apache license is available in the LICENSE file at
# the root of the repo.

set -euo pipefail

BRANCHES=(
  "origin/main"
  "bannu8615/scratch/aws-signing"
)

TAG="${TAG:-sn-20260724-01}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
cd "$PROJECT_DIR"

current_branch=$(git branch --show-current)
if [[ "$current_branch" != "feature/sn-custom-changes" ]]; then
  echo "ERROR: Expected to be on branch 'feature/sn-custom-changes', but on '$current_branch'"
  exit 1
fi

echo "==> Fetching latest from upstream (origin), fork, and bannu8615..."
git fetch origin main
git fetch fork
git fetch bannu8615

merged=0
for branch in "${BRANCHES[@]}"; do
  local_head=$(git rev-parse HEAD)
  branch_head=$(git rev-parse "$branch" 2>/dev/null || true)

  if [[ -z "$branch_head" ]]; then
    echo "  SKIP: $branch (not found)"
    continue
  fi

  # Check if branch is already fully merged
  if git merge-base --is-ancestor "$branch" HEAD 2>/dev/null; then
    echo "  UP-TO-DATE: $branch"
  else
    echo "  MERGING: $branch..."
    if git merge "$branch" --no-edit; then
      echo "  MERGED: $branch"
      merged=1
    else
      echo "ERROR: Merge conflict with $branch. Resolve manually, then re-run."
      exit 1
    fi
  fi
done

if [[ "$merged" -eq 0 ]]; then
  echo ""
  echo "==> No new changes to merge."
else
  echo ""
  echo "==> Pushing feature/sn-custom-changes to fork..."
  git push fork feature/sn-custom-changes
  echo "==> Pushed."
fi

if [[ "${BUILD:-true}" == "true" ]]; then
  if [[ "$merged" -eq 0 ]]; then
    read -rp "Build images anyway? [y/N] " answer
    if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
      echo "Skipping build."
      exit 0
    fi
  fi

  echo ""
  echo "==> Building images with TAG=$TAG..."
  make docker-build.controller docker-build.extproc docker-build.aigw \
    DOCKER_BUILD_ARGS="--load" TAG="$TAG"

  echo ""
  echo "==> Done. Images tagged as $TAG:"
  docker images | grep "ai-gateway" | grep "$TAG"
fi

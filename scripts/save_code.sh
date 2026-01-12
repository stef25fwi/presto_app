#!/usr/bin/env bash
set -euo pipefail

MSG="${1:-feat: update}"

echo "==> Status"
git status -sb

echo "==> Add (interactive) lib/"
git add -p lib

# Si tu veux inclure functions aussi, décommente la ligne suivante :
# git add -p functions

echo "==> Commit"
git commit -m "$MSG" || { echo "Nothing to commit."; exit 0; }

echo "==> Push"
git push -u origin HEAD

#!/usr/bin/env bash
set -euo pipefail

BASE_HREF="/presto_app/"
DOCS_DIR="docs"

echo "==> Check branch"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [ "$BRANCH" != "main" ]; then
  echo "❌ Tu n'es pas sur main ($BRANCH). Stop."
  exit 1
fi

echo "==> Flutter build web (release)"
flutter pub get
flutter build web --release --base-href "$BASE_HREF"

echo "==> Prepare docs/"
mkdir -p "$DOCS_DIR"
touch "$DOCS_DIR/.nojekyll"

echo "==> Sync build/web -> docs/ (no rsync)"
# Nettoyage (garde .git, .nojekyll, éventuellement CNAME si tu en as un)
find "$DOCS_DIR" -mindepth 1 -maxdepth 1 \
  ! -name ".git" \
  ! -name ".nojekyll" \
  ! -name "CNAME" \
  -exec rm -rf {} +

# Copie du build vers docs
cp -a build/web/. "$DOCS_DIR/"

echo "==> Detect changes in docs/"
if git diff --quiet -- "$DOCS_DIR"; then
  echo "✅ Rien à déployer : docs/ inchangé."
  exit 0
fi

echo "==> Commit + push docs/"
git add "$DOCS_DIR"
git commit -m "deploy: update GitHub Pages (docs)"
git push origin main

echo "✅ Déploiement envoyé (main/docs)."

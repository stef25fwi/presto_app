#!/usr/bin/env bash
set -euo pipefail

BASE_HREF="/presto_app/"
DOCS_DIR="docs"

echo "==> Check branch"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [ "$BRANCH" != "main" ]; then
  echo "⚠️ Tu n'es pas sur main ($BRANCH)."
  echo "   Merge ta branche vers main, puis relance (sinon tu déploies depuis la mauvaise branche)."
fi

echo "==> Flutter build web (release)"
flutter pub get
flutter build web --release --base-href "$BASE_HREF"

echo "==> Prepare docs/"
mkdir -p "$DOCS_DIR"
touch "$DOCS_DIR/.nojekyll"

echo "==> Sync build/web -> docs/"
# rsync: miroir exact (supprime les anciens fichiers)
rsync -a --delete build/web/ "$DOCS_DIR/"

echo "==> Detect changes in docs/"
if git diff --quiet -- "$DOCS_DIR"; then
  echo "✅ Rien à déployer : docs/ inchangé."
  exit 0
fi

echo "==> Commit + push docs/"
git add "$DOCS_DIR"
git commit -m "deploy: update GitHub Pages (docs)"
git push origin main

echo "✅ Déploiement envoyé. (GitHub Pages se met à jour depuis docs/ sur main)"

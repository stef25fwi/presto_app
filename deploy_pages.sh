#!/usr/bin/env bash
set -euo pipefail

BRANCH="main"
PAGES_DIR="docs"
BASE_HREF="/presto_app/"

# Refuse de continuer si tu as des modifs non commit (évite les décalages)
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "❌ Working tree sale. Commit ou stash avant de déployer."
  git status --porcelain
  exit 1
fi

echo "==> Checkout & update $BRANCH"
git checkout "$BRANCH"
git pull --rebase origin "$BRANCH"

echo "==> Flutter build web (base-href: $BASE_HREF)"
flutter clean
flutter pub get
flutter build web --release --base-href "$BASE_HREF"

echo "==> Sync build/web -> $PAGES_DIR/"
mkdir -p "$PAGES_DIR"
rsync -a --delete build/web/ "$PAGES_DIR"/
touch "$PAGES_DIR/.nojekyll"

echo "==> Commit docs/ only (if changed)"
git add "$PAGES_DIR"
git commit -m "Deploy web to GitHub Pages" || echo "No docs/ changes -> nothing to deploy."

echo "==> Push"
git push origin "$BRANCH"

echo "✅ Done. Pages will update only if docs/ changed."

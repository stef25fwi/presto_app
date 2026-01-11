#!/usr/bin/env bash
set -euo pipefail

# --- CONFIG ---
BRANCH="main"
PAGES_DIR="docs"
BASE_HREF="/presto_app/"

echo "==> Checkout & update $BRANCH"
git checkout "$BRANCH"
git pull --rebase

echo "==> Flutter build web (base-href: $BASE_HREF)"
flutter clean
flutter pub get
flutter build web --release --base-href "$BASE_HREF"

echo "==> Publish build/web -> $PAGES_DIR/"
rm -rf "$PAGES_DIR"
mkdir -p "$PAGES_DIR"
cp -R build/web/* "$PAGES_DIR"/

# Désactive Jekyll (évite des surprises avec des dossiers commençant par _)
touch "$PAGES_DIR/.nojekyll"

# Optionnel: petit fichier de version pour vérifier ce qui est en prod
date -u +"%Y-%m-%dT%H:%M:%SZ" > "$PAGES_DIR/version.txt"
echo "$(git rev-parse --short HEAD)" >> "$PAGES_DIR/version.txt"

echo "==> Commit & push"
git add -A
git commit -m "deploy(pages): $(date -u +'%Y-%m-%dT%H:%MZ')" || true
git push origin "$BRANCH"

echo "✅ Done. URL: https://stef25fwi.github.io/presto_app/"

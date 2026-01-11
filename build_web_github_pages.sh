#!/bin/bash
set -euo pipefail

# Build Flutter Web pour GitHub Pages (https://stef25fwi.github.io/presto_app/)
# IMPORTANT: base-href doit matcher le sous-répertoire /presto_app/

cd "$(dirname "$0")"

# Précondition: Flutter doit être disponible
if ! command -v flutter >/dev/null 2>&1; then
        echo "❌ Flutter n'est pas installé ou introuvable dans le PATH." >&2
        echo "   Installe Flutter SDK puis relancez ce script." >&2
        echo "   Doc: https://docs.flutter.dev/get-started/install" >&2
        exit 127
fi

echo "🏗️  Build Flutter Web (GitHub Pages) avec --base-href /presto_app/ ..."
flutter --version || true
flutter pub get

SHA="$(git rev-parse --short HEAD 2>/dev/null || echo local)"
BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')"
BUILD_TIME_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

echo "ℹ️  Defines: APP_BUILD_SHA=$SHA APP_BUILD_BRANCH=$BRANCH APP_BUILD_TIME=$BUILD_TIME_UTC"

flutter build web --release --base-href "/presto_app/" \
        --dart-define=APP_BUILD_SHA="$SHA" \
        --dart-define=APP_BUILD_BRANCH="$BRANCH" \
        --dart-define=APP_BUILD_TIME="$BUILD_TIME_UTC"

# Note: Flutter remplace automatiquement $FLUTTER_BASE_HREF par la valeur de --base-href
# Pas besoin de sed supplémentaire

# Préparer la sortie pour GitHub Pages
# - docs/ est le dossier publié via Settings → Pages → Source: GitHub Actions ou main/docs
# - .nojekyll évite le processing Jekyll qui peut casser les assets Flutter
# - 404.html copie de index.html pour fallback SPA sur GH Pages

echo "🧩 Sync build/web -> docs/ (sans supprimer les fichiers custom éventuels)"
mkdir -p docs
cp -a build/web/. docs/

touch docs/.nojekyll
if [[ -f docs/index.html ]]; then
  cp -f docs/index.html docs/404.html
fi

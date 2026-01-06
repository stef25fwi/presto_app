#!/bin/bash
set -euo pipefail

# Build Flutter Web pour GitHub Pages (https://stef25fwi.github.io/presto_app/)
# IMPORTANT: base-href doit matcher le sous-répertoire /presto_app/

cd "$(dirname "$0")"

echo "🏗️  Build Flutter Web (GitHub Pages) avec --base-href /presto_app/ ..."
flutter pub get
flutter build web --release --base-href "/presto_app/"

echo "🧩 Sync build/web -> docs/ (sans supprimer les fichiers custom éventuels)"
mkdir -p docs
cp -a build/web/. docs/

echo "✅ OK: artefacts GH Pages prêts dans ./docs"

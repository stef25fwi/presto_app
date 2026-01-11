#!/bin/bash
set -euo pipefail

# Simple script de synchronisation build/web -> docs/
# Sans utiliser les commandes shell complexes

cd "$(dirname "$0")"

echo "🧹 Nettoyage de docs/ ..."
rm -rf docs/*

echo "📂 Création de docs/ ..."
mkdir -p docs

echo "📋 Copie des fichiers racine..."
cp build/web/index.html docs/
cp build/web/.last_build_id docs/
cp build/web/flutter.js docs/
cp build/web/flutter_bootstrap.js docs/
cp build/web/flutter_service_worker.js docs/
cp build/web/manifest.json docs/
cp build/web/version.json docs/
cp build/web/favicon.png docs/

echo "📁 Copie des répertoires..."
cp -r build/web/assets docs/ || true
cp -r build/web/canvaskit docs/ || true
cp -r build/web/icons docs/ || true

echo "⚠️  Copie du fichier JavaScript volumineux main.dart.js ..."
cp build/web/main.dart.js docs/

echo "🔧 Configuration pour GitHub Pages..."
touch docs/.nojekyll
if [[ -f docs/index.html ]]; then
  cp docs/index.html docs/404.html
  echo "✅ 404.html créé pour SPA"
fi

echo ""
echo "✅ Synchronisation terminée!"
echo "📊 Fichiers dans docs/:"
ls -lh docs/ | grep -v "^total" | tail -20

#!/bin/bash
set -e

cd /workspaces/presto_app

echo "📝 Préparation du commit..."
git add docs/

echo "📌 Création du commit..."
git commit -m "fix: Synchronise build/web -> docs/ pour GitHub Pages (main.dart.js inclus)"

echo "🚀 Poussage vers GitHub..."
git push origin main

echo ""
echo "✅ Succès! Les fichiers ont été poussés vers GitHub."
echo "   La page https://stef25fwi.github.io/presto_app/ devrait se mettre à jour dans ~1 min"

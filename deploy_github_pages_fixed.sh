#!/bin/bash
set -euo pipefail

# Script de déploiement GitHub Pages
# 1. Nettoie docs/
# 2. Copie build/web vers docs/
# 3. Crée .nojekyll et 404.html
# 4. Pousse vers main

cd "$(dirname "$0")"

echo "🔄 Synchronisation build/web -> docs/ pour GitHub Pages"

# Étape 1: Nettoyer et recréer docs/
echo "🧹 Nettoyage de docs/..."
rm -rf docs
mkdir -p docs

# Étape 2: Copier les fichiers
echo "📋 Copie des fichiers..."
cp -r build/web/* docs/

# Étape 3: Configuration GitHub Pages
echo "⚙️  Configuration GitHub Pages..."
touch docs/.nojekyll
[ -f docs/index.html ] && cp docs/index.html docs/404.html

# Étape 4: Git commit et push
echo "📤 Git commit et push..."
git add docs/ .nojekyll .github/workflows/deploy.yml
git commit -m "🚀 Deploy: Sync build/web to docs/ with base-href /presto_app/" || echo "⏭️  Rien à committer"
git push origin main

echo ""
echo "✅ Déploiement terminé!"
echo "📊 Fichiers déployés dans docs/:"
ls -1 docs/ | grep -E '\.js$|\.html$|\.json$' | head -10

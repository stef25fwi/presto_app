#!/bin/bash

set -e

echo "════════════════════════════════════════════════════════════"
echo "🚀 DÉPLOIEMENT PRESTO - Comment ça marche"
echo "════════════════════════════════════════════════════════════"
echo ""

# Build Flutter Web
echo "📦 Build Flutter Web..."
flutter build web --release

if [ $? -eq 0 ]; then
  echo "✅ Build réussi"
else
  echo "❌ Build échoué"
  exit 1
fi

echo ""
echo "🔥 Déploiement Firebase Hosting..."
firebase deploy --only hosting

if [ $? -eq 0 ]; then
  echo "✅ Déploiement Firebase réussi"
else
  echo "❌ Déploiement échoué"
  exit 1
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo "✅ DÉPLOIEMENT TERMINÉ"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "🔗 App: https://presto-app-74abe.web.app"
echo "📄 Changelog: Mise à jour section 'Comment ça marche' (3 étapes)"
echo ""

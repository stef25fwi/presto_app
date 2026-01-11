#!/bin/bash

echo "🔧 FIX: Rebuild avec le bon base-href pour Firebase Hosting"
echo "════════════════════════════════════════════════════════════"
echo ""

echo "Problème détecté:"
echo "  ❌ base href=\"/presto_app/\" dans build/web/index.html"
echo "  ✅ Besoin de base href=\"/\" pour Firebase Hosting"
echo ""

cd /workspaces/presto_app

echo "📦 Nettoyage..."
flutter clean

echo ""
echo "📥 Récupération des dépendances..."
flutter pub get

echo ""
echo "🏗️  Build avec base-href correct..."
flutter build web --release --base-href="/"

if [ $? -eq 0 ]; then
  echo ""
  echo "✅ Build réussi!"
  echo ""
  echo "🔥 Redéploiement Firebase..."
  firebase deploy --only hosting
  
  if [ $? -eq 0 ]; then
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo "✅ DÉPLOIEMENT CORRIGÉ"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    echo "🌐 Vérifier: https://presto-app-74abe.web.app"
    echo ""
  else
    echo "❌ Erreur déploiement"
    exit 1
  fi
else
  echo "❌ Erreur build"
  exit 1
fi

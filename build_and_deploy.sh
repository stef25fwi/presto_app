#!/bin/bash

echo "🔧 Fix et Build Presto App"
echo "════════════════════════════════════════════════════════════"

cd /workspaces/presto_app

echo ""
echo "1️⃣ Nettoyage..."
flutter clean

echo ""
echo "2️⃣ Mise à jour des dépendances..."
flutter pub get

if [ $? -ne 0 ]; then
  echo ""
  echo "❌ Erreur lors de flutter pub get"
  echo "Tentative d'upgrade automatique..."
  flutter pub upgrade --major-versions
  flutter pub get
fi

echo ""
echo "3️⃣ Build web avec base-href correct..."
flutter build web --release --base-href="/"

if [ $? -eq 0 ]; then
  echo ""
  echo "✅ Build réussi!"
  echo ""
  echo "📁 Vérification du build:"
  ls -lh build/web/ | head -10
  
  echo ""
  echo "🔍 Vérification base href:"
  cat build/web/index.html | grep "base href"
  
  echo ""
  echo "4️⃣ Déploiement Firebase Hosting..."
  firebase deploy --only hosting
  
  if [ $? -eq 0 ]; then
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo "✅ DÉPLOIEMENT RÉUSSI"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    echo "🌐 App: https://presto-app-74abe.web.app"
    echo "📊 Console: https://console.firebase.google.com/project/presto-app-74abe"
    echo ""
  else
    echo ""
    echo "❌ Erreur lors du déploiement Firebase"
    exit 1
  fi
else
  echo ""
  echo "❌ Erreur lors du build Flutter"
  echo ""
  echo "Essayez manuellement:"
  echo "  flutter clean"
  echo "  flutter pub upgrade --major-versions"
  echo "  flutter pub get"
  echo "  flutter build web --release --base-href='/'"
  exit 1
fi

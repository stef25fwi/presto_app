#!/bin/bash

echo "🚀 DÉPLOIEMENT COMPLET - PRESTO APP"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "📦 Mises à jour incluses:"
echo "   • Correction page 'Je consulte les offres'"
echo "   • Système de gestion des splashscreens"
echo "   • Règles Firestore mises à jour"
echo ""
echo "════════════════════════════════════════════════════════════"

cd /workspaces/presto_app

# 1. Nettoyage
echo ""
echo "1️⃣ Nettoyage..."
flutter clean

# 2. Dépendances
echo ""
echo "2️⃣ Mise à jour des dépendances..."
flutter pub get

if [ $? -ne 0 ]; then
  echo "⚠️  Erreur pub get, tentative d'upgrade..."
  flutter pub upgrade --major-versions
  flutter pub get
fi

# 3. Build web
echo ""
echo "3️⃣ Build web (release)..."
flutter build web --release --base-href="/"

if [ $? -ne 0 ]; then
  echo ""
  echo "❌ Erreur lors du build"
  exit 1
fi

echo ""
echo "✅ Build réussi!"
echo ""
echo "📁 Contenu du build:"
ls -lh build/web/ | head -10

# 4. Déploiement Firebase
echo ""
echo "════════════════════════════════════════════════════════════"
echo "4️⃣ Déploiement Firebase..."
echo "════════════════════════════════════════════════════════════"

# 4.1 Hosting
echo ""
echo "📱 Déploiement Hosting..."
firebase deploy --only hosting

if [ $? -ne 0 ]; then
  echo "❌ Erreur déploiement hosting"
  exit 1
fi

# 4.2 Firestore Rules (si pas déjà fait)
echo ""
echo "🔒 Déploiement Règles Firestore..."
firebase deploy --only firestore:rules

# 4.3 Firestore Indexes (optionnel)
echo ""
echo "📊 Déploiement Index Firestore..."
firebase deploy --only firestore:indexes

echo ""
echo "════════════════════════════════════════════════════════════"
echo "✅ DÉPLOIEMENT TERMINÉ"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "🌐 Application: https://presto-app-74abe.web.app"
echo "📊 Console: https://console.firebase.google.com/project/presto-app-74abe"
echo ""
echo "🧪 Tests recommandés:"
echo "   • Ouvrir l'app web"
echo "   • Tester 'Je consulte les offres'"
echo "   • Admin → Splashscreen management"
echo ""
echo "📝 N'oublie pas de créer le document Firestore:"
echo "   Collection: config"
echo "   Document: splashscreen"
echo "   Champs: { active: 'v1', updatedAt: [Timestamp] }"
echo ""

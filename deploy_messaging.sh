#!/bin/bash
set -euo pipefail

echo "🚀 Déploiement Presto App avec nouvelles fonctionnalités de messagerie"
echo "=========================================================================="

# Vérification Flutter
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter non trouvé. Veuillez l'installer."
    exit 1
fi

# Vérification Firebase CLI
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI non trouvé. Veuillez l'installer."
    exit 1
fi

echo ""
echo "📊 Analyse du code..."
flutter analyze
if [ $? -ne 0 ]; then
    echo "⚠️  Des avertissements ont été détectés, mais on continue..."
fi

echo ""
echo "🧹 Nettoyage des builds précédents..."
flutter clean

echo ""
echo "📦 Installation des dépendances..."
flutter pub get

echo ""
echo "🔨 Build Flutter Web (mode release)..."
flutter build web --release --no-tree-shake-icons

# Vérification que le build existe
if [ ! -d "build/web" ]; then
    echo "❌ Le dossier build/web n'existe pas. Build échoué."
    exit 1
fi

if [ ! -f "build/web/index.html" ]; then
    echo "❌ index.html non trouvé dans build/web. Build échoué."
    exit 1
fi

echo ""
echo "✅ Build réussi !"
echo "📁 Taille du build:"
du -sh build/web

echo ""
echo "🚀 Déploiement sur Firebase Hosting..."
firebase deploy --only hosting

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ =========================================="
    echo "✅ DÉPLOIEMENT RÉUSSI !"
    echo "✅ =========================================="
    echo ""
    echo "🌐 URL de l'application:"
    echo "   https://presto-app-74abe.web.app/"
    echo "   https://presto-app-74abe.firebaseapp.com/"
    echo ""
    echo "📱 Nouvelles fonctionnalités déployées:"
    echo "   ✅ Système de messagerie Firebase temps réel"
    echo "   ✅ Envoi/réception de messages instantanés"
    echo "   ✅ Compteur de messages non lus"
    echo "   ✅ Conversations en temps réel"
    echo "   ✅ Archivage et signalement"
    echo ""
    echo "💡 Conseil: Videz le cache de votre navigateur (Ctrl+Shift+R)"
    echo "            ou désactivez le service worker pour voir les changements."
else
    echo ""
    echo "❌ Échec du déploiement Firebase."
    exit 1
fi

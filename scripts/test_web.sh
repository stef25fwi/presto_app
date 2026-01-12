#!/bin/bash
set -e

echo "🌐 Lancement de l'app Flutter sur le web..."
echo ""
echo "Configuration:"
echo "- Plateforme: Web"
echo "- Port: 5000"
echo ""

cd /workspaces/presto_app

# Vérifier les dépendances
echo "✅ Vérification des dépendances..."
flutter pub get

# Lancer en mode debug sur le web
echo "🚀 Lancement du serveur web..."
flutter run -d web-server --dart-define=FLUTTER_WEB_AUTO_OPEN=false

echo ""
echo "✅ Serveur web démarré"
echo "Ouvrez: http://localhost:5000"

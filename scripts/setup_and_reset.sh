#!/bin/bash

# Script pour guider le téléchargement du service account et exécuter reset_annonces.js

set -euo pipefail

PROJECT_ID="presto-app-74abe"
SERVICE_ACCOUNT_PATH="/workspaces/presto_app/functions/serviceAccount.json"

echo "🔐 Configuration du Service Account Firebase"
echo "==========================================="
echo ""
echo "📋 ÉTAPES À SUIVRE :"
echo ""
echo "1. Je vais ouvrir Firebase Console dans ton navigateur"
echo "2. Clique sur l'onglet 'Service Accounts'"
echo "3. Clique sur 'Generate new private key'"
echo "4. Confirme en cliquant 'Generate key'"
echo "5. Le fichier JSON sera téléchargé"
echo "6. Renomme-le en 'serviceAccount.json'"
echo "7. Place-le dans: /workspaces/presto_app/functions/"
echo ""
read -p "Prêt ? (Appuie sur Entrée pour ouvrir Firebase Console)" 

# Ouvrir Firebase Console dans le navigateur
URL="https://console.firebase.google.com/project/$PROJECT_ID/settings/serviceaccounts/adminsdk"

if command -v xdg-open &> /dev/null; then
  xdg-open "$URL" 2>/dev/null || true
elif [ -n "${BROWSER:-}" ]; then
  "$BROWSER" "$URL" 2>/dev/null || true
else
  echo "📎 Ouvre cette URL dans ton navigateur:"
  echo "   $URL"
fi

echo ""
echo "⏳ En attente du fichier serviceAccount.json..."
echo "   (Place-le dans: /workspaces/presto_app/functions/serviceAccount.json)"
echo ""
echo "   Appuie sur Entrée quand c'est fait..."
read

# Vérifier que le fichier existe
if [ ! -f "$SERVICE_ACCOUNT_PATH" ]; then
  echo "❌ Fichier serviceAccount.json introuvable dans:"
  echo "   $SERVICE_ACCOUNT_PATH"
  echo ""
  echo "Place-le au bon endroit et relance ce script."
  exit 1
fi

echo "✅ Service account trouvé !"
echo ""

# Configurer les variables d'environnement
export FIREBASE_PROJECT_ID="$PROJECT_ID"
export GOOGLE_APPLICATION_CREDENTIALS="$SERVICE_ACCOUNT_PATH"

echo "🚀 Lancement du script reset_annonces.js..."
echo ""

cd /workspaces/presto_app
node scripts/reset_annonces.js

echo ""
echo "✨ Terminé !"

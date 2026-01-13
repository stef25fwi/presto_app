#!/bin/bash

# Guide pour télécharger manuellement le service account

PROJECT_ID="presto-app-74abe"
SERVICE_ACCOUNT_PATH="/workspaces/presto_app/functions/serviceAccount.json"

echo "📋 GUIDE: Télécharger le Service Account Firebase"
echo "=================================================="
echo ""
echo "📖 Suis ces étapes:"
echo ""
echo "1️⃣  Ouvre cette URL dans ton navigateur:"
echo ""
echo "    https://console.firebase.google.com/project/$PROJECT_ID/settings/serviceaccounts/adminsdk"
echo ""

# Ouvrir l'URL automatiquement
if command -v xdg-open &> /dev/null; then
  xdg-open "https://console.firebase.google.com/project/$PROJECT_ID/settings/serviceaccounts/adminsdk" 2>/dev/null &
elif [ -n "$BROWSER" ]; then
  "$BROWSER" "https://console.firebase.google.com/project/$PROJECT_ID/settings/serviceaccounts/adminsdk" 2>/dev/null &
fi

echo "2️⃣  Clique sur le bouton 'Generate new private key' (en bas)"
echo ""
echo "3️⃣  Confirme en cliquant 'Generate key'"
echo ""
echo "4️⃣  Un fichier JSON sera téléchargé (ex: presto-app-74abe-firebase-adminsdk-xxxxx.json)"
echo ""
echo "5️⃣  Copie le contenu du fichier téléchargé"
echo ""
echo "6️⃣  Dans VS Code, ouvre: functions/serviceAccount.json"
echo ""
echo "7️⃣  Colle le contenu JSON dedans et sauvegarde"
echo ""
echo ""
read -p "Appuie sur ENTRÉE quand c'est fait..." 

# Vérifier si le fichier existe
if [ -f "$SERVICE_ACCOUNT_PATH" ]; then
  # Vérifier que c'est du JSON valide
  if grep -q "private_key" "$SERVICE_ACCOUNT_PATH" 2>/dev/null; then
    echo ""
    echo "✅ Service Account détecté !"
    echo ""
    echo "🚀 Lancement du reset des annonces..."
    echo ""
    
    export FIREBASE_PROJECT_ID=$PROJECT_ID
    export GOOGLE_APPLICATION_CREDENTIALS=$SERVICE_ACCOUNT_PATH
    
    node scripts/reset_annonces.js
  else
    echo ""
    echo "⚠️  Le fichier existe mais ne semble pas valide"
    echo "   Vérifie que tu as bien copié tout le contenu JSON"
    exit 1
  fi
else
  echo ""
  echo "❌ Fichier non trouvé: $SERVICE_ACCOUNT_PATH"
  echo ""
  echo "   Crée le fichier et colle le JSON dedans,"
  echo "   puis relance: bash scripts/download_service_account.sh"
  exit 1
fi

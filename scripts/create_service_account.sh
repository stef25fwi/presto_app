#!/bin/bash

# Créer automatiquement un service account Firebase Admin SDK via Firebase CLI

set -euo pipefail

PROJECT_ID="presto-app-74abe"
SERVICE_ACCOUNT_NAME="firebase-adminsdk-script"
SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
SERVICE_ACCOUNT_PATH="/workspaces/presto_app/functions/serviceAccount.json"

echo "🔐 Création du Service Account Firebase Admin SDK"
echo "================================================="
echo ""
echo "Projet: $PROJECT_ID"
echo "Service Account: $SERVICE_ACCOUNT_EMAIL"
echo ""

# Vérifier Firebase CLI
if ! command -v firebase &> /dev/null; then
  echo "❌ Firebase CLI n'est pas installé"
  echo ""
  echo "📋 MÉTHODE MANUELLE :"
  echo "   1. Va sur: https://console.firebase.google.com/project/$PROJECT_ID/settings/serviceaccounts/adminsdk"
  echo "   2. Clique sur 'Generate new private key'"
  echo "   3. Télécharge et renomme en 'serviceAccount.json'"
  echo "   4. Place dans: /workspaces/presto_app/functions/"
  exit 1
fi

echo "✅ Firebase CLI trouvé"
echo ""

# Obtenir le token d'accès via Firebase CLI
echo "🔑 Obtention du token d'accès..."
ACCESS_TOKEN=$(firebase login:ci --no-localhost 2>/dev/null || firebase --token "$(cat ~/.config/configstore/firebase-tools.json 2>/dev/null | grep -oP '(?<="tokens":{"access_token":")[^"]*')" projects:list --format=json >/dev/null 2>&1 && cat ~/.config/configstore/firebase-tools.json | grep -oP '(?<="tokens":{"access_token":")[^"]*' || echo "")

if [ -z "$ACCESS_TOKEN" ]; then
  echo "⚠️  Impossible d'obtenir le token automatiquement"
  echo ""
  echo "🔑 Méthode alternative: utiliser gcloud"
  
  if command -v gcloud &> /dev/null; then
    echo "   Authentifie-toi avec: gcloud auth login"
    echo "   Puis relance ce script"
  else
    echo ""
    echo "📋 MÉTHODE MANUELLE (RECOMMANDÉE) :"
    echo ""
    echo "   1. Ouvre: https://console.firebase.google.com/project/$PROJECT_ID/settings/serviceaccounts/adminsdk"
    echo ""
    echo "   2. Clique sur 'Generate new private key' (bouton bleu)"
    echo ""
    echo "   3. Télécharge le fichier JSON"
    echo ""
    echo "   4. Place-le dans:"
    echo "      $SERVICE_ACCOUNT_PATH"
    echo ""
    echo "   5. Lance: bash scripts/setup_and_reset.sh"
  fi
  exit 1
fi

echo "✅ Token obtenu"
echo ""

# Créer le service account via API REST
echo "📝 Création du service account..."

RESPONSE=$(curl -s -X POST \
  "https://iam.googleapis.com/v1/projects/$PROJECT_ID/serviceAccounts" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"accountId\": \"$SERVICE_ACCOUNT_NAME\",
    \"serviceAccount\": {
      \"displayName\": \"Firebase Admin SDK (Script)\",
      \"description\": \"Service account pour scripts admin Firebase\"
    }
  }")

if echo "$RESPONSE" | grep -q "error"; then
  if echo "$RESPONSE" | grep -q "already exists"; then
    echo "⚠️  Service account existe déjà"
  else
    echo "❌ Erreur lors de la création:"
    echo "$RESPONSE" | grep -oP '(?<="message":")[^"]*'
    echo ""
    echo "📋 Utilise la méthode manuelle (Console Firebase)"
    exit 1
  fi
else
  echo "✅ Service account créé"
fi

echo ""

# Attribuer les permissions
echo "🔐 Attribution des permissions..."

# Role Firebase Admin
curl -s -X POST \
  "https://cloudresourcemanager.googleapis.com/v1/projects/$PROJECT_ID:setIamPolicy" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"policy\": {
      \"bindings\": [
        {
          \"role\": \"roles/firebase.admin\",
          \"members\": [\"serviceAccount:$SERVICE_ACCOUNT_EMAIL\"]
        },
        {
          \"role\": \"roles/datastore.user\",
          \"members\": [\"serviceAccount:$SERVICE_ACCOUNT_EMAIL\"]
        }
      ]
    }
  }" > /dev/null

echo "✅ Permissions attribuées"
echo ""

# Générer la clé
echo "🔑 Génération de la clé privée..."

rm -f "$SERVICE_ACCOUNT_PATH"

KEY_RESPONSE=$(curl -s -X POST \
  "https://iam.googleapis.com/v1/projects/$PROJECT_ID/serviceAccounts/$SERVICE_ACCOUNT_EMAIL/keys" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}')

if echo "$KEY_RESPONSE" | grep -q "privateKeyData"; then
  echo "$KEY_RESPONSE" | grep -oP '(?<="privateKeyData":")[^"]*' | base64 -d > "$SERVICE_ACCOUNT_PATH"
  echo "✅ Clé générée: $SERVICE_ACCOUNT_PATH"
else
  echo "❌ Erreur lors de la génération de la clé"
  echo ""
  echo "📋 MÉTHODE MANUELLE :"
  echo "   1. Va sur: https://console.firebase.google.com/project/$PROJECT_ID/settings/serviceaccounts/adminsdk"
  echo "   2. Clique sur 'Generate new private key'"
  echo "   3. Place le fichier dans: $SERVICE_ACCOUNT_PATH"
  exit 1
fi

echo ""

# Vérifier le fichier
if [ ! -f "$SERVICE_ACCOUNT_PATH" ]; then
  echo "❌ Erreur: fichier non créé"
  exit 1
fi

echo "✅ Service Account configuré avec succès !"
echo ""
echo "📁 Fichier créé: $SERVICE_ACCOUNT_PATH"
echo ""
echo "🚀 Lancement automatique du reset des annonces..."
echo ""

export FIREBASE_PROJECT_ID=$PROJECT_ID
export GOOGLE_APPLICATION_CREDENTIALS=$SERVICE_ACCOUNT_PATH

node scripts/reset_annonces.js

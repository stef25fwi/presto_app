#!/bin/bash

# Déployer et exécuter la Cloud Function pour activer les offres

set -euo pipefail

PROJECT_ID="presto-app-74abe"
FUNCTION_NAME="activateAllOffers"
REGION="europe-west1"

echo "🚀 Déploiement de la Cloud Function..."
echo "   Projet: $PROJECT_ID"
echo "   Fonction: $FUNCTION_NAME"
echo "   Région: $REGION"
echo ""

# Vérifier firebase CLI
if ! command -v firebase &> /dev/null; then
  echo "❌ firebase-tools n'est pas installé"
  echo "   Installe avec: npm install -g firebase-tools"
  exit 1
fi

# Vérifier connexion
echo "✅ Vérification de la connexion..."
firebase projects:list > /dev/null 2>&1 || {
  echo "❌ Non connecté. Lance: firebase login"
  exit 1
}

echo "✅ Connecté"
echo ""

# Déployer
echo "📦 Déploiement..."
cd functions
npm run deploy 2>&1 | head -20

cd ..

echo ""
echo "✅ Déploiement terminé"
echo ""
echo "📍 URL de la fonction:"
FUNCTION_URL="https://$REGION-$PROJECT_ID.cloudfunctions.net/$FUNCTION_NAME"
echo "   $FUNCTION_URL"
echo ""

echo "🔧 Exécution..."
RESPONSE=$(curl -s -X POST "$FUNCTION_URL")

echo ""
echo "📊 Résultat:"
echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"

echo ""
echo "✨ Terminé"
echo ""
echo "🎉 Les offres sont maintenant actives!"
echo "   Va sur l'app → 'Je consulte les offres' → les annonces s'affichent"

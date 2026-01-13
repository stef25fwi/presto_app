#!/bin/bash

# Corriger toutes les offres : ajouter isActive: true

set -euo pipefail

PROJECT_ID="presto-app-74abe"
COLLECTION="offers"

echo "🔧 Activation des annonces dans Firestore..."
echo "   Projet: $PROJECT_ID"
echo "   Collection: $COLLECTION"
echo ""

# Vérifier firebase CLI
if ! command -v firebase &> /dev/null; then
  echo "❌ firebase-tools n'est pas installé"
  echo "   Installe avec: npm install -g firebase-tools"
  exit 1
fi

# Vérifier connexion
echo "✅ Vérification de la connexion Firebase..."
firebase projects:list > /dev/null 2>&1 || {
  echo "❌ Non connecté. Lance: firebase login"
  exit 1
}

echo "✅ Connecté"
echo ""

# Récupérer l'ID du token
echo "🔑 Récupération du token d'accès..."
TOKEN=$(firebase auth:export /tmp/users.json --project=$PROJECT_ID 2>/dev/null | grep -o '"idToken":"[^"]*' | head -1 | cut -d'"' -f4 || echo "")

# Alternative: utiliser gcloud pour obtenir le token
if [ -z "$TOKEN" ]; then
  echo "   Utilisation de gcloud..."
  TOKEN=$(gcloud auth application-default print-access-token 2>/dev/null || echo "")
fi

if [ -z "$TOKEN" ]; then
  echo "❌ Impossible d'obtenir le token d'accès"
  echo "   Utilise plutôt la méthode manuelle:"
  echo "   https://console.firebase.google.com → $PROJECT_ID → Firestore"
  exit 1
fi

echo "✅ Token obtenu"
echo ""

# Récupérer toutes les offres
echo "📊 Récupération des offres..."
RESPONSE=$(curl -s -X POST \
  "https://firestore.googleapis.com/v1/projects/$PROJECT_ID/databases/(default)/documents:runQuery" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "structuredQuery": {
      "from": [{"collectionId": "'$COLLECTION'"}],
      "limit": 1000
    }
  }')

# Parser et compter
COUNT=$(echo "$RESPONSE" | grep -o '"name"' | wc -l)

if [ $COUNT -eq 0 ]; then
  echo "❌ Aucune offre trouvée (ou erreur API)"
  echo "   Répond: $RESPONSE"
  exit 1
fi

echo "✅ $COUNT offre(s) trouvée(s)"
echo ""

# Mettre à jour chaque offre
echo "✏️  Mise à jour..."
UPDATED=0

echo "$RESPONSE" | grep -o '"name":"[^"]*documents/offers/[^"]*' | cut -d'"' -f4 | while read DOC_PATH; do
  DOC_ID=$(echo "$DOC_PATH" | rev | cut -d'/' -f1 | rev)
  
  echo "  Updating: $DOC_ID"
  
  curl -s -X PATCH \
    "https://firestore.googleapis.com/v1/$DOC_PATH" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "fields": {
        "isActive": {"booleanValue": true},
        "updatedAt": {"timestampValue": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}
      }
    }' > /dev/null
  
  echo "    ✅ Done"
  UPDATED=$((UPDATED + 1))
done

echo ""
echo "✨ Terminé : $UPDATED offre(s) activée(s)"
echo ""
echo "🚀 Maintenant :"
echo "   1. Ouvre l'app"
echo "   2. Va sur 'Je consulte les offres'"
echo "   3. Les annonces doivent s'afficher ! 🎉"

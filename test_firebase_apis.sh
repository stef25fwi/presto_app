#!/bin/bash

set -euo pipefail

echo "🔍 Test des clés API Firebase - Presto App"
echo "=========================================="
echo ""

# Configuration
API_KEY="${FIREBASE_WEB_API_KEY:-}"
PROJECT_ID="presto-app-74abe"
AUTH_DOMAIN="presto-app-74abe.firebaseapp.com"

if [ -z "$API_KEY" ]; then
  echo "FIREBASE_WEB_API_KEY manquante" >&2
  exit 1
fi

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "📋 Configuration détectée:"
echo "   Project ID: $PROJECT_ID"
echo "   API Key: ${API_KEY:0:20}..."
echo "   Auth Domain: $AUTH_DOMAIN"
echo ""

# Test 1: Firebase Auth API
echo "1️⃣  Test Firebase Auth API..."
AUTH_RESPONSE=$(curl -s -w "\n%{http_code}" \
  "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"returnSecureToken":true}')

HTTP_CODE=$(echo "$AUTH_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$AUTH_RESPONSE" | head -n-1)

if [ "$HTTP_CODE" = "400" ]; then
  # 400 = requête invalide mais API key fonctionne
  if echo "$RESPONSE_BODY" | grep -q "MISSING_EMAIL"; then
    echo -e "   ${GREEN}✅ Firebase Auth API: OK${NC}"
    echo "   (Code 400 attendu sans email - API key valide)"
  else
    echo -e "   ${YELLOW}⚠️  Response: $RESPONSE_BODY${NC}"
  fi
elif [ "$HTTP_CODE" = "403" ]; then
  echo -e "   ${RED}❌ API Key invalide ou restrictions IP${NC}"
  echo "   Response: $RESPONSE_BODY"
elif [ "$HTTP_CODE" = "200" ]; then
  echo -e "   ${GREEN}✅ Firebase Auth API: OK${NC}"
else
  echo -e "   ${YELLOW}⚠️  HTTP $HTTP_CODE${NC}"
  echo "   Response: $RESPONSE_BODY"
fi
echo ""

# Test 2: Firestore API
echo "2️⃣  Test Firestore API..."
FIRESTORE_RESPONSE=$(curl -s -w "\n%{http_code}" \
  "https://firestore.googleapis.com/v1/projects/$PROJECT_ID/databases/(default)/documents/_test/connection" \
  -H "Content-Type: application/json")

HTTP_CODE=$(echo "$FIRESTORE_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$FIRESTORE_RESPONSE" | head -n-1)

if [ "$HTTP_CODE" = "200" ]; then
  echo -e "   ${GREEN}✅ Firestore API: OK (document accessible)${NC}"
elif [ "$HTTP_CODE" = "404" ]; then
  echo -e "   ${GREEN}✅ Firestore API: OK (document non trouvé - normal)${NC}"
elif [ "$HTTP_CODE" = "403" ]; then
  echo -e "   ${YELLOW}⚠️  Firestore: Accès refusé (vérifier les règles de sécurité)${NC}"
else
  echo -e "   ${YELLOW}⚠️  HTTP $HTTP_CODE${NC}"
fi
echo ""

# Test 3: Firebase Functions
echo "3️⃣  Test Firebase Functions..."
FUNCTIONS_URL="https://europe-west1-$PROJECT_ID.cloudfunctions.net/trackUserLogin"
FUNCTIONS_RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST "$FUNCTIONS_URL" \
  -H "Content-Type: application/json" \
  -d '{}' 2>&1)

HTTP_CODE=$(echo "$FUNCTIONS_RESPONSE" | tail -n1)

if [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "403" ]; then
  echo -e "   ${GREEN}✅ Functions déployées (Auth requise)${NC}"
  echo "   URL: $FUNCTIONS_URL"
elif [ "$HTTP_CODE" = "404" ]; then
  echo -e "   ${YELLOW}⚠️  Function non trouvée ou non déployée${NC}"
elif [ "$HTTP_CODE" = "200" ]; then
  echo -e "   ${GREEN}✅ Functions accessibles${NC}"
else
  echo -e "   ${YELLOW}⚠️  HTTP $HTTP_CODE${NC}"
fi
echo ""

# Test 4: Storage
echo "4️⃣  Test Firebase Storage..."
STORAGE_URL="https://firebasestorage.googleapis.com/v0/b/$PROJECT_ID.firebasestorage.app/o"
STORAGE_RESPONSE=$(curl -s -w "\n%{http_code}" "$STORAGE_URL")

HTTP_CODE=$(echo "$STORAGE_RESPONSE" | tail -n1)

if [ "$HTTP_CODE" = "200" ]; then
  echo -e "   ${GREEN}✅ Storage API: OK${NC}"
elif [ "$HTTP_CODE" = "403" ]; then
  echo -e "   ${YELLOW}⚠️  Storage: Accès refusé (vérifier les règles)${NC}"
else
  echo -e "   ${YELLOW}⚠️  HTTP $HTTP_CODE${NC}"
fi
echo ""

# Test 5: Connectivité générale
echo "5️⃣  Test connectivité Firebase..."
FIREBASE_PING=$(curl -s -w "\n%{http_code}" "https://www.gstatic.com/firebasejs/ui/6.1.0/firebase-ui-auth.js" | tail -n1)

if [ "$FIREBASE_PING" = "200" ]; then
  echo -e "   ${GREEN}✅ Connectivité Firebase: OK${NC}"
else
  echo -e "   ${RED}❌ Problème de connectivité${NC}"
fi
echo ""

# Résumé
echo "═══════════════════════════════════════════════════"
echo "📊 RÉSUMÉ DES TESTS"
echo "═══════════════════════════════════════════════════"
echo ""
echo "✅ Tests terminés!"
echo ""
echo "💡 Prochaines étapes:"
echo "   1. Vérifier Firebase Console: https://console.firebase.google.com"
echo "   2. Activer Authentication → Sign-in method → Google"
echo "   3. Vérifier les domaines autorisés dans Authentication → Settings"
echo "   4. Déployer les Functions si nécessaire: firebase deploy --only functions"
echo ""

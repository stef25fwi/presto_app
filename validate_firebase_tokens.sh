#!/bin/bash

# ✅ Script de Validation des Tokens Firebase Firestore API
# Vérifie que tous les tokens et clés API sont correctement configurés
# Usage: bash validate_firebase_tokens.sh

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Compteurs
PASS=0
FAIL=0
WARN=0

# Fonctions
check_pass() {
    echo -e "${GREEN}✅ $1${NC}"
    ((PASS++))
}

check_fail() {
    echo -e "${RED}❌ $1${NC}"
    ((FAIL++))
}

check_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    ((WARN++))
}

section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

echo ""
echo "🔥 === Validation des Tokens Firebase Firestore API ==="
echo "📅 $(date)"
echo ""

# ============================================================
# 1. Vérifier firebase_options.dart
# ============================================================
section "1. Configuration Firebase Options"

if [ -f "lib/firebase_options.dart" ]; then
    check_pass "Fichier lib/firebase_options.dart existe"
    
    # Vérifier apiKey
    if grep -q "apiKey:" lib/firebase_options.dart; then
        API_KEY=$(grep "apiKey:" lib/firebase_options.dart | grep -o "'[^']*'" | head -1 | tr -d "'")
        if [[ ${#API_KEY} -ge 40 ]]; then
            check_pass "apiKey format valide (${#API_KEY} caractères)"
        else
            check_fail "apiKey format invalide (${#API_KEY} caractères, attendu >= 40)"
        fi
    else
        check_fail "apiKey non trouvée"
    fi
    
    # Vérifier authDomain
    if grep -q "authDomain:" lib/firebase_options.dart; then
        if grep -q "firebaseapp.com" lib/firebase_options.dart; then
            check_pass "authDomain format valide (*.firebaseapp.com)"
        else
            check_fail "authDomain format invalide"
        fi
    else
        check_fail "authDomain non trouvée"
    fi
    
    # Vérifier projectId
    if grep -q "projectId:" lib/firebase_options.dart; then
        PROJECT_ID=$(grep "projectId:" lib/firebase_options.dart | grep -o "'[^']*'" | head -1 | tr -d "'")
        if [[ $PROJECT_ID == "presto-app-74abe" ]]; then
            check_pass "projectId correct: $PROJECT_ID"
        else
            check_fail "projectId incorrect: $PROJECT_ID"
        fi
    else
        check_fail "projectId non trouvée"
    fi
    
    # Vérifier storageBucket
    if grep -q "storageBucket:" lib/firebase_options.dart; then
        if grep -q "firebasestorage.app" lib/firebase_options.dart; then
            check_pass "storageBucket format valide (*.firebasestorage.app)"
        else
            check_fail "storageBucket format invalide"
        fi
    else
        check_fail "storageBucket non trouvée"
    fi
    
    # Vérifier messagingSenderId
    if grep -q "messagingSenderId:" lib/firebase_options.dart; then
        SENDER_ID=$(grep "messagingSenderId:" lib/firebase_options.dart | grep -o "[0-9]\+" | head -1)
        if [[ ${#SENDER_ID} -eq 12 ]]; then
            check_pass "messagingSenderId format valide (12 chiffres)"
        else
            check_fail "messagingSenderId format invalide (${#SENDER_ID} chiffres, attendu 12)"
        fi
    else
        check_fail "messagingSenderId non trouvée"
    fi
    
    # Vérifier appId
    if grep -q "appId:" lib/firebase_options.dart; then
        APP_ID=$(grep "appId:" lib/firebase_options.dart | grep -o "'[^']*'" | head -1 | tr -d "'")
        if [[ $APP_ID == *":web:"* ]]; then
            check_pass "appId format valide (type Web)"
        else
            check_fail "appId format invalide (type non-Web)"
        fi
    else
        check_fail "appId non trouvée"
    fi
else
    check_fail "Fichier lib/firebase_options.dart n'existe pas"
fi

# ============================================================
# 2. Vérifier google_places_config.dart
# ============================================================
section "2. Configuration Google Places (Deprecated)"

if [ -f "lib/google_places_config.dart" ]; then
    check_pass "Fichier lib/google_places_config.dart existe"
    
    if grep -q "@Deprecated" lib/google_places_config.dart; then
        check_pass "Google Places API marquée comme @Deprecated"
    else
        check_warn "Google Places API n'est pas marquée comme deprecated"
    fi
    
    if grep -q "kGooglePlacesApiKey = '';" lib/google_places_config.dart; then
        check_pass "Google Places API key vide (sécurisée)"
    else
        check_fail "Google Places API key non-vide (risque de sécurité)"
    fi
else
    check_warn "Fichier lib/google_places_config.dart n'existe pas"
fi

# ============================================================
# 3. Vérifier firebase.json
# ============================================================
section "3. Configuration firebase.json"

if [ -f "firebase.json" ]; then
    check_pass "Fichier firebase.json existe"
    
    if grep -q '".env"' firebase.json; then
        check_pass "Fichier .env dans ignore list"
    else
        check_warn "Fichier .env peut ne pas être dans ignore list"
    fi
    
    if grep -q '"hosting"' firebase.json; then
        check_pass "Configuration Hosting présente"
    else
        check_fail "Configuration Hosting manquante"
    fi
    
    if grep -q '"firestore"' firebase.json; then
        check_pass "Configuration Firestore présente"
    else
        check_fail "Configuration Firestore manquante"
    fi
    
    if grep -q '"storage"' firebase.json; then
        check_pass "Configuration Storage présente"
    else
        check_fail "Configuration Storage manquante"
    fi
else
    check_fail "Fichier firebase.json n'existe pas"
fi

# ============================================================
# 4. Vérifier .gitignore pour secrets
# ============================================================
section "4. Secrets Exclus (.gitignore)"

if [ -f ".gitignore" ]; then
    check_pass "Fichier .gitignore existe"
    
    SECRETS_FOUND=0
    
    if grep -q "^\.env$" .gitignore || grep -q "\.env" .gitignore; then
        check_pass ".env exclus du contrôle de version"
        ((SECRETS_FOUND++))
    else
        check_fail ".env NON exclus du contrôle de version (RISQUE!)"
    fi
    
    if grep -q "runtimeconfig" .gitignore; then
        check_pass ".runtimeconfig.json exclus"
        ((SECRETS_FOUND++))
    else
        check_warn ".runtimeconfig.json peut ne pas être exclu"
    fi
    
    if grep -q "firebase-debug" .gitignore; then
        check_pass "firebase-debug logs exclus"
        ((SECRETS_FOUND++))
    else
        check_warn "firebase-debug logs peuvent ne pas être exclus"
    fi
else
    check_fail ".gitignore n'existe pas"
fi

# ============================================================
# 5. Vérifier Cloud Functions (TypeScript)
# ============================================================
section "5. Configuration Cloud Functions"

if [ -d "functions" ]; then
    check_pass "Répertoire functions existe"
    
    # Vérifier Firebase v2
    if grep -q "defineString\|defineSecret" functions/src/*.ts 2>/dev/null; then
        check_pass "Cloud Functions utilise Firebase Params v2"
    else
        check_warn "Cloud Functions peut ne pas utiliser Firebase Params v2"
    fi
    
    # Vérifier pas de secrets en dur
    if grep -q "apiKey\|password\|secret" functions/src/*.ts 2>/dev/null | grep -v "defineString\|defineSecret"; then
        check_warn "Secrets potentiels trouvés en dur dans Cloud Functions"
    else
        check_pass "Pas de secrets codés en dur détectés"
    fi
    
    if [ -f "functions/.env.example" ]; then
        check_pass "Fichier functions/.env.example pour documentation"
    else
        check_warn "Fichier functions/.env.example manquant (recommandé)"
    fi
else
    check_warn "Répertoire functions n'existe pas"
fi

# ============================================================
# 6. Vérifier Firestore Rules
# ============================================================
section "6. Règles de Sécurité Firestore"

if [ -f "firestore.rules" ]; then
    check_pass "Fichier firestore.rules existe"
    
    if grep -q "match /offers" firestore.rules; then
        check_pass "Règles pour collection 'offers' présentes"
    else
        check_warn "Pas de règles détectées pour 'offers'"
    fi
    
    if grep -q "allow read:" firestore.rules && grep -q "allow write:" firestore.rules; then
        check_pass "Règles read/write définies"
    else
        check_warn "Règles read/write peuvent être manquantes"
    fi
    
    if grep -q "request.auth" firestore.rules; then
        check_pass "Authentification Firebase utilisée dans les règles"
    else
        check_warn "Authentification Firebase peut ne pas être utilisée"
    fi
else
    check_fail "Fichier firestore.rules n'existe pas"
fi

# ============================================================
# 7. Vérifier Storage Rules
# ============================================================
section "7. Règles de Sécurité Storage"

if [ -f "storage.rules" ]; then
    check_pass "Fichier storage.rules existe"
    
    if grep -q "match /" storage.rules; then
        check_pass "Règles de base définies"
    else
        check_fail "Pas de règles détectées"
    fi
    
    if grep -q "request.auth" storage.rules; then
        check_pass "Authentification Firebase utilisée"
    else
        check_warn "Authentification Firebase peut ne pas être utilisée"
    fi
else
    check_fail "Fichier storage.rules n'existe pas"
fi

# ============================================================
# 8. Résumé & Score
# ============================================================
section "Résumé de Validation"

TOTAL=$((PASS + FAIL + WARN))
SCORE=$(( (PASS * 100) / (PASS + FAIL) ))

echo ""
echo "Résultats:"
echo -e "  ${GREEN}✅ Valides: $PASS${NC}"
echo -e "  ${RED}❌ Erreurs: $FAIL${NC}"
echo -e "  ${YELLOW}⚠️  Avertissements: $WARN${NC}"
echo -e "  📊 Total: $TOTAL"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✅ TOUS LES TOKENS FIREBASE SONT VALIDES${NC}"
    echo -e "${GREEN}Score de Sécurité: $SCORE%${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 0
else
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}❌ ERREURS DÉTECTÉES - ATTENTION REQUISE${NC}"
    echo -e "${RED}Score de Sécurité: $SCORE%${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 1
fi

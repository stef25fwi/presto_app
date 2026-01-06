#!/bin/bash

# 🔥 Script de vérification Firebase - Presto App
# Ce script vérifie toute la configuration Firebase et détecte les problèmes

echo "🔥 === Vérification Firebase Presto App ==="
echo ""

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Compteurs
PASS=0
FAIL=0
WARN=0

# Fonctions helper
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

echo "📋 1. Vérification des fichiers de configuration"
echo "================================================"

# Vérifier firebase.json
if [ -f "firebase.json" ]; then
    check_pass "firebase.json existe"
    
    # Vérifier hosting config
    if grep -q '"hosting"' firebase.json; then
        check_pass "Configuration hosting présente"
        
        # Vérifier public directory
        if grep -q '"public": "build/web"' firebase.json; then
            check_pass "Directory public: build/web"
        else
            check_fail "Directory public incorrect (devrait être build/web)"
        fi
    else
        check_fail "Configuration hosting manquante"
    fi
else
    check_fail "firebase.json manquant"
fi

# Vérifier .firebaserc
if [ -f ".firebaserc" ]; then
    check_pass ".firebaserc existe"
    
    # Vérifier project ID
    if grep -q '"default": "presto-app-74abe"' .firebaserc; then
        check_pass "Project ID correct: presto-app-74abe"
    else
        check_warn "Project ID différent de presto-app-74abe"
    fi
else
    check_fail ".firebaserc manquant"
fi

# Vérifier firebase_options.dart
if [ -f "lib/firebase_options.dart" ]; then
    check_pass "lib/firebase_options.dart existe"
    
    # Vérifier apiKey
    if grep -q "apiKey: 'AIzaSyB-Oo_86VpG_refQU7my0qk10tQFQDU-Fo'" lib/firebase_options.dart; then
        check_pass "API Key présente"
    else
        check_warn "API Key différente ou absente"
    fi
    
    # Vérifier projectId
    if grep -q "projectId: 'presto-app-74abe'" lib/firebase_options.dart; then
        check_pass "Project ID cohérent"
    else
        check_fail "Project ID incohérent"
    fi
else
    check_fail "lib/firebase_options.dart manquant"
fi

echo ""
echo "📋 2. Vérification web/index.html"
echo "================================="

if [ -f "web/index.html" ]; then
    check_pass "web/index.html existe"
    
    # Vérifier Google Client ID
    if grep -q 'google-signin-client_id' web/index.html; then
        check_pass "Google Sign-In Client ID configuré"
        CLIENT_ID=$(grep 'google-signin-client_id' web/index.html | sed 's/.*content="\([^"]*\)".*/\1/')
        echo "   Client ID: $CLIENT_ID"
    else
        check_warn "Google Sign-In Client ID non configuré dans index.html"
    fi
else
    check_fail "web/index.html manquant"
fi

echo ""
echo "📋 3. Vérification des règles Firestore et Storage"
echo "=================================================="

# Firestore rules
if [ -f "firestore.rules" ]; then
    check_pass "firestore.rules existe"
    
    if grep -q "rules_version = '2'" firestore.rules; then
        check_pass "Version des règles Firestore: 2"
    fi
else
    check_fail "firestore.rules manquant"
fi

# Storage rules
if [ -f "storage.rules" ]; then
    check_pass "storage.rules existe"
    
    if grep -q "rules_version = '2'" storage.rules; then
        check_pass "Version des règles Storage: 2"
    fi
else
    check_fail "storage.rules manquant"
fi

echo ""
echo "📋 4. Vérification du code d'authentification"
echo "============================================="

# Vérifier main.dart
if [ -f "lib/main.dart" ]; then
    check_pass "lib/main.dart existe"
    
    # Vérifier initialisation Firebase
    if grep -q "Firebase.initializeApp" lib/main.dart; then
        check_pass "Firebase.initializeApp() présent"
    else
        check_fail "Firebase.initializeApp() manquant"
    fi
    
    # Vérifier import firebase_options
    if grep -q "firebase_options.dart" lib/main.dart; then
        check_pass "Import firebase_options.dart présent"
    else
        check_fail "Import firebase_options.dart manquant"
    fi
else
    check_fail "lib/main.dart manquant"
fi

# Vérifier profile_page.dart
if [ -f "lib/profile_page.dart" ]; then
    check_pass "lib/profile_page.dart existe"
    
    # Vérifier Google Sign-In
    if grep -q "_onGoogleSignIn" lib/profile_page.dart; then
        check_pass "Méthode _onGoogleSignIn() présente"
    else
        check_fail "Méthode _onGoogleSignIn() manquante"
    fi
    
    # Vérifier fallback redirect
    if grep -q "signInWithRedirect" lib/profile_page.dart; then
        check_pass "Fallback redirect configuré"
    else
        check_warn "Pas de fallback redirect pour popup bloquée"
    fi
else
    check_fail "lib/profile_page.dart manquant"
fi

echo ""
echo "📋 5. Vérification pubspec.yaml"
echo "================================"

if [ -f "pubspec.yaml" ]; then
    check_pass "pubspec.yaml existe"
    
    # Vérifier packages Firebase
    FIREBASE_PACKAGES=(
        "firebase_core"
        "firebase_auth"
        "cloud_firestore"
        "firebase_storage"
    )
    
    for pkg in "${FIREBASE_PACKAGES[@]}"; do
        if grep -q "$pkg:" pubspec.yaml; then
            check_pass "Package $pkg présent"
        else
            check_warn "Package $pkg manquant ou commenté"
        fi
    done
else
    check_fail "pubspec.yaml manquant"
fi

echo ""
echo "📋 6. Vérification build/web (si existe)"
echo "========================================"

if [ -d "build/web" ]; then
    check_pass "Dossier build/web existe"
    
    # Vérifier index.html compilé
    if [ -f "build/web/index.html" ]; then
        check_pass "build/web/index.html généré"
    else
        check_warn "build/web/index.html manquant (rebuild nécessaire)"
    fi
    
    # Vérifier flutter.js
    if [ -f "build/web/flutter.js" ] || [ -f "build/web/flutter_bootstrap.js" ]; then
        check_pass "Flutter bootstrap présent"
    else
        check_warn "Flutter bootstrap manquant (rebuild nécessaire)"
    fi
else
    check_warn "build/web absent (jamais compilé)"
fi

echo ""
echo "📋 7. Test de connectivité Firebase (si Firebase CLI disponible)"
echo "================================================================"

if command -v firebase &> /dev/null; then
    check_pass "Firebase CLI installé"
    
    # Vérifier version
    FB_VERSION=$(firebase --version)
    echo "   Version: $FB_VERSION"
    
    # Vérifier projet actif
    ACTIVE_PROJECT=$(firebase projects:list 2>&1 | grep "presto-app-74abe" || echo "")
    if [ -n "$ACTIVE_PROJECT" ]; then
        check_pass "Projet presto-app-74abe accessible"
    else
        check_warn "Projet presto-app-74abe non trouvé (authentification nécessaire?)"
    fi
else
    check_warn "Firebase CLI non installé"
fi

echo ""
echo "================================================"
echo "📊 RÉSUMÉ"
echo "================================================"
echo -e "${GREEN}✅ Tests réussis: $PASS${NC}"
echo -e "${YELLOW}⚠️  Avertissements: $WARN${NC}"
echo -e "${RED}❌ Échecs: $FAIL${NC}"
echo ""

if [ $FAIL -eq 0 ]; then
    if [ $WARN -eq 0 ]; then
        echo -e "${GREEN}🎉 Configuration Firebase parfaite !${NC}"
        exit 0
    else
        echo -e "${YELLOW}⚠️  Configuration Firebase OK avec quelques avertissements${NC}"
        exit 0
    fi
else
    echo -e "${RED}❌ Problèmes détectés dans la configuration Firebase${NC}"
    echo ""
    echo "📝 Prochaines étapes recommandées:"
    echo "1. Corriger les fichiers manquants ou incorrects"
    echo "2. Vérifier Firebase Console → Authentication"
    echo "3. Tester avec: open test_firebase_connection.html"
    echo "4. Rebuild: flutter clean && flutter build web --release"
    exit 1
fi

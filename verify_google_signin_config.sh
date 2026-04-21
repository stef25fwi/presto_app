#!/bin/bash

# Script de vérification de la configuration Google Sign-In
# Utilisation: bash verify_google_signin_config.sh

echo "🔍 Vérification de la Configuration Google Sign-In"
echo "=================================================="
echo ""

# Couleurs
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Compteurs
total_checks=0
passed_checks=0

check_result() {
  local name=$1
  local status=$2
  local details=$3

  total_checks=$((total_checks + 1))

  if [ "$status" = "✅" ]; then
    passed_checks=$((passed_checks + 1))
    echo -e "${GREEN}$status${NC} $name"
  else
    echo -e "${RED}$status${NC} $name"
  fi

  if [ ! -z "$details" ]; then
    echo "   $details"
  fi
  echo ""
}

echo "📝 Vérifications du Code"
echo "----------------------"

# Vérifier Client ID dans web/index.html
if grep -q "151421230024-lung00ghpcc0qgbukvo29og1kuapnggf.apps.googleusercontent.com" web/index.html; then
  check_result "Client ID Web dans web/index.html" "✅" "Client ID: 151421230024-lung00ghpcc0qgbukvo29og1kuapnggf.apps.googleusercontent.com"
else
  check_result "Client ID Web dans web/index.html" "❌" "Client ID non trouvé ou incorrect"
fi

# Vérifier Firebase Config
if grep -q "presto-app-74abe" lib/firebase_options.dart; then
  check_result "Firebase Project ID" "✅" "Project ID: presto-app-74abe"
else
  check_result "Firebase Project ID" "❌" "Project ID non trouvé"
fi

# Vérifier API Key
if grep -q "AIzaSyB-Oo_86VpG_refQU7my0qk10tQFQDU-Fo" lib/firebase_options.dart; then
  check_result "Firebase API Key" "✅" "API Key présente"
else
  check_result "Firebase API Key" "❌" "API Key non trouvée"
fi

# Vérifier Auth Domain
if grep -q "presto-app-74abe.firebaseapp.com" lib/firebase_options.dart; then
  check_result "Firebase Auth Domain" "✅" "Auth Domain: presto-app-74abe.firebaseapp.com"
else
  check_result "Firebase Auth Domain" "❌" "Auth Domain non trouvée"
fi

# Vérifier implémentation AccountSocialAuthActions
if grep -q "signInWithGoogle" lib/services/account_social_auth_actions.dart; then
  check_result "Implémentation signInWithGoogle" "✅" "Méthode trouvée"
else
  check_result "Implémentation signInWithGoogle" "❌" "Méthode non trouvée"
fi

# Vérifier GoogleAuthService
if [ -f "lib/services/google_auth_service.dart" ]; then
  check_result "Service GoogleAuthService" "✅" "Fichier existe"
else
  check_result "Service GoogleAuthService" "❌" "Fichier manquant"
fi

# Vérifier dépendances
echo ""
echo "📦 Vérifications des Dépendances"
echo "--------------------------------"

if grep -q "firebase_auth:" pubspec.yaml; then
  check_result "firebase_auth" "✅" "Package présent"
else
  check_result "firebase_auth" "❌" "Package manquant"
fi

if grep -q "firebase_core:" pubspec.yaml; then
  check_result "firebase_core" "✅" "Package présent"
else
  check_result "firebase_core" "❌" "Package manquant"
fi

if grep -q "google_sign_in:" pubspec.yaml 2>/dev/null; then
  check_result "google_sign_in" "✅" "Package présent"
else
  # C'est optionnel pour web
  check_result "google_sign_in" "⚠️" "Package optionnel (web utilise Firebase Auth)"
fi

echo ""
echo "⚙️  Configuration Firebase Console (À Vérifier Manuellement)"
echo "-----------------------------------------------------------"
echo ""
echo "🔗 Liens pour Configuration:"
echo "   1. Authentication Setup:"
echo "      https://console.firebase.google.com/project/presto-app-74abe/authentication"
echo ""
echo "   2. Authorized Domains:"
echo "      https://console.firebase.google.com/project/presto-app-74abe/authentication/settings"
echo ""
echo "   3. OAuth Consent Screen:"
echo "      https://console.cloud.google.com/apis/credentials/consent?project=presto-app-74abe"
echo ""
echo "   4. OAuth Client ID:"
echo "      https://console.cloud.google.com/apis/credentials?project=presto-app-74abe"
echo ""

echo ""
echo "✅ À Vérifier dans Firebase Console:"
echo "   ☐ Google Sign-In activé dans Authentication → Sign-in method"
echo "   ☐ Domaines autorisés ajoutés:"
echo "      • localhost"
echo "      • presto-app-74abe.web.app"
echo "      • presto-app-74abe.firebaseapp.com"
echo ""

echo "✅ À Vérifier dans Google Cloud Console:"
echo "   ☐ OAuth Consent Screen configuré (External type)"
echo "   ☐ Client ID OAuth Web application créé/configuré"
echo "   ☐ Authorized JavaScript origins:"
echo "      • https://presto-app-74abe.web.app"
echo "      • https://presto-app-74abe.firebaseapp.com"
echo "      • http://localhost (pour dev)"
echo ""
echo "   ☐ Authorized redirect URIs:"
echo "      • https://presto-app-74abe.web.app/__/auth/handler"
echo "      • https://presto-app-74abe.firebaseapp.com/__/auth/handler"
echo "      • http://localhost/__/auth/handler"
echo ""

# Résumé
echo ""
echo "=================================================="
echo "📊 Résumé des Vérifications"
echo "=================================================="
echo "Vérifications du Code: $passed_checks/$total_checks"
echo ""

if [ $passed_checks -eq $total_checks ]; then
  echo -e "${GREEN}✅ Code correctement configuré${NC}"
  echo ""
  echo "⚠️  IMPORTANT: Vous devez maintenant configurer:"
  echo "   1. Firebase Console (domaines autorisés, Google Sign-In)"
  echo "   2. Google Cloud Console (OAuth consent screen, Client ID)"
  echo ""
  echo "Consultez le guide complet:"
  echo "   GOOGLE_LOGIN_SETUP_GUIDE.md"
else
  echo -e "${RED}❌ Erreurs détectées - Consultez les détails ci-dessus${NC}"
fi

echo ""
echo "=================================================="

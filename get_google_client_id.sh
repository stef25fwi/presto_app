#!/bin/bash

# Script pour récupérer et configurer le Client ID Google OAuth
# Usage: ./get_google_client_id.sh

echo "🔍 Récupération du Client ID Google pour Firebase"
echo "=================================================="
echo ""

PROJECT_ID="presto-app-74abe"

echo "📋 Votre projet Firebase: $PROJECT_ID"
echo ""

echo "Pour récupérer votre Client ID Google:"
echo ""
echo "1️⃣  MÉTHODE 1: Firebase Console"
echo "   👉 https://console.firebase.google.com/project/$PROJECT_ID/settings/general"
echo "   - Scroll vers le bas"
echo "   - Section 'Your apps' → Application Web"
echo "   - SDK snippet → Config"
echo "   - Pas de Client ID OAuth ici, aller à la méthode 2"
echo ""

echo "2️⃣  MÉTHODE 2: Google Cloud Console (RECOMMANDÉ)"
echo "   👉 https://console.cloud.google.com/apis/credentials?project=$PROJECT_ID"
echo "   - Section 'OAuth 2.0 Client IDs'"
echo "   - Chercher le client de type 'Web application'"
echo "   - Format: 151421230024-XXXXX.apps.googleusercontent.com"
echo ""

echo "3️⃣  MÉTHODE 3: Firebase Authentication Settings"
echo "   👉 https://console.firebase.google.com/project/$PROJECT_ID/authentication/providers"
echo "   - Cliquer sur 'Google'"
echo "   - Activer si pas déjà fait"
echo "   - Le Web SDK configuration affiche le Client ID"
echo ""

echo "═══════════════════════════════════════════════════"
echo ""

# Vérifier si gcloud CLI est installé
if command -v gcloud &> /dev/null; then
    echo "🔧 gcloud CLI détecté, tentative de récupération automatique..."
    echo ""
    
    # Configurer le projet
    gcloud config set project $PROJECT_ID 2>/dev/null
    
    # Lister les OAuth clients
    echo "📋 OAuth 2.0 Clients disponibles:"
    gcloud alpha iap oauth-clients list 2>/dev/null || echo "   ⚠️  Commande non disponible"
    
    echo ""
    echo "Ou essayez:"
    echo "   gcloud auth application-default print-access-token"
    echo ""
else
    echo "⚠️  gcloud CLI non installé"
    echo "   Pour installation: https://cloud.google.com/sdk/docs/install"
    echo ""
fi

echo "═══════════════════════════════════════════════════"
echo ""

# Instructions de mise à jour
echo "📝 Une fois le Client ID récupéré:"
echo ""
echo "Mettre à jour web/index.html:"
echo ""
echo "Remplacer:"
echo '  <meta name="google-signin-client_id" content="151421230024-xxxxxxxxxx.apps.googleusercontent.com">'
echo ""
echo "Par:"
echo '  <meta name="google-signin-client_id" content="VOTRE_CLIENT_ID.apps.googleusercontent.com">'
echo ""

echo "Puis reconstruire:"
echo "  flutter clean"
echo "  flutter build web"
echo ""

# Vérifier le fichier actuel
echo "═══════════════════════════════════════════════════"
echo "📄 Configuration actuelle dans web/index.html:"
echo ""
grep -A1 "google-signin-client_id" web/index.html 2>/dev/null || echo "   ❌ Fichier non trouvé"
echo ""

echo "✅ Pour tester après mise à jour:"
echo "   1. flutter run -d chrome"
echo "   2. Aller sur la page 'Mon compte'"
echo "   3. Cliquer sur 'Continuer avec Google'"
echo "   4. Vérifier la console DevTools (F12)"
echo ""

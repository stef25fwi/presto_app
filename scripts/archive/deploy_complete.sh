#!/bin/bash

# 🚀 Script de Déploiement Complet - Presto App avec Messagerie Firebase

set -euo pipefail

echo "🚀 Déploiement Complet Presto App"
echo "=================================="
echo ""

# Couleurs pour les messages
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Fonction pour afficher les messages
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Vérification des prérequis
echo "🔍 Vérification des prérequis..."

if ! command -v flutter &> /dev/null; then
    print_error "Flutter n'est pas installé"
    exit 1
fi
print_success "Flutter trouvé"

if ! command -v firebase &> /dev/null; then
    print_error "Firebase CLI n'est pas installé"
    echo "   Installer: npm install -g firebase-tools"
    exit 1
fi
print_success "Firebase CLI trouvé"

echo ""

# Étape 1 : Analyse du code
echo "📋 Étape 1/5 : Analyse du code..."
if flutter analyze > /dev/null 2>&1; then
    print_success "Aucune erreur d'analyse"
else
    print_warning "Avertissements d'analyse détectés (continuons quand même)"
fi
echo ""

# Étape 2 : Nettoyage et récupération des dépendances
echo "🧹 Étape 2/5 : Nettoyage et dépendances..."
flutter clean
print_success "Nettoyage terminé"

flutter pub get
print_success "Dépendances récupérées"
echo ""

# Étape 3 : Build Flutter Web
echo "🏗️  Étape 3/5 : Build Flutter Web..."
flutter build web --release

if [ -f "build/web/index.html" ]; then
    print_success "Build web réussi"
else
    print_error "Échec du build web"
    exit 1
fi
echo ""

# Étape 4 : Déploiement des Index Firestore
echo "🔥 Étape 4/5 : Déploiement des index Firestore..."
print_warning "Les index peuvent prendre 5-10 minutes à se construire"

firebase deploy --only firestore:indexes

print_success "Index Firestore déployés"
echo "   Vérifiez le statut sur:"
echo "   https://console.firebase.google.com/project/presto-app-74abe/firestore/indexes"
echo ""

# Étape 5 : Déploiement Firebase Hosting
echo "🌐 Étape 5/5 : Déploiement Firebase Hosting..."
firebase deploy --only hosting

print_success "Application déployée sur Firebase Hosting"
echo ""

# Résumé
echo "========================================="
echo "✅ DÉPLOIEMENT TERMINÉ !"
echo "========================================="
echo ""
echo "🌐 URL de Production:"
echo "   https://presto-app-74abe.web.app/"
echo "   https://presto-app-74abe.firebaseapp.com/"
echo ""
echo "🔥 Console Firebase:"
echo "   https://console.firebase.google.com/project/presto-app-74abe"
echo ""
echo "⚠️  IMPORTANT :"
echo "   1. Vider le cache navigateur (Ctrl+Shift+R)"
echo "   2. Les index Firestore peuvent prendre 5-10 minutes"
echo "   3. Vérifier le statut des index dans la console"
echo ""
echo "📋 Fonctionnalités Déployées:"
echo "   ✅ Messagerie temps réel avec Firebase"
echo "   ✅ Page d'accueil avec dernières offres"
echo "   ✅ Page 'Je consulte' avec filtres"
echo "   ✅ Conversations et messages"
echo "   ✅ Compteurs de messages non lus"
echo ""
print_success "Déploiement réussi ! 🎉"

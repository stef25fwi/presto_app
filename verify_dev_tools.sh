#!/bin/bash

# Script de vérification des outils de développement
# Vérifie Firebase CLI et autres outils essentiels

echo "🔍 Vérification des outils de développement..."
echo "================================================"
echo ""

# Couleurs pour l'affichage
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_tool() {
    local tool=$1
    local version_cmd=$2
    
    if command -v "$tool" &> /dev/null; then
        version=$($version_cmd 2>&1 | head -n 1)
        echo -e "${GREEN}✓${NC} $tool: $version"
        return 0
    else
        echo -e "${RED}✗${NC} $tool: Non installé"
        return 1
    fi
}

# Firebase CLI
echo "📦 Firebase CLI"
check_tool "firebase" "firebase --version"
if command -v firebase &> /dev/null; then
    echo "   Connexion Firebase:"
    firebase login:list 2>&1 | head -n 3
fi
echo ""

# Flutter & Dart
echo "🎯 Flutter & Dart"
check_tool "flutter" "flutter --version"
check_tool "dart" "dart --version"
if command -v flutter &> /dev/null; then
    echo "   Flutter doctor (résumé):"
    flutter doctor 2>&1 | head -n 15
fi
echo ""

# Git
echo "📝 Git"
check_tool "git" "git --version"
if command -v git &> /dev/null; then
    echo "   Config Git:"
    git config user.name 2>&1 | sed 's/^/   - Nom: /'
    git config user.email 2>&1 | sed 's/^/   - Email: /'
fi
echo ""

# Node.js & npm
echo "📦 Node.js & npm"
check_tool "node" "node --version"
check_tool "npm" "npm --version"
echo ""

# Python
echo "🐍 Python"
check_tool "python3" "python3 --version"
check_tool "pip3" "pip3 --version"
echo ""

# Autres outils utiles
echo "🛠️  Autres outils"
check_tool "curl" "curl --version"
check_tool "wget" "wget --version"
check_tool "jq" "jq --version"
echo ""

# Vérifications spécifiques au projet
echo "📁 Projet Presto"
if [ -f "pubspec.yaml" ]; then
    echo -e "${GREEN}✓${NC} pubspec.yaml trouvé"
    flutter_version=$(grep "flutter:" pubspec.yaml -A 2 | grep "sdk:" | awk '{print $2}')
    echo "   - Flutter SDK requis: $flutter_version"
else
    echo -e "${RED}✗${NC} pubspec.yaml non trouvé"
fi

if [ -f "firebase.json" ]; then
    echo -e "${GREEN}✓${NC} firebase.json trouvé"
else
    echo -e "${RED}✗${NC} firebase.json non trouvé"
fi

if [ -d ".git" ]; then
    echo -e "${GREEN}✓${NC} Repository Git initialisé"
    current_branch=$(git branch --show-current)
    echo "   - Branche actuelle: $current_branch"
else
    echo -e "${RED}✗${NC} Repository Git non initialisé"
fi
echo ""

# Dépendances Flutter
echo "📦 Dépendances Flutter"
if [ -f "pubspec.yaml" ]; then
    if [ -d ".dart_tool" ]; then
        echo -e "${GREEN}✓${NC} Dépendances installées"
    else
        echo -e "${YELLOW}⚠${NC}  Dépendances non installées - Exécutez: flutter pub get"
    fi
fi
echo ""

# Firebase config
echo "🔥 Configuration Firebase"
if [ -f "lib/firebase_options.dart" ]; then
    echo -e "${GREEN}✓${NC} firebase_options.dart trouvé"
else
    echo -e "${YELLOW}⚠${NC}  firebase_options.dart non trouvé - Exécutez: flutterfire configure"
fi
echo ""

# Résumé
echo "================================================"
echo "✅ Vérification terminée"
echo ""
echo "💡 Commandes utiles:"
echo "   flutter pub get        # Installer les dépendances"
echo "   flutter run -d chrome  # Lancer en mode web"
echo "   firebase login         # Se connecter à Firebase"
echo "   firebase projects:list # Lister les projets Firebase"
echo "   flutter doctor         # Diagnostic complet Flutter"

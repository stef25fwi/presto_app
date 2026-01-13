#!/bin/bash
# Fix offers isActive field - Simple deployment helper

set -euo pipefail

echo "🔧 Correction des annonces dans Firebase Firestore..."
echo ""
echo "Cette opération va :"
echo "  1. Ajouter isActive: true à toutes les offres"
echo "  2. Mettre à jour le champ updatedAt"
echo ""

# Vérifier que firebase CLI est installé
if ! command -v firebase &> /dev/null; then
  echo "❌ firebase-tools n'est pas installé"
  echo "   Installe avec: npm install -g firebase-tools"
  exit 1
fi

# Vérifier qu'on est connecté
firebase projects:list > /dev/null 2>&1 || {
  echo "❌ Non connecté à Firebase"
  echo "   Connecte avec: firebase login"
  exit 1
}

# S'assurer qu'on cible le bon projet
PROJECT=$(firebase projects:list 2>/dev/null | grep -oP 'presto-app-\d+' | head -1 || echo "")
if [ -z "$PROJECT" ]; then
  echo "❌ Projet presto-app non trouvé"
  exit 1
fi

echo "✅ Projet: $PROJECT"
echo ""

# Exécuter la migration via Firestore
# Option 1: Via les functions shell
echo "🚀 Lancement de la correction..."
firebase functions:config:get > /dev/null 2>&1 && {
  # Si les functions existent
  echo "   (via Cloud Functions)"
  node fix_offers_isactive.js
} || {
  # Fallback: instructions manuelles
  echo "   (instructions manuelles ci-dessous)"
  echo ""
  echo "⚙️  OPTION MANUELLE (via Firebase Console) :"
  echo "   1. Ouvre: https://console.firebase.google.com"
  echo "   2. Projet: $PROJECT"
  echo "   3. Firestore → collection 'offers'"
  echo "   4. Pour chaque offre:"
  echo "      - Clique sur le doc"
  echo "      - Ajoute champ 'isActive' = true"
  echo "   5. Retour à l'app → 'Je consulte' doit afficher les annonces"
}

echo ""
echo "✨ Terminé"

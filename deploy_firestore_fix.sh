#!/bin/bash

# Script de déploiement des règles Firestore
# Corrige le problème de chargement des offres dans "Je consulte"

echo "🔧 Déploiement des règles Firestore..."
echo "📋 Correction: Support du champ 'isActive' pour les offres publiques"
echo ""

# Déployer les règles
firebase deploy --only firestore:rules

if [ $? -eq 0 ]; then
  echo ""
  echo "✅ Règles Firestore déployées avec succès !"
  echo ""
  echo "🧪 Test recommandé:"
  echo "   1. Ouvrir l'application"
  echo "   2. Aller sur 'Je consulte les offres'"
  echo "   3. Vérifier que les annonces se chargent"
  echo ""
else
  echo ""
  echo "❌ Erreur lors du déploiement"
  echo "   Réessaye avec: firebase deploy --only firestore:rules"
  echo ""
  exit 1
fi

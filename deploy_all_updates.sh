#!/bin/bash

echo "🚀 Déploiement complet - Presto App"
echo "===================================="
echo ""

# 1. Règles Firestore (correction page Je consulte)
echo "📋 1/2 - Déploiement des règles Firestore..."
firebase deploy --only firestore:rules

if [ $? -eq 0 ]; then
  echo "   ✅ Règles Firestore déployées"
else
  echo "   ❌ Erreur règles Firestore"
  exit 1
fi

echo ""

# 2. Index Firestore (si nécessaire)
echo "📊 2/2 - Déploiement des index Firestore..."
firebase deploy --only firestore:indexes

if [ $? -eq 0 ]; then
  echo "   ✅ Index Firestore déployés"
else
  echo "   ⚠️  Erreur index Firestore (non bloquant)"
fi

echo ""
echo "✅ Déploiement terminé !"
echo ""
echo "🧪 Tests à effectuer:"
echo "   • Page 'Je consulte les offres' → Les annonces se chargent"
echo "   • Page 'Splashscreen Admin' → Changement de version fonctionne"
echo ""
echo "📱 Relance l'application pour voir les changements"

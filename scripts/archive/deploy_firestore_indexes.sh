#!/bin/bash

# 🔥 Script de déploiement Firestore Indexes et correction de chargement

set -euo pipefail

echo "🔥 Déploiement des Index Firestore pour Presto App"
echo "=================================================="
echo ""

# Vérification de Firebase CLI
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI n'est pas installé"
    echo "   Installer: npm install -g firebase-tools"
    exit 1
fi

echo "✅ Firebase CLI trouvé"
echo ""

# Affichage des index à déployer
echo "📋 Index Firestore à déployer:"
echo "   - offers (isActive + createdAt DESC)"
echo "   - offers (isActive + cityId + createdAt DESC)"
echo "   - offers (isActive + categoryId + createdAt DESC)"
echo "   - offers (isActive + cityCategoryKey + createdAt DESC)"
echo "   - offers (isActive + dept + createdAt DESC)"
echo "   - offers (isActive + subcategory + createdAt DESC)"
echo "   - offers (isActive + budgetValue ASC + createdAt DESC)"
echo "   - offers (createdAt DESC) - Pour page d'accueil"
echo "   - conversations (participants + lastMessageAt DESC)"
echo "   - messages (sentAt ASC)"
echo ""

# Déploiement des index
echo "🚀 Déploiement des index Firestore..."
firebase deploy --only firestore:indexes

echo ""
echo "✅ Index Firestore déployés avec succès !"
echo ""
echo "⏳ Les index peuvent prendre quelques minutes à se construire."
echo "   Vérifiez le statut dans la console Firebase:"
echo "   https://console.firebase.google.com/project/presto-app-74abe/firestore/indexes"
echo ""
echo "🔍 Pour surveiller la construction des index:"
echo "   firebase firestore:indexes"
echo ""
echo "✅ Déploiement terminé !"

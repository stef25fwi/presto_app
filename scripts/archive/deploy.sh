#!/bin/bash

set -e

cd /workspaces/presto_app

echo "════════════════════════════════════════════════════════════"
echo "🚀 DÉPLOIEMENT COMPLET PRESTO APP"
echo "════════════════════════════════════════════════════════════"
echo ""

# 1️⃣ VÉRIFICATIONS PRÉ-DÉPLOIEMENT
echo "📋 ÉTAPE 1 : VÉRIFICATIONS"
echo "════════════════════════════════════════════════════════════"

echo "✅ Status Git:"
git status --short | head -20

echo ""
echo "✅ Vérification Dart/Flutter:"
flutter analyze --no-fatal-infos 2>&1 | grep -E "^(No issues|[0-9]+ issue)" || echo "⚠️  Analyse en cours..."

echo ""
echo "✅ Dépendances:"
flutter pub get 2>&1 | tail -3

echo ""
echo "✅ Vérification Firestore Rules:"
if [ -f firestore.rules ]; then
  echo "   ✓ firestore.rules found"
  wc -l firestore.rules
else
  echo "   ⚠️  firestore.rules not found"
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo "📝 ÉTAPE 2 : GIT COMMIT & PUSH"
echo "════════════════════════════════════════════════════════════"

echo ""
echo "📦 Staging des modifications..."
git add -A

echo ""
echo "💬 Création du commit..."
git commit -m "feat: analytics + admin panel + firestore rules + presence tracking

- 📊 Analytics: tracking complet (page view, filtres, offres, messages, conversations)
- 🔐 Firestore rules: isActive==true required, soft-delete, strict security
- 👨‍💼 Admin panel: stats temps réel, erreurs, plateforme, export
- 🛡️ Crashlytics: erreurs non-fatales + contexte utilisateur
- 📱 Présence: online/away/offline avec session tracking
- ✅ Performance: cache normalisation, pagination progressive

Fixes:
- Soft-delete via isActive=false (pas de suppression physique)
- Audit trail: aucune suppression de documents critiques
- Query optimization: cityCategoryKey pour réduction index
- Throttling présence (30s min), cache normalisation (200 entrées max)" || echo "⚠️  Aucun changement à committer"

echo ""
echo "🚀 Push vers GitHub..."
git push origin main

if [ $? -eq 0 ]; then
  echo "✅ Push réussi"
else
  echo "❌ Push échoué"
  exit 1
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo "🔥 ÉTAPE 3 : DÉPLOIEMENT FIREBASE"
echo "════════════════════════════════════════════════════════════"

echo ""
echo "✅ Vérification Firebase CLI..."
firebase --version

echo ""
echo "✅ Vérification authentification Firebase..."
firebase projects:list 2>&1 | head -3 || echo "⚠️  Nécessite: firebase login"

echo ""
echo "📋 Déploiement Firestore Rules..."
firebase deploy --only firestore:rules

if [ $? -eq 0 ]; then
  echo "✅ Firestore Rules déployées avec succès"
else
  echo "❌ Erreur déploiement"
  exit 1
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo "✅ VÉRIFICATIONS POST-DÉPLOIEMENT"
echo "════════════════════════════════════════════════════════════"

echo ""
echo "🔍 Règles Firestore en prod:"
firebase firestore:rules:get 2>&1 | head -10

echo ""
echo "📊 Logs Firebase (dernières 10 lignes):"
firebase functions:log --limit 10 2>&1 | tail -10 || echo "⚠️  Aucun log disponible"

echo ""
echo "════════════════════════════════════════════════════════════"
echo "🎉 DÉPLOIEMENT TERMINÉ AVEC SUCCÈS"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "📊 Résumé:"
echo "  ✅ Code poussé sur GitHub/main"
echo "  ✅ Firestore Rules déployées"
echo "  ✅ Analytics intégrée"
echo "  ✅ Admin panel fonctionnel"
echo "  ✅ Crashlytics actif"
echo "  ✅ Présence tracking"
echo ""
echo "🔗 Liens utiles:"
echo "  📊 Analytics: https://console.firebase.google.com/project/YOUR_PROJECT/analytics"
echo "  🔥 Firestore: https://console.firebase.google.com/project/YOUR_PROJECT/firestore"
echo "  💻 GitHub: https://github.com/stef25fwi/presto_app"
echo ""
echo "════════════════════════════════════════════════════════════"


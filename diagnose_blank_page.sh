#!/bin/bash

echo "🔍 DIAGNOSTIC PAGE BLANCHE"
echo "════════════════════════════════════════════════════════════"
echo ""

cd /workspaces/presto_app

# 1. Vérifier base href
echo "1️⃣ Vérification base href dans index.html:"
grep "base href" build/web/index.html || echo "❌ Pas de base href trouvé"

echo ""
echo "2️⃣ Vérification fichiers Flutter générés:"
if [ -f "build/web/main.dart.js" ]; then
  SIZE=$(du -h build/web/main.dart.js | cut -f1)
  echo "✅ main.dart.js existe (Taille: $SIZE)"
else
  echo "❌ main.dart.js manquant!"
fi

if [ -f "build/web/flutter.js" ]; then
  echo "✅ flutter.js existe"
else
  echo "❌ flutter.js manquant!"
fi

if [ -f "build/web/flutter_bootstrap.js" ]; then
  echo "✅ flutter_bootstrap.js existe"
else
  echo "❌ flutter_bootstrap.js manquant!"
fi

echo ""
echo "3️⃣ Nombre total de fichiers dans build/web:"
ls -1 build/web/ | wc -l

echo ""
echo "4️⃣ Vérification firebase.json:"
cat firebase.json | grep -A5 "hosting"

echo ""
echo "5️⃣ Test page créée:"
if [ -f "build/web/test.html" ]; then
  echo "✅ test.html créé"
else
  echo "❌ test.html manquant"
fi

echo ""
echo "6️⃣ Redéploiement avec la page de test..."
firebase deploy --only hosting

echo ""
echo "════════════════════════════════════════════════════════════"
echo "🧪 TESTS À EFFECTUER"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "1. Ouvrir: https://presto-app-74abe.web.app/test.html"
echo "   Si cette page s'affiche → Firebase fonctionne"
echo ""
echo "2. Ouvrir: https://presto-app-74abe.web.app"
echo "   F12 → Console → Noter les erreurs"
echo ""
echo "3. Vider le cache navigateur:"
echo "   - Chrome: Ctrl+Shift+Del"
echo "   - Firefox: Ctrl+Shift+Del"
echo "   - Safari: Cmd+Option+E"
echo ""
echo "4. Tester en navigation privée"
echo ""
echo "════════════════════════════════════════════════════════════"
echo ""
echo "📊 Erreurs courantes:"
echo ""
echo "❌ Erreur: 'Failed to load flutter.js'"
echo "   → Solution: Vérifier que tous les fichiers sont uploadés"
echo ""
echo "❌ Erreur: 'CORS policy'"
echo "   → Solution: Vérifier firebase.json headers"
echo ""
echo "❌ Erreur: 'main.dart.js:1 Uncaught SyntaxError'"
echo "   → Solution: Rebuild avec: flutter build web --release"
echo ""
echo "❌ Page blanche mais pas d'erreurs console"
echo "   → Solution: Problème d'initialisation Firebase Auth/Firestore"
echo ""

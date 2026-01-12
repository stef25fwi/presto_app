#!/bin/bash

set -euo pipefail

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "❌ Commande manquante: $1"
    echo "   Veuillez l'installer ou vérifier le PATH."
    exit 1
  fi
}

echo "🚀 Rebuild + Redeploy COMPLET"
echo "════════════════════════════════════════════════════════════"
cd /workspaces/presto_app

# Pré-vérifications des outils
require_cmd flutter
require_cmd firebase

# 1. Clean total
echo "1️⃣ Nettoyage complet..."
flutter clean
rm -rf build/

# 2. Pub get
echo ""
echo "2️⃣ Récupération des dépendances..."
flutter pub get

# 3. Build web (sans web-renderer flag pour compatibilité)
echo ""
echo "3️⃣ Build Flutter Web..."
flutter build web --release --base-href=/

# Vérifier la présence des fichiers de sortie
if [ ! -f "build/web/index.html" ]; then
  echo "❌ Échec du build: build/web/index.html introuvable"
  exit 1
fi

# 4. Ajouter page de test
echo ""
echo "4️⃣ Ajout page de test..."
mkdir -p build/web
cat > build/web/test.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Test Firebase</title>
  <style>
    body { 
      font-family: Arial; 
      display: flex; 
      justify-content: center; 
      align-items: center; 
      min-height: 100vh; 
      margin: 0;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      text-align: center;
    }
    h1 { font-size: 48px; }
  </style>
</head>
<body>
  <div>
    <h1>✅ Firebase OK</h1>
    <p>Si vous voyez ceci, Firebase Hosting fonctionne</p>
    <p><a href="/" style="color: white;">→ Retour à l'app</a></p>
  </div>
  <script>
    console.log('✅ Test page loaded at:', new Date().toISOString());
  </script>
</body>
</html>
EOF

# 5. Vérifications
echo ""
echo "5️⃣ Vérifications..."
if [ -f "build/web/index.html" ]; then
  echo "Base href: $(grep -E '<base href' build/web/index.html || echo 'non défini')"
else
  echo "Base href: index.html introuvable"
fi
echo "Fichiers: $(ls -1 build/web/ 2>/dev/null | wc -l) fichiers"
if [ -f "build/web/main.dart.js" ]; then
  echo "main.dart.js: $(du -h build/web/main.dart.js 2>/dev/null | awk '{print $1}')"
else
  echo "main.dart.js: MANQUANT"
fi

# 6. Deploy
echo ""
echo "6️⃣ Déploiement Firebase..."
firebase deploy --only hosting

if [ $? -eq 0 ]; then
  echo ""
  echo "════════════════════════════════════════════════════════════"
  echo "✅ DÉPLOIEMENT RÉUSSI"
  echo "════════════════════════════════════════════════════════════"
  echo ""
  echo "🧪 Tests:"
  echo "  1. https://presto-app-74abe.web.app/test.html (doit afficher 'Firebase OK')"
  echo "  2. https://presto-app-74abe.web.app (app principale)"
  echo ""
  echo "🔍 Si toujours blanc:"
  echo "  - Ouvrir DevTools (F12)"
  echo "  - Aller dans Console"
  echo "  - Noter les erreurs en ROUGE"
  echo "  - Partager les erreurs pour diagnostic"
  echo ""
else
  echo "❌ Erreur déploiement"
  exit 1
fi

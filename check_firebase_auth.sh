#!/bin/bash

echo "=== Vérification de l'authentification Firebase ==="
echo ""

# Vérifier la version de Node.js
echo "1. Version Node.js:"
node --version
echo ""

# Vérifier si firebase-tools est installé globalement
echo "2. Firebase CLI (global):"
if command -v firebase &> /dev/null; then
    firebase --version
    echo "✓ Firebase CLI trouvé globalement"
else
    echo "✗ Firebase CLI non installé globalement"
fi
echo ""

# Tester l'authentification avec npx et une version compatible
echo "3. Test d'authentification Firebase (avec firebase-tools@11.0.0 compatible Node 18):"
npx firebase-tools@11.0.0 projects:list 2>&1 | head -20
echo ""

# Vérifier le projet configuré
echo "4. Projet Firebase configuré (.firebaserc):"
if [ -f ".firebaserc" ]; then
    cat .firebaserc
    echo "✓ Fichier .firebaserc présent"
else
    echo "✗ Fichier .firebaserc absent"
fi
echo ""

# Vérifier la config hosting
echo "5. Configuration Hosting (firebase.json):"
if [ -f "firebase.json" ]; then
    grep -A 10 '"hosting"' firebase.json
    echo "✓ Configuration hosting présente"
else
    echo "✗ Fichier firebase.json absent"
fi
echo ""

echo "=== Fin de la vérification ==="

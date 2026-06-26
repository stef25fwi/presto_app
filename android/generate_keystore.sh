#!/usr/bin/env bash
# ── Génération du keystore release pour Play Store ──
# Usage : ./generate_keystore.sh
# Le fichier key.properties sera créé automatiquement.

set -euo pipefail
cd "$(dirname "$0")"

KEYSTORE_FILE="app/upload-keystore.jks"
KEY_ALIAS="upload"
VALIDITY_DAYS=10000
KEY_PROPERTIES="key.properties"

if [[ -f "$KEYSTORE_FILE" ]]; then
  echo "⚠️  $KEYSTORE_FILE existe déjà. Supprime-le d'abord si tu veux en générer un nouveau."
  exit 1
fi

echo "🔑 Génération du keystore release..."
echo "   Tu vas devoir fournir un mot de passe (minimum 6 caractères)."
echo ""

keytool -genkey -v \
  -keystore "$KEYSTORE_FILE" \
  -storetype JKS \
  -alias "$KEY_ALIAS" \
  -keyalg RSA \
  -keysize 2048 \
  -validity "$VALIDITY_DAYS"

echo ""
read -sp "🔐 Re-saisis le mot de passe du keystore : " STORE_PASS
echo ""
read -sp "🔐 Re-saisis le mot de passe de la clé : " KEY_PASS
echo ""

cat > "$KEY_PROPERTIES" <<EOF
storePassword=$STORE_PASS
keyPassword=$KEY_PASS
keyAlias=$KEY_ALIAS
storeFile=../app/$KEYSTORE_FILE
EOF

echo ""
echo "✅ Keystore créé : $KEYSTORE_FILE"
echo "✅ key.properties créé (non versionné)"
echo ""
echo "Prochaine étape : flutter build appbundle --release"

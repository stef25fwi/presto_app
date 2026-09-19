#!/usr/bin/env bash
# ── Génération EXCEPTIONNELLE d'une nouvelle clé d'upload Google Play ──
# Usage volontaire : ./generate_keystore.sh --create-new-upload-key
#
# IMPORTANT : après le premier enregistrement de cette clé dans Google Play,
# ne régénère jamais une nouvelle clé simplement parce que le fichier local
# manque. Restaure le keystore depuis la sauvegarde sécurisée / Secret Manager.

set -euo pipefail
cd "$(dirname "$0")"

if [[ "${1:-}" != "--create-new-upload-key" ]]; then
  cat <<'EOF'
❌ Génération refusée par défaut.

Ce script crée une NOUVELLE clé d'upload Google Play.
Après le premier upload Play Console, une régénération accidentelle peut casser
le flux de publication jusqu'à réinitialisation officielle de la clé d'upload.

Si l'application n'a encore jamais enregistré de clé d'upload et que tu veux
réellement en créer une nouvelle, relance explicitement :

  ./generate_keystore.sh --create-new-upload-key

Si une clé existe déjà pour iliprestō, restaure-la au lieu d'en créer une autre.
EOF
  exit 64
fi

KEYSTORE_FILE="app/upload-keystore.jks"
KEY_ALIAS="upload"
VALIDITY_DAYS=10000
KEY_PROPERTIES="key.properties"

if [[ -f "$KEYSTORE_FILE" ]]; then
  echo "❌ $KEYSTORE_FILE existe déjà. Génération interdite pour éviter de remplacer la clé d'upload."
  exit 1
fi

echo "⚠️  CRÉATION D'UNE NOUVELLE CLÉ D'UPLOAD GOOGLE PLAY"
echo "   À utiliser uniquement avant l'enregistrement de la première clé d'upload."
echo "   Tu vas devoir fournir un mot de passe robuste."
echo ""

keytool -genkey -v \
  -keystore "$KEYSTORE_FILE" \
  -storetype JKS \
  -alias "$KEY_ALIAS" \
  -keyalg RSA \
  -keysize 2048 \
  -validity "$VALIDITY_DAYS"

echo ""
read -rsp "🔐 Re-saisis le mot de passe du keystore : " STORE_PASS
echo ""
read -rsp "🔐 Re-saisis le mot de passe de la clé : " KEY_PASS
echo ""

cat > "$KEY_PROPERTIES" <<EOF
storePassword=$STORE_PASS
keyPassword=$KEY_PASS
keyAlias=$KEY_ALIAS
storeFile=../app/upload-keystore.jks
storeType=JKS
EOF
chmod 600 "$KEY_PROPERTIES" "$KEYSTORE_FILE"
unset STORE_PASS KEY_PASS

echo ""
echo "✅ Keystore créé : $KEYSTORE_FILE"
echo "✅ key.properties créé (non versionné)"
echo ""
echo "Étapes obligatoires maintenant :"
echo "  1. Sauvegarder immédiatement le keystore dans un coffre sécurisé hors GitHub."
echo "  2. Copier le matériel de signature dans Google Secret Manager."
echo "  3. Noter les empreintes SHA-1/SHA-256 du certificat d'upload."
echo "  4. Ne plus exécuter ce script après l'enregistrement de la clé dans Play Console."
echo "  5. Construire le Store bundle avec le workflow GitHub 'Build signed Android AAB (Google Play)'."

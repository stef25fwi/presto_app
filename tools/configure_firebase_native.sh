#!/usr/bin/env bash
# ── Configurer Firebase pour toutes les plateformes ──
# Génère google-services.json (Android), GoogleService-Info.plist (iOS),
# et met à jour firebase_options.dart.
#
# Pré-requis :
#   dart pub global activate flutterfire_cli
#   firebase login
#
# Usage : ./configure_firebase_native.sh

set -euo pipefail
cd "$(dirname "$0")/.."

PROJECT_ID="presto-app-74abe"
ANDROID_PACKAGE="fr.ilipresto.app"
IOS_BUNDLE="fr.ilipresto.app"

echo "🔥 Configuration Firebase pour $PROJECT_ID..."
echo ""

flutterfire configure \
  --project="$PROJECT_ID" \
  --platforms=android,ios,web \
  --android-package-name="$ANDROID_PACKAGE" \
  --ios-bundle-id="$IOS_BUNDLE" \
  --yes

echo ""
echo "✅ Fichiers générés :"
echo "   - android/app/google-services.json"
echo "   - ios/Runner/GoogleService-Info.plist"
echo "   - lib/firebase_options.dart (mis à jour)"
echo ""
echo "Prochaine étape : flutter build web / apk / ios"

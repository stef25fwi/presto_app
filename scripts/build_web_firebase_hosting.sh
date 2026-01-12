#!/bin/bash
set -euo pipefail

# Build Flutter Web pour Firebase Hosting (racine /)
# IMPORTANT: ne pas utiliser /presto_app/ ici, sinon les assets/routing cassent sur https://presto-app-74abe.web.app/

cd "$(dirname "$0")"

# Précondition: Flutter doit être disponible
if ! command -v flutter >/dev/null 2>&1; then
	echo "❌ Flutter n'est pas installé ou introuvable dans le PATH." >&2
	echo "   Installe Flutter SDK puis relancez ce script." >&2
	echo "   Doc: https://docs.flutter.dev/get-started/install" >&2
	exit 127
fi

echo "🏗️  Build Flutter Web (Firebase Hosting) ..."
flutter --version || true
flutter pub get

SHA="$(git rev-parse --short HEAD 2>/dev/null || echo local)"
BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')"
BUILD_TIME_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

echo "ℹ️  Defines: APP_BUILD_SHA=$SHA APP_BUILD_BRANCH=$BRANCH APP_BUILD_TIME=$BUILD_TIME_UTC"

flutter build web --release --base-href "/" \
	--dart-define=APP_BUILD_SHA="$SHA" \
	--dart-define=APP_BUILD_BRANCH="$BRANCH" \
	--dart-define=APP_BUILD_TIME="$BUILD_TIME_UTC"

echo "✅ OK: artefacts Firebase Hosting prêts dans ./build/web"

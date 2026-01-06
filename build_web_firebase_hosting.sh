#!/bin/bash
set -euo pipefail

# Build Flutter Web pour Firebase Hosting (racine /)
# IMPORTANT: ne pas utiliser /presto_app/ ici, sinon les assets/routing cassent sur https://presto-app-74abe.web.app/

cd "$(dirname "$0")"

echo "🏗️  Build Flutter Web (Firebase Hosting) ..."
flutter pub get
flutter build web --release --base-href "/"

echo "✅ OK: artefacts Firebase Hosting prêts dans ./build/web"

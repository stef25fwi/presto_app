#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

version_line="$(grep -E '^version:' pubspec.yaml | head -n 1 | sed -E 's/^version:[[:space:]]*//')"
app_version="${version_line%%+*}"
app_build_number="0"

if [[ "$version_line" == *"+"* ]]; then
  app_build_number="${version_line##*+}"
fi

app_build_sha="$(git rev-parse --short=12 HEAD 2>/dev/null || echo local)"
app_build_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')"
app_build_tag="$(git describe --tags --exact-match 2>/dev/null || git describe --tags --abbrev=0 2>/dev/null || echo '')"
origin_url="$(git config --get remote.origin.url 2>/dev/null || echo '')"
app_repository=""

if [[ -n "$origin_url" ]]; then
  app_repository="$(printf '%s\n' "$origin_url" | sed -E 's#^(git@github.com:|https://github.com/)##; s#\.git$##')"
fi

app_build_time="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Propage les secrets de build s'ils sont définis dans l'environnement.
# Sans ça, un build web local active aucun App Check et Firestore (en mode
# enforce) rejette toutes les lectures publiques avec PERMISSION_DENIED.
# Conventions :
#   - APPCHECK_RECAPTCHA_SITE_KEY      : reCAPTCHA Enterprise pour App Check Web
#   - FCM_WEB_VAPID_KEY                : VAPID key pour notifications web
#   - MARKETPLACE_RECAPTCHA_WEB_SITE_KEY : reCAPTCHA pour vérification humaine marketplace
extra_defines=()
if [[ -n "${APPCHECK_RECAPTCHA_SITE_KEY:-}" ]]; then
  extra_defines+=(--dart-define=APPCHECK_RECAPTCHA_SITE_KEY="$APPCHECK_RECAPTCHA_SITE_KEY")
fi
if [[ -n "${FCM_WEB_VAPID_KEY:-}" ]]; then
  extra_defines+=(--dart-define=FCM_WEB_VAPID_KEY="$FCM_WEB_VAPID_KEY")
fi
if [[ -n "${MARKETPLACE_RECAPTCHA_WEB_SITE_KEY:-}" ]]; then
  extra_defines+=(--dart-define=MARKETPLACE_RECAPTCHA_WEB_SITE_KEY="$MARKETPLACE_RECAPTCHA_WEB_SITE_KEY")
fi

# Trace minimale pour diagnostiquer un build sans App Check (Firestore 403).
appcheck_status="absent"
if [[ -n "${APPCHECK_RECAPTCHA_SITE_KEY:-}" ]]; then
  appcheck_status="present(${#APPCHECK_RECAPTCHA_SITE_KEY} chars)"
fi
echo "[flutter_with_build_stamp] APPCHECK_RECAPTCHA_SITE_KEY=$appcheck_status" >&2

exec flutter "$@" \
  --dart-define=APP_VERSION="$app_version" \
  --dart-define=APP_BUILD_NUMBER="$app_build_number" \
  --dart-define=APP_REPOSITORY="$app_repository" \
  --dart-define=APP_BUILD_SHA="$app_build_sha" \
  --dart-define=APP_BUILD_BRANCH="$app_build_branch" \
  --dart-define=APP_BUILD_TAG="$app_build_tag" \
  --dart-define=APP_BUILD_TIME="$app_build_time" \
  "${extra_defines[@]}"
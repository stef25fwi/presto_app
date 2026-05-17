#!/usr/bin/env bash
#
# check_recaptcha_keys.sh - Audit reCAPTCHA / App Check keys for presto_app.
#
# Verifie qu'une SEULE cle reCAPTCHA valide est utilisee partout :
#   1. les cles reCAPTCHA Enterprise enregistrees dans le projet Google Cloud
#   2. les cles eventuellement codees en dur dans le repo
#   3. la cle reellement embarquee dans le build web (build/web)
#
# Usage:
#   ./scripts/check_recaptcha_keys.sh
#
set -euo pipefail

PROJECT="presto-app-74abe"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEY_REGEX='6L[A-Za-z0-9_-]\{38,40\}'

echo "=================================================="
echo " Audit reCAPTCHA / App Check - projet $PROJECT"
echo "=================================================="

# --- 1. Cles reCAPTCHA Enterprise enregistrees dans Google Cloud -----------
echo
echo "1) Cles reCAPTCHA Enterprise du projet Google Cloud"
echo "---------------------------------------------------"
if command -v gcloud >/dev/null 2>&1; then
  mapfile -t GCP_KEYS < <(
    gcloud recaptcha keys list --project="$PROJECT" \
      --format="value(name)" 2>/dev/null || true
  )
  if [ "${#GCP_KEYS[@]}" -eq 0 ]; then
    echo "  (aucune cle trouvee, ou acces refuse - verifie 'gcloud auth login')"
  else
    for key in "${GCP_KEYS[@]}"; do
      key_id="${key##*/}"
      echo
      echo "  Cle: $key_id"
      gcloud recaptcha keys describe "$key_id" --project="$PROJECT" \
        --format="value(displayName, webSettings.allowedDomains, webSettings.integrationType)" \
        2>/dev/null | sed 's/^/    /' || echo "    (describe a echoue)"
    done
    echo
    echo "  => Nombre de cles reCAPTCHA Enterprise : ${#GCP_KEYS[@]}"
    if [ "${#GCP_KEYS[@]}" -gt 1 ]; then
      echo "  !! ATTENTION : plusieurs cles existent. Une seule doit etre"
      echo "     utilisee par l'app web. Les autres peuvent semer la confusion."
    fi
  fi
else
  echo "  gcloud absent. Installe le SDK Google Cloud, puis :"
  echo "    gcloud auth login"
  echo "    gcloud recaptcha keys list --project=$PROJECT"
fi

# --- 2. Cles codees en dur dans le repo ------------------------------------
echo
echo "2) Cles reCAPTCHA codees en dur dans le repo"
echo "--------------------------------------------"
REPO_HITS="$(
  grep -rEoh "$KEY_REGEX" "$REPO_ROOT" \
    --include='*.dart' --include='*.html' --include='*.js' \
    --include='*.json' --include='*.yaml' --include='*.yml' \
    --include='*.sh' --include='*.env' 2>/dev/null \
    | grep -v node_modules | sort -u || true
)"
if [ -z "$REPO_HITS" ]; then
  echo "  Aucune cle en dur (normal : elle vient de --dart-define au build)."
else
  echo "$REPO_HITS" | sed 's/^/  /'
  echo "  => $(echo "$REPO_HITS" | wc -l) cle(s) distincte(s) dans le repo."
fi

# --- 3. Cle embarquee dans le build web ------------------------------------
echo
echo "3) Cle embarquee dans le build web (build/web)"
echo "----------------------------------------------"
WEB_BUNDLE=""
for candidate in "$REPO_ROOT/build/web/main.dart.js" \
                 "$REPO_ROOT/build/web/flutter.js"; do
  [ -f "$candidate" ] && WEB_BUNDLE="$candidate" && break
done
if [ -z "$WEB_BUNDLE" ]; then
  echo "  Pas de build web. Genere-le d'abord :"
  echo "    flutter build web --release --dart-define=APPCHECK_RECAPTCHA_SITE_KEY=<cle>"
else
  BUILD_HITS="$(grep -Eoh "$KEY_REGEX" "$REPO_ROOT"/build/web/*.js 2>/dev/null \
    | sort -u || true)"
  if [ -z "$BUILD_HITS" ]; then
    echo "  !! AUCUNE cle dans le build => App Check NON configure."
    echo "     Le build a ete fait sans --dart-define=APPCHECK_RECAPTCHA_SITE_KEY."
  else
    echo "$BUILD_HITS" | sed 's/^/  /'
    COUNT="$(echo "$BUILD_HITS" | wc -l)"
    echo "  => $COUNT cle(s) dans le build."
    [ "$COUNT" -gt 1 ] && echo "  !! Plusieurs cles dans le build : anomalie."
  fi
fi

# --- Verdict ---------------------------------------------------------------
echo
echo "=================================================="
echo " Verdict"
echo "=================================================="
ALL_KEYS="$(printf '%s\n%s\n' "$REPO_HITS" "${BUILD_HITS:-}" \
  | grep -E "$KEY_REGEX" | sort -u || true)"
DISTINCT="$(echo "$ALL_KEYS" | grep -c . || true)"
if [ "$DISTINCT" -le 1 ]; then
  echo " OK : au plus une cle reCAPTCHA utilisee cote app."
else
  echo " PROBLEME : $DISTINCT cles distinctes detectees. Aligne-les sur UNE seule :"
  echo "$ALL_KEYS" | sed 's/^/   - /'
fi
echo
echo " Rappel : la cle utilisee par l'app (build/repo) doit etre la MEME que"
echo " celle enregistree dans Firebase Console > App Check > app Web, et que"
echo " le secret GitHub APPCHECK_RECAPTCHA_SITE_KEY."

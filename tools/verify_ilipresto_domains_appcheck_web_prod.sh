#!/usr/bin/env bash

set -u

grep_project() {
  grep -RIn \
    --exclude-dir=node_modules \
    --exclude-dir=.dart_tool \
    --exclude-dir=build \
    --exclude-dir=.git \
    --exclude-dir=dist \
    --exclude-dir=coverage \
    "$@"
}

grep_project_e() {
  grep -RInE \
    --exclude-dir=node_modules \
    --exclude-dir=.dart_tool \
    --exclude-dir=build \
    --exclude-dir=.git \
    --exclude-dir=dist \
    --exclude-dir=coverage \
    "$@"
}

main() {
  local root_dir="${1:-$PWD}"
  cd "$root_dir" || exit 1

  local out
  out="verify_ilipresto_domains_appcheck_$(date +%Y%m%d_%H%M%S).txt"

  {
    echo "=================================================="
    echo " VERIFICATION DOMAINS + APP CHECK + WEB PROD"
    echo "=================================================="

    echo ""
    echo "===== 1. FIREBASE CONFIG ====="
    grep_project_e "authDomain|projectId|storageBucket|messagingSenderId|appId" \
      lib/firebase_options.dart web/firebase-messaging-sw.js web/flutter_bootstrap.js 2>/dev/null || true

    echo ""
    echo "===== 2. HOSTS PROD ACCEPTES DANS LE WEB ====="
    grep_project_e "firebaseapp\.com|web\.app|ilipresto\.fr|www\.ilipresto\.fr|localhost|127\.0\.0\.1|github\.dev|github\.io" \
      web lib 2>/dev/null || true

    echo ""
    echo "===== 3. APP CHECK FLUTTER ====="
    grep_project_e "FirebaseAppCheck|ReCaptcha|ReCaptchaEnterpriseProvider|PlayIntegrity|AppAttest|AndroidProvider|AppleProvider|activate\(" \
      lib web 2>/dev/null || true

    echo ""
    echo "===== 4. FCM WEB / SERVICE WORKER ====="
    if [[ -f web/firebase-messaging-sw.js ]]; then
      echo "OK firebase-messaging-sw.js PRESENT"
    else
      echo "ERREUR firebase-messaging-sw.js ABSENT"
    fi

    grep_project_e "messaging|getToken|vapid|FCM_WEB_VAPID_KEY|firebase-messaging-sw" \
      lib web 2>/dev/null || true

    echo ""
    echo "===== 5. CHECK DOMAINE ILIPRESTO.FR DANS LE CODE ====="
    grep_project "ilipresto.fr" . 2>/dev/null || true

    echo ""
    echo "===== 6. CHECK WWW.ILIPRESTO.FR ====="
    grep_project "www.ilipresto.fr" . 2>/dev/null || true

    echo ""
    echo "===== 7. DOMAINES DEV A SUPPRIMER EN PROD ====="
    grep_project_e "github\.dev|app\.github\.dev|github\.io|localhost:|127\.0\.0\.1:" \
      web lib firebase.json 2>/dev/null || true

    echo ""
    echo "===== 8. FIRESTORE RULES OUVERTES ====="
    find . -name "firestore.rules" -exec grep -HnE \
      "allow read, write: if true|allow write: if true|allow read: if true" {} \; 2>/dev/null || true

    echo ""
    echo "===== 9. APP CHECK ENFORCEMENT ====="
    echo "VERIFIER DANS FIREBASE CONSOLE :"
    echo "- Firestore => ENFORCED quand tests OK"
    echo "- Storage => ENFORCED"
    echo "- Authentication => ENFORCED"
    echo "- Functions => ENFORCED si fonctions compatibles App Check"

    echo ""
    echo "===== 10. FLUTTER ANALYZE ====="
    flutter analyze || true

    echo ""
    echo "===== 11. BUILD WEB RELEASE ====="
    flutter build web --release \
      --dart-define=FCM_WEB_VAPID_KEY=test \
      2>&1 || true

    echo ""
    echo "===== 12. VERIFICATION BUILD FINAL ====="
    grep -RInE "github\.dev|localhost|MISSING_|firebaseapp\.com|web\.app|ilipresto\.fr" \
      build/web 2>/dev/null || true

    echo ""
    echo "===== 13. SCORE PROD ====="

    local sw
    local appcheck
    local rules

    sw=$([[ -f web/firebase-messaging-sw.js ]] && echo 1 || echo 0)
    appcheck=$(grep_project "FirebaseAppCheck" lib web 2>/dev/null | wc -l | tr -d ' ')
    rules=$(find . -name "firestore.rules" -exec grep -H "allow read, write: if true" {} \; | wc -l | tr -d ' ')

    echo "service_worker_present=$sw"
    echo "appcheck_hits=$appcheck"
    echo "open_rules=$rules"

    if [[ "$sw" = "1" ]]; then
      echo "OK: SERVICE WORKER WEB"
    else
      echo "BLOQUANT: SERVICE WORKER ABSENT"
    fi

    if [[ "$appcheck" != "0" ]]; then
      echo "OK: APP CHECK DETECTE"
    else
      echo "BLOQUANT: APP CHECK ABSENT"
    fi

    if [[ "$rules" = "0" ]]; then
      echo "OK: PAS DE REGLE FIRESTORE TOTALEMENT OUVERTE"
    else
      echo "BLOQUANT: REGLES FIRESTORE OUVERTES"
    fi

    echo ""
    echo "=================================================="
    echo " RAPPORT : $out"
    echo "=================================================="
  } | tee "$out"

  echo ""
  echo "Rapport genere: $out"
}

main "$@"
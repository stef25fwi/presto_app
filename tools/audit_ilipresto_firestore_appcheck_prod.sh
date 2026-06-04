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
    --exclude-dir=.next \
    --exclude-dir=.firebase \
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
    --exclude-dir=.next \
    --exclude-dir=.firebase \
    "$@"
}

run_diagnostic_command() {
  local label="$1"
  shift

  local output=""
  local status=0

  echo "--- $label ---"

  if output="$($@ 2>&1)"; then
    if [[ -n "$output" ]]; then
      printf '%s\n' "$output"
    else
      echo "INFO: aucune sortie"
    fi
  else
    status=$?
    if [[ -n "$output" ]]; then
      printf '%s\n' "$output"
    fi
    echo "INFO: commande en echec (code=$status)"
  fi
}

looks_like_ilipresto_root() {
  local dir_path="$1"
  [[ -d "$dir_path" ]] || return 1
  [[ -f "$dir_path/pubspec.yaml" ]] || return 1

  if grep -RIsqE "fr\.ilipresto\.app|ilipresto|e-libresto|elibresto" \
    "$dir_path/lib" \
    "$dir_path/ios" \
    "$dir_path/macos" \
    "$dir_path/android" \
    "$dir_path/web" \
    "$dir_path/firebase.json" \
    "$dir_path/.firebaserc" 2>/dev/null; then
    return 0
  fi

  return 1
}

resolve_ilipresto_root() {
  if [[ -n "${ILIPRESTO_ROOT:-}" ]] && looks_like_ilipresto_root "$ILIPRESTO_ROOT"; then
    printf '%s\n' "$ILIPRESTO_ROOT"
    return 0
  fi

  if looks_like_ilipresto_root "$PWD"; then
    printf '%s\n' "$PWD"
    return 0
  fi

  if [[ -d /workspaces/take3/ilipresto ]]; then
    printf '%s\n' /workspaces/take3/ilipresto
    return 0
  fi

  if [[ -d /workspaces/ilipresto ]]; then
    printf '%s\n' /workspaces/ilipresto
    return 0
  fi

  local pubspec_path
  while IFS= read -r pubspec_path; do
    [[ -z "$pubspec_path" ]] && continue
    local candidate_root
    candidate_root="$(dirname "$pubspec_path")"
    if looks_like_ilipresto_root "$candidate_root"; then
      printf '%s\n' "$candidate_root"
      return 0
    fi
  done < <(find /workspaces -maxdepth 4 -type f -name pubspec.yaml 2>/dev/null)

  return 1
}

parse_stage() {
  local raw_stage="${1:-full}"
  case "$raw_stage" in
    full|all)
      STAGE_KEY="full"
      STAGE_LABEL="COMPLET"
      ;;
    1|step1|step-1|context|config)
      STAGE_KEY="context"
      STAGE_LABEL="ETAPE 1/6 - CONTEXTE + CONFIG"
      ;;
    2|step2|step-2|firestore)
      STAGE_KEY="firestore"
      STAGE_LABEL="ETAPE 2/6 - FIRESTORE"
      ;;
    3|step3|step-3|appcheck|auth)
      STAGE_KEY="appcheck"
      STAGE_LABEL="ETAPE 3/6 - APP CHECK + AUTH"
      ;;
    4|step4|step-4|runtime|functions)
      STAGE_KEY="runtime"
      STAGE_LABEL="ETAPE 4/6 - RUNTIME + FUNCTIONS"
      ;;
    5|step5|step-5|flutter|build)
      STAGE_KEY="flutter"
      STAGE_LABEL="ETAPE 5/6 - FLUTTER + BUILD"
      ;;
    6|step6|step-6|summary|synthese)
      STAGE_KEY="summary"
      STAGE_LABEL="ETAPE 6/6 - SYNTHESE"
      ;;
    *)
      echo "Usage: $0 [full|context|firestore|appcheck|runtime|flutter|summary]"
      exit 1
      ;;
  esac
}

stage_slug() {
  case "$STAGE_KEY" in
    full) printf '%s\n' "firestore_appcheck_prod" ;;
    context) printf '%s\n' "step1_context_config" ;;
    firestore) printf '%s\n' "step2_firestore" ;;
    appcheck) printf '%s\n' "step3_appcheck_auth" ;;
    runtime) printf '%s\n' "step4_runtime_functions" ;;
    flutter) printf '%s\n' "step5_flutter_build" ;;
    summary) printf '%s\n' "step6_summary" ;;
  esac
}

setup_project_context() {
  ROOT_DIR="$(resolve_ilipresto_root)"
  if [[ -z "$ROOT_DIR" ]]; then
    echo "ERREUR: impossible de localiser le projet IliPresto dans /workspaces"
    exit 1
  fi

  cd "$ROOT_DIR" || exit 1

  PROJECT_ID="$(grep -Rho "projectId: '[^']*'\|projectId: \"[^\"]*\"" lib/firebase_options.dart 2>/dev/null | head -1 | sed -E "s/.*projectId: ['\"]([^'\"]+)['\"].*/\1/")"
  if [[ -z "$PROJECT_ID" ]]; then
    PROJECT_ID="$(gcloud config get-value project 2>/dev/null || true)"
  fi

  OUT="audit_ilipresto_$(stage_slug)_$(date +%Y%m%d_%H%M%S).txt"
}

print_banner() {
  echo "=================================================="
  echo " AUDIT ILIPRESTO - FIRESTORE / APP CHECK / DOMAINES / PROD"
  echo " STAGE: $STAGE_LABEL"
  echo " PROJECT_ID: $PROJECT_ID"
  echo " DATE: $(date)"
  echo "=================================================="
  echo ""
}

print_footer() {
  echo ""
  echo "=================================================="
  echo " FIN AUDIT - RAPPORT: $OUT"
  echo "=================================================="
}

run_context_sections() {
  echo "===== 1. CONTEXTE GCP / FIREBASE ====="
  pwd
  git branch --show-current || true
  git status --short || true
  gcloud config list --format="text" || true
  firebase projects:list || true
  firebase use || true
  echo ""
  echo "===== 2. FICHIERS FIREBASE / APP CHECK PRESENTS ====="
  find . -maxdepth 5 \( \
  -name "firebase.json" -o \
  -name "firestore.rules" -o \
  -name "firestore.indexes.json" -o \
  -name "firebase_options.dart" -o \
  -name "google-services.json" -o \
  -name "GoogleService-Info.plist" -o \
  -name "firebase-messaging-sw.js" \
  \) -print
  echo ""
  echo "===== 3. CONFIG FIREBASE_OPTIONS - PROJECT / APPS / DOMAINES ====="
  grep_project "apiKey\|appId\|messagingSenderId\|projectId\|authDomain\|storageBucket" lib/firebase_options.dart web firebase.json .firebaserc 2>/dev/null || true
  echo ""
  echo "===== 4. DOMAINES DECLARES DANS LE CODE / CONFIG WEB ====="
  grep_project_e "authDomain|authorizedDomains|localhost|127\.0\.0\.1|firebaseapp\.com|web\.app|appspot\.com|pages\.dev|vercel\.app|netlify\.app|ilipresto|elibresto|e-libresto" \
  lib web android ios firebase.json .firebaserc 2>/dev/null || true
}

run_firestore_sections() {
  echo "===== 5. FIRESTORE RULES - AUDIT COMPLET ====="
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    echo ""
    echo "----- $f -----"
    nl -ba "$f" | sed -n '1,260p'
  done < <(find . -name "firestore.rules" -print)
  echo ""
  echo "===== 6. FIRESTORE INDEXES ====="
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    echo ""
    echo "----- $f -----"
    cat "$f"
  done < <(find . -name "firestore.indexes.json" -print)
  echo ""
  echo "===== 7. REFERENCES FIRESTORE DANS LE CODE ====="
  grep_project_e "FirebaseFirestore|collection\(|doc\(|snapshots\(|where\(|orderBy\(|limit\(|FieldValue|runTransaction|WriteBatch|batch\(" lib functions web 2>/dev/null || true
  echo ""
  echo "===== 8. COLLECTIONS CRITIQUES ILIPRESTO DETECTEES ====="
  grep_project_e "offers|annonces|messages|conversations|favorites|users|admins|reports|notifications|categories|transactions|reviews|ratings|userOffers|managedOffers|publicProfiles" lib functions firestore.rules 2>/dev/null || true
  echo ""
  echo "===== 9. FIRESTORE RULES - RISQUES PROD ====="
  RULE_FILES="$(find . -name "firestore.rules" -print)"
  grep_project_e "allow read, write: if true|allow read: if true|allow write: if true|request.auth == null|debug|TODO|FIXME|admin|superadmin|isAdmin|claims|customClaims" $RULE_FILES lib functions 2>/dev/null || true
}

run_appcheck_sections() {
  echo "===== 10. FIREBASE APP CHECK - CODE FLUTTER / WEB / NATIF ====="
  grep_project_e "FirebaseAppCheck|activate|ReCaptcha|ReCaptchaEnterpriseProvider|AndroidProvider|AppleProvider|PlayIntegrity|AppAttest|debugProvider|X-Firebase-AppCheck|appCheckToken" \
  lib web android ios functions 2>/dev/null || true
  echo ""
  echo "===== 11. FIREBASE APP CHECK - APPS DECLAREES COTE FIREBASE ====="
  run_diagnostic_command "firebase apps:list" firebase apps:list --project "$PROJECT_ID"
  echo ""
  echo "===== 12. APP CHECK - CONFIG VIA GCLOUD / FIREBASE SI DISPONIBLE ====="
  run_diagnostic_command "gcloud firebase appcheck apps list" gcloud firebase appcheck apps list --project="$PROJECT_ID"
  run_diagnostic_command "gcloud firebase appcheck services list" gcloud firebase appcheck services list --project="$PROJECT_ID"
  echo ""
  echo "===== 13. APP CHECK - VERIFICATION ENFORCEMENT SERVICES ====="
  run_diagnostic_command "appcheck firestore" gcloud firebase appcheck services describe firestore.googleapis.com --project="$PROJECT_ID"
  run_diagnostic_command "appcheck storage" gcloud firebase appcheck services describe firebasestorage.googleapis.com --project="$PROJECT_ID"
  run_diagnostic_command "appcheck identitytoolkit" gcloud firebase appcheck services describe identitytoolkit.googleapis.com --project="$PROJECT_ID"
  run_diagnostic_command "appcheck cloudfunctions" gcloud firebase appcheck services describe cloudfunctions.googleapis.com --project="$PROJECT_ID"
  echo ""
  echo "===== 14. AUTHORIZED DOMAINS AUTH FIREBASE - TENTATIVE GCLOUD ====="
  run_diagnostic_command "gcloud identity-platform oauth-domains list" gcloud identity-platform oauth-domains list --project="$PROJECT_ID"
  echo ""
  echo "===== 15. AUTH / PROVIDERS / WEB CONFIG ====="
  run_diagnostic_command "gcloud identity-platform config describe" gcloud identity-platform config describe --project="$PROJECT_ID"
  grep_project_e "signInWith|GoogleAuthProvider|AppleAuthProvider|phone|email|authStateChanges|FirebaseAuth|currentUser" lib web 2>/dev/null || true
}

run_runtime_sections() {
  echo "===== 16. FCM / PUSH WEB - VAPID / SERVICE WORKER / TOKEN ====="
  grep_project_e "FirebaseMessaging|messaging|getToken|vapid|VAPID|firebase-messaging-sw|onBackgroundMessage|onMessage|requestPermission|new_message|offer_update|conversationId" \
  lib web firebase.json 2>/dev/null || true
  if [[ -f web/firebase-messaging-sw.js ]]; then
    nl -ba web/firebase-messaging-sw.js | sed -n '1,220p'
  else
    echo "BLOQUANT POSSIBLE: web/firebase-messaging-sw.js absent"
  fi
  echo ""
  echo "===== 17. STORAGE RULES / BUCKETS ====="
  find . -name "storage.rules" -print -exec sh -c 'echo "----- $1 -----"; nl -ba "$1" | sed -n "1,260p"' sh {} \;
  gsutil ls -p "$PROJECT_ID" 2>/dev/null || true
  echo ""
  echo "===== 18. FUNCTIONS / CLOUD RUN / LOGS ERREURS RECENTES ====="
  firebase functions:list --project "$PROJECT_ID" 2>/dev/null || true
  gcloud functions list --project="$PROJECT_ID" --format="table(name,state,environment,region)" 2>/dev/null || true
  gcloud run services list --project="$PROJECT_ID" --format="table(metadata.name,status.url,metadata.labels.location)" 2>/dev/null || true
  gcloud logging read 'severity>=ERROR' --project="$PROJECT_ID" --limit=50 --format="value(timestamp,resource.type,resource.labels.function_name,resource.labels.service_name,textPayload,jsonPayload.message)" 2>/dev/null || true
}

run_flutter_sections() {
  echo "===== 19. FLUTTER / DEPENDANCES / ANALYSE ====="
  flutter --version || true
  flutter pub outdated 2>/dev/null || true
  flutter analyze || true
  flutter test --reporter expanded || true
  echo ""
  echo "===== 20. BUILD WEB PROD AVEC CHECK DART-DEFINES ====="
  echo "Variables attendues possibles: FCM_WEB_VAPID_KEY, MAPBOX_ACCESS_TOKEN, API_BASE_URL"
  flutter build web --release \
    --dart-define=FCM_WEB_VAPID_KEY="${FCM_WEB_VAPID_KEY:-MISSING_FCM_WEB_VAPID_KEY}" \
    --dart-define=MAPBOX_ACCESS_TOKEN="${MAPBOX_ACCESS_TOKEN:-MISSING_MAPBOX_ACCESS_TOKEN}" \
    2>&1 || true
  echo ""
  echo "===== 21. VERIFICATION BUILD OUTPUT / ASSETS / SERVICE WORKER ====="
  find build/web -maxdepth 2 -type f | sed -n '1,220p' || true
  grep -RInE "MISSING_FCM_WEB_VAPID_KEY|MISSING_MAPBOX_ACCESS_TOKEN|firebase-messaging-sw|appCheck|vapid|authDomain" build/web 2>/dev/null || true
}

run_summary_sections() {
  echo "===== 22. DIAGNOSTIC AUTOMATIQUE PROD 10/10 ====="
  RULES_OPEN="$(grep_project_e "allow read, write: if true|allow write: if true" $(find . -name "firestore.rules" -print) 2>/dev/null | wc -l | tr -d ' ')"
  SW_PRESENT="$([[ -f web/firebase-messaging-sw.js ]] && echo YES || echo NO)"
  APP_CHECK_CODE="$(grep_project_e "FirebaseAppCheck|ReCaptcha|PlayIntegrity|AppAttest|AndroidProvider|AppleProvider" lib web 2>/dev/null | wc -l | tr -d ' ')"
  VAPID_CODE="$(grep_project_e "FCM_WEB_VAPID_KEY|vapid|VAPID|getToken" lib web 2>/dev/null | wc -l | tr -d ' ')"
  FIREBASE_OPTIONS="$([[ -f lib/firebase_options.dart ]] && echo YES || echo NO)"
  ANALYZE_OK="$(flutter analyze >/tmp/ilipresto_analyze_check.log 2>&1 && echo YES || echo NO)"
  echo "firestore_rules_open_count=$RULES_OPEN"
  echo "firebase_options_present=$FIREBASE_OPTIONS"
  echo "web_fcm_service_worker_present=$SW_PRESENT"
  echo "app_check_code_hits=$APP_CHECK_CODE"
  echo "vapid_code_hits=$VAPID_CODE"
  echo "flutter_analyze_ok=$ANALYZE_OK"
  echo ""
  echo "===== 23. REPARATIONS RECOMMANDEES PRIORISEES ====="
  if [[ "$RULES_OPEN" != "0" ]]; then
    echo "BLOQUANT P0: regles Firestore trop ouvertes detectees. Remplacer tout allow true par regles basees sur request.auth, ownerId, roles admin/superadmin et validation resource.data."
  else
    echo "OK: pas de regle Firestore totalement ouverte detectee par grep."
  fi
  if [[ "$SW_PRESENT" = "NO" ]]; then
    echo "BLOQUANT P0: service worker FCM web absent. Creer web/firebase-messaging-sw.js pour les notifications background."
  else
    echo "OK: service worker FCM web present."
  fi
  if [[ "$APP_CHECK_CODE" = "0" ]]; then
    echo "BLOQUANT P0: App Check non detecte dans le code Flutter. Ajouter FirebaseAppCheck.instance.activate() avec providers Web/Android/iOS."
  else
    echo "OK: code App Check detecte."
  fi
  if [[ "$VAPID_CODE" = "0" ]]; then
    echo "BLOQUANT P1: VAPID web non detecte. Ajouter recuperation token FCM Web via vapidKey fourni en --dart-define=FCM_WEB_VAPID_KEY."
  else
    echo "OK: logique VAPID/FCM detectee."
  fi
  if [[ "$ANALYZE_OK" = "NO" ]]; then
    echo "BLOQUANT P1: flutter analyze echoue. Voir /tmp/ilipresto_analyze_check.log et section analyse ci-dessus."
  else
    echo "OK: flutter analyze passe."
  fi
  echo ""
  echo "===== 24. CHECKLIST PROD 10/10 ILIPRESTO ====="
  cat <<'CHECKLIST'
[ ] Firestore rules: aucun allow true global.
[ ] Firestore rules: users/{uid} lisible/modifiable uniquement par uid ou admin.
[ ] Firestore rules: offers validees avec ownerId == request.auth.uid sur create.
[ ] Firestore rules: conversations/messages proteges par participants.
[ ] Firestore rules: favorites proteges par userId == request.auth.uid.
[ ] Firestore rules: admin/superadmin bases sur custom claims ou collection roles verrouillee.
[ ] Firestore indexes: toutes les requetes where + orderBy utilisees par home/je consulte/messages sont indexees.
[ ] App Check active en code Flutter.
[ ] App Check enforcement active Firebase pour Firestore, Storage, Functions.
[ ] Web Auth domains declares: localhost dev + domaine prod + firebaseapp/web.app si utilises.
[ ] FCM Web: firebase-messaging-sw.js present.
[ ] FCM Web: FCM_WEB_VAPID_KEY injecte au build prod.
[ ] Notifications: payload contient type + conversationId/offerId selon route.
[ ] Storage rules alignees avec avatars, photos offres, pieces jointes messages.
[ ] flutter analyze OK.
[ ] flutter test OK ou tests Firebase correctement mockes.
[ ] flutter build web --release OK sans placeholder MISSING_*.
CHECKLIST
}

run_selected_stage() {
  case "$STAGE_KEY" in
    full)
      run_context_sections
      echo ""
      run_firestore_sections
      echo ""
      run_appcheck_sections
      echo ""
      run_runtime_sections
      echo ""
      run_flutter_sections
      echo ""
      run_summary_sections
      ;;
    context) run_context_sections ;;
    firestore) run_firestore_sections ;;
    appcheck) run_appcheck_sections ;;
    runtime) run_runtime_sections ;;
    flutter) run_flutter_sections ;;
    summary) run_summary_sections ;;
  esac
}

main() {
  if [[ "${1:-}" == "--stage" ]]; then
    parse_stage "${2:-full}"
  else
    parse_stage "${1:-full}"
  fi

  setup_project_context

  {
    print_banner
    run_selected_stage
    print_footer
  } | tee "$OUT"

  echo ""
  echo "Rapport genere: $OUT"
}

main "$@"

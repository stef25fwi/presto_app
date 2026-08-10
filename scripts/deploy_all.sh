#!/usr/bin/env bash
# deploy_all.sh — Déploiement complet iliprestō avec certification Brevo.
# Usage : bash scripts/deploy_all.sh

set -euo pipefail

PROJECT="presto-app-74abe"
WEBHOOK_URL="${WEBHOOK_URL:-https://europe-west1-${PROJECT}.cloudfunctions.net/handleEmailProviderWebhook}"
export WEBHOOK_URL

ok()   { echo "  ✓ $1"; }
step() { echo; echo "=== $1 ==="; }

if [ -z "${BREVO_API_KEY:-}" ]; then
  read -rsp "Brevo API key : " BREVO_API_KEY; echo
fi

if [ -z "${BREVO_WEBHOOK_SECRET:-}" ]; then
  BREVO_WEBHOOK_SECRET="$(firebase functions:secrets:access BREVO_WEBHOOK_SECRET \
    --project "$PROJECT" 2>/dev/null || true)"
fi
if [ -z "${BREVO_WEBHOOK_SECRET:-}" ]; then
  BREVO_WEBHOOK_SECRET="$(python3 -c 'import secrets; print(secrets.token_urlsafe(48))')"
  echo "  → Nouveau secret webhook généré sans affichage dans le terminal."
fi

if [ -z "${BREVO_API_KEY:-}" ] || [ -z "${BREVO_WEBHOOK_SECRET:-}" ]; then
  echo "Configuration Brevo incomplète." >&2
  exit 2
fi
export BREVO_API_KEY BREVO_WEBHOOK_SECRET

step "1/7 · Build et tests Functions"
npm --prefix functions ci
npm --prefix functions run build
npm --prefix functions test
ok "Build et tests backend validés"

step "2/7 · Secrets Firebase Brevo"
printf '%s' "$BREVO_API_KEY" | firebase functions:secrets:set BREVO_API_KEY \
  --project "$PROJECT" --force >/dev/null
printf '%s' "$BREVO_WEBHOOK_SECRET" | firebase functions:secrets:set BREVO_WEBHOOK_SECRET \
  --project "$PROJECT" --force >/dev/null
firebase functions:secrets:access BREVO_API_KEY --project "$PROJECT" >/dev/null
firebase functions:secrets:access BREVO_WEBHOOK_SECRET --project "$PROJECT" >/dev/null
ok "Secrets Brevo présents et accessibles"

step "3/7 · Firestore indexes"
firebase deploy --only firestore:indexes --project "$PROJECT" --force
ok "Index Firestore déployés"

step "4/7 · Cloud Functions"
firebase deploy --only functions --project "$PROJECT" --force
ok "Cloud Functions déployées"

step "5/7 · Provisioning webhook Brevo sécurisé"
bash scripts/create_brevo_webhook.sh
ok "Webhook transactionnel Brevo conforme"

step "6/7 · Smoke test webhook production"
node functions/scripts/brevo_webhook_smoke_test.mjs \
  --url "$WEBHOOK_URL" \
  --secret "$BREVO_WEBHOOK_SECRET"
ok "Webhook production accepte Bearer et refuse les accès invalides"

step "7/7 · Audit Brevo production"
AUDIT_ARGS=(
  --domain ilipresto.fr
  --sender noreply@ilipresto.fr
  --reply-to contact@ilipresto.fr
  --webhook-url "$WEBHOOK_URL"
  --output quality/brevo-production-certification.json
)
if [ "${RUN_BREVO_E2E:-false}" = "true" ]; then
  AUDIT_ARGS+=(--e2e --canary "${BREVO_CANARY_RECIPIENT:-contact@ilipresto.fr}")
fi
node functions/scripts/brevo_production_audit.mjs "${AUDIT_ARGS[@]}"
ok "Audit Brevo terminé"

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Déploiement iliprestō terminé."
echo " Rapport Brevo : quality/brevo-production-certification.json"
if [ "${RUN_BREVO_E2E:-false}" != "true" ]; then
  echo " Note : relancer avec RUN_BREVO_E2E=true pour certifier la livraison réelle via webhook."
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

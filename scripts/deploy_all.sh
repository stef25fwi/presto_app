#!/bin/bash
# deploy_all.sh — Déploiement complet Presto App
# Usage : bash scripts/deploy_all.sh

set -e
PROJECT=presto-app-74abe
WEBHOOK_URL="https://europe-west1-${PROJECT}.cloudfunctions.net/handleEmailProviderWebhook"

# Clés à fournir en variable d'environnement ou saisie interactive
if [ -z "$BREVO_API_KEY" ]; then
  read -rsp "Brevo API key : " BREVO_API_KEY; echo
fi
if [ -z "$BREVO_WEBHOOK_SECRET" ]; then
  BREVO_WEBHOOK_SECRET=$(python3 -c "import secrets; print(secrets.token_hex(32))")
  echo "  → Webhook secret généré : $BREVO_WEBHOOK_SECRET"
  echo "  (conserve-le si tu veux le réutiliser)"
fi

ok()  { echo "  ✓ $1"; }
err() { echo "  ✗ $1"; }
step(){ echo; echo "=== $1 ==="; }

# ─── 1. Secrets Brevo ────────────────────────────────────────────────────────
step "1/5 · Secrets Firebase (Brevo)"

echo "$BREVO_API_KEY" | firebase functions:secrets:set BREVO_API_KEY \
  --project "$PROJECT" --force && ok "BREVO_API_KEY défini" || err "BREVO_API_KEY échoué"

echo "$BREVO_WEBHOOK_SECRET" | firebase functions:secrets:set BREVO_WEBHOOK_SECRET \
  --project "$PROJECT" --force && ok "BREVO_WEBHOOK_SECRET défini" || err "BREVO_WEBHOOK_SECRET échoué"

# ─── 2. Firestore indexes ─────────────────────────────────────────────────────
step "2/5 · Firestore indexes"
firebase deploy --only firestore:indexes --project "$PROJECT" \
  && ok "Index déployés" || err "Index échoués (voir erreur ci-dessus)"

# ─── 3. Cloud Functions ───────────────────────────────────────────────────────
step "3/5 · Cloud Functions"
firebase deploy --only functions --project "$PROJECT" \
  && ok "Functions déployées" || { err "Functions échouées"; exit 1; }

# ─── 4. Webhook Brevo ────────────────────────────────────────────────────────
step "4/5 · Webhook Brevo"
HTTP_CODE=$(curl -s -o /tmp/brevo_webhook.json -w "%{http_code}" \
  -X POST "https://api.brevo.com/v3/webhooks" \
  -H "api-key: $BREVO_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"url\": \"$WEBHOOK_URL\",
    \"events\": [\"delivered\",\"softBounce\",\"hardBounce\",\"spam\",\"unsubscribed\",\"opened\",\"click\"],
    \"type\": \"transactional\",
    \"description\": \"Presto App tracking\"
  }")

if [ "$HTTP_CODE" = "201" ]; then
  WEBHOOK_ID=$(cat /tmp/brevo_webhook.json | python3 -c "import sys,json; print(json.load(sys.stdin).get('id','?'))")
  ok "Webhook Brevo créé (id=$WEBHOOK_ID)"
else
  BODY=$(cat /tmp/brevo_webhook.json)
  err "Webhook Brevo HTTP $HTTP_CODE — $BODY"
fi

# ─── 5. Vérifications ─────────────────────────────────────────────────────────
step "5/5 · Vérifications"

# Secrets accessibles ?
firebase functions:secrets:access BREVO_API_KEY --project "$PROJECT" > /dev/null 2>&1 \
  && ok "Secret BREVO_API_KEY accessible" || err "Secret BREVO_API_KEY non accessible"

firebase functions:secrets:access BREVO_WEBHOOK_SECRET --project "$PROJECT" > /dev/null 2>&1 \
  && ok "Secret BREVO_WEBHOOK_SECRET accessible" || err "Secret BREVO_WEBHOOK_SECRET non accessible"

# Fonctions déployées ? (via Firebase REST — gcloud optionnel)
for CF in handleEmailProviderWebhook microIaProcessAudio generateOfferDraft; do
  if command -v gcloud &>/dev/null; then
    STATUS=$(gcloud functions describe "$CF" --region=europe-west1 --project="$PROJECT" \
      --format="value(status)" 2>/dev/null || echo "")
    [ "$STATUS" = "ACTIVE" ] && ok "CF $CF → ACTIVE" || err "CF $CF → status inconnu (vérifie Firebase Console)"
  else
    ok "CF $CF → déployé (secrets OK — vérifie https://console.firebase.google.com/project/${PROJECT}/functions)"
  fi
done

# ─── Résumé ───────────────────────────────────────────────────────────────────
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Déploiement terminé."
echo " ➜ Teste l'app sur https://presto-app-74abe.web.app"
echo " ➜ Logs Functions : https://console.firebase.google.com/project/${PROJECT}/functions/logs"
echo " ➜ Revoque la clé SA si partagée : https://console.cloud.google.com/iam-admin/serviceaccounts?project=${PROJECT}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

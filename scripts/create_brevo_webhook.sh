#!/usr/bin/env bash
set -euo pipefail

URL="${WEBHOOK_URL:-https://europe-west1-presto-app-74abe.cloudfunctions.net/handleEmailProviderWebhook}"

if [ -z "${BREVO_API_KEY:-}" ]; then
  read -rsp "Brevo API key : " BREVO_API_KEY; echo
fi
if [ -z "${BREVO_WEBHOOK_SECRET:-}" ]; then
  read -rsp "Brevo webhook bearer secret : " BREVO_WEBHOOK_SECRET; echo
fi

if [ -z "$BREVO_API_KEY" ] || [ -z "$BREVO_WEBHOOK_SECRET" ]; then
  echo "BREVO_API_KEY et BREVO_WEBHOOK_SECRET sont obligatoires." >&2
  exit 2
fi

export URL BREVO_WEBHOOK_SECRET
PAYLOAD="$(python3 - <<'PY'
import json, os
print(json.dumps({
    "url": os.environ["URL"],
    "events": [
        "sent", "delivered", "hardBounce", "softBounce", "blocked",
        "spam", "invalid", "deferred", "click", "opened",
        "uniqueOpened", "unsubscribed",
    ],
    "type": "transactional",
    "description": "iliprestō transactional email tracking",
    "batched": False,
    "auth": {
        "type": "bearer",
        "token": os.environ["BREVO_WEBHOOK_SECRET"],
    },
}, separators=(",", ":")))
PY
)"

WEBHOOKS="$(curl --fail-with-body --silent --show-error \
  -H "accept: application/json" \
  -H "api-key: $BREVO_API_KEY" \
  "https://api.brevo.com/v3/webhooks?type=transactional")"

export WEBHOOKS
WEBHOOK_ID="$(python3 - <<'PY'
import json, os
url = os.environ["URL"]
data = json.loads(os.environ["WEBHOOKS"])
for hook in data.get("webhooks", []):
    if hook.get("url") == url and hook.get("type") == "transactional":
        print(hook.get("id", ""))
        break
PY
)"

if [ -n "$WEBHOOK_ID" ]; then
  echo "Mise à jour du webhook Brevo existant id=$WEBHOOK_ID"
  curl --fail-with-body --silent --show-error \
    -X PUT "https://api.brevo.com/v3/webhooks/$WEBHOOK_ID" \
    -H "accept: application/json" \
    -H "api-key: $BREVO_API_KEY" \
    -H "Content-Type: application/json" \
    --data "$PAYLOAD" >/dev/null
else
  echo "Création du webhook Brevo transactionnel"
  CREATED="$(curl --fail-with-body --silent --show-error \
    -X POST "https://api.brevo.com/v3/webhooks" \
    -H "accept: application/json" \
    -H "api-key: $BREVO_API_KEY" \
    -H "Content-Type: application/json" \
    --data "$PAYLOAD")"
  export CREATED
  WEBHOOK_ID="$(python3 - <<'PY'
import json, os
print(json.loads(os.environ["CREATED"]).get("id", ""))
PY
)"
fi

if [ -z "$WEBHOOK_ID" ]; then
  echo "Impossible de déterminer l'identifiant du webhook Brevo." >&2
  exit 3
fi

DETAIL="$(curl --fail-with-body --silent --show-error \
  -H "accept: application/json" \
  -H "api-key: $BREVO_API_KEY" \
  "https://api.brevo.com/v3/webhooks/$WEBHOOK_ID")"
export DETAIL
python3 - <<'PY'
import json, os, sys
hook = json.loads(os.environ["DETAIL"])
required = {
    "sent", "delivered", "hardBounce", "softBounce", "blocked", "spam",
    "invalid", "deferred", "click", "opened", "uniqueOpened", "unsubscribed",
}
actual = set(hook.get("events") or [])
errors = []
if hook.get("url") != os.environ["URL"]:
    errors.append("URL incorrecte")
if hook.get("type") != "transactional":
    errors.append("type non transactionnel")
if not required.issubset(actual):
    errors.append("événements manquants: " + ",".join(sorted(required - actual)))
auth = hook.get("auth") or {}
if str(auth.get("type", "")).lower() != "bearer":
    errors.append("auth Bearer absente")
if errors:
    print("Webhook Brevo non conforme: " + " ; ".join(errors), file=sys.stderr)
    sys.exit(4)
print(f"Webhook Brevo conforme id={hook.get('id')} auth=bearer events={len(actual)}")
PY

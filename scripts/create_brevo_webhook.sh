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
read -r CREATE_PAYLOAD UPDATE_PAYLOAD < <(python3 - <<'PY'
import json, os
common = {
    "url": os.environ["URL"],
    "events": [
        "sent", "delivered", "hardBounce", "softBounce", "blocked",
        "spam", "invalid", "deferred", "click", "opened",
        "uniqueOpened", "unsubscribed",
    ],
    "description": "iliprestō transactional email tracking",
    "batched": False,
    "auth": {
        "type": "bearer",
        "token": os.environ["BREVO_WEBHOOK_SECRET"],
    },
}
create = {**common, "type": "transactional"}
# Brevo's update schema does not accept the immutable webhook `type` field.
print(json.dumps(create, separators=(",", ":")), json.dumps(common, separators=(",", ":")))
PY
)

WEBHOOKS="$(curl --fail-with-body --silent --show-error \
  -H "accept: application/json" \
  -H "api-key: $BREVO_API_KEY" \
  "https://api.brevo.com/v3/webhooks?type=transactional")"

export WEBHOOKS
MATCHING_IDS="$(python3 - <<'PY'
import json, os
url = os.environ["URL"]
data = json.loads(os.environ["WEBHOOKS"])
ids = [str(h.get("id")) for h in data.get("webhooks", [])
       if h.get("url") == url and h.get("type") == "transactional" and h.get("id") is not None]
print(" ".join(ids))
PY
)"

WEBHOOK_ID="${MATCHING_IDS%% *}"
if [ "$MATCHING_IDS" = "$WEBHOOK_ID" ]; then
  EXTRA_IDS=""
else
  EXTRA_IDS="${MATCHING_IDS#* }"
fi

if [ -n "$WEBHOOK_ID" ]; then
  echo "Mise à jour du webhook Brevo existant id=$WEBHOOK_ID"
  curl --fail-with-body --silent --show-error \
    -X PUT "https://api.brevo.com/v3/webhooks/$WEBHOOK_ID" \
    -H "accept: application/json" \
    -H "api-key: $BREVO_API_KEY" \
    -H "Content-Type: application/json" \
    --data "$UPDATE_PAYLOAD" >/dev/null
else
  echo "Création du webhook Brevo transactionnel"
  CREATED="$(curl --fail-with-body --silent --show-error \
    -X POST "https://api.brevo.com/v3/webhooks" \
    -H "accept: application/json" \
    -H "api-key: $BREVO_API_KEY" \
    -H "Content-Type: application/json" \
    --data "$CREATE_PAYLOAD")"
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

# Older deployment scripts created a new unauthenticated webhook on each run.
# Keep one canonical hook and remove duplicate hooks targeting the same URL.
if [ -n "$EXTRA_IDS" ]; then
  for duplicate_id in $EXTRA_IDS; do
    echo "Suppression du webhook Brevo dupliqué id=$duplicate_id"
    curl --fail-with-body --silent --show-error \
      -X DELETE "https://api.brevo.com/v3/webhooks/$duplicate_id" \
      -H "accept: application/json" \
      -H "api-key: $BREVO_API_KEY" >/dev/null
  done
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
    "delivered", "hardBounce", "softBounce", "blocked", "spam",
    "invalid", "deferred", "click", "opened", "uniqueOpened", "unsubscribed",
}
actual = set(hook.get("events") or [])
errors = []
if hook.get("url") != os.environ["URL"]:
    errors.append("URL incorrecte")
if hook.get("type") != "transactional":
    errors.append("type non transactionnel")
if not ({"sent", "request"} & actual):
    errors.append("événement sent/request manquant")
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

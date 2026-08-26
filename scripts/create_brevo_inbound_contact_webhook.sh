#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${INBOUND_DOMAIN:-inbound.ilipresto.fr}"
URL="${INBOUND_WEBHOOK_URL:-https://europe-west1-presto-app-74abe.cloudfunctions.net/handleInboundContactEmailWebhook}"

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

export DOMAIN URL BREVO_WEBHOOK_SECRET
mapfile -t PAYLOADS < <(python3 - <<'PY'
import json, os
common = {
    "url": os.environ["URL"],
    "events": ["inboundEmailProcessed"],
    "domain": os.environ["DOMAIN"],
    "description": "iliprestō contact inbox notifications",
    "batched": False,
    "auth": {
        "type": "bearer",
        "token": os.environ["BREVO_WEBHOOK_SECRET"],
    },
}
print(json.dumps({**common, "type": "inbound"}, separators=(",", ":")))
print(json.dumps(common, separators=(",", ":")))
PY
)
CREATE_PAYLOAD="${PAYLOADS[0]:-}"
UPDATE_PAYLOAD="${PAYLOADS[1]:-}"

# `--fail-with-body` sous `set -e` interrompt le script avant qu'il puisse
# afficher le corps de la réponse : capturer statut et corps séparément pour
# ne plus jamais perdre le message d'erreur réel de Brevo.
LIST_RESPONSE_FILE="$(mktemp)"
LIST_HTTP_CODE="$(curl --silent --show-error \
  --output "$LIST_RESPONSE_FILE" \
  --write-out '%{http_code}' \
  -H "accept: application/json" \
  -H "api-key: $BREVO_API_KEY" \
  "https://api.brevo.com/v3/webhooks?type=inbound")"
WEBHOOKS="$(cat "$LIST_RESPONSE_FILE")"
rm -f "$LIST_RESPONSE_FILE"
if [ "$LIST_HTTP_CODE" -lt 200 ] || [ "$LIST_HTTP_CODE" -ge 300 ]; then
  # Observé en production (26 août 2026) : tant qu'aucun webhook "inbound"
  # n'existe encore sur le compte, Brevo répond 400 document_not_found sur
  # ce filtre au lieu d'une liste vide — ce n'est pas une erreur, juste
  # l'absence de webhook à mettre à jour. Toute autre erreur reste fatale.
  if [ "$LIST_HTTP_CODE" = "400" ] && printf '%s' "$WEBHOOKS" | grep -q '"code":"document_not_found"'; then
    echo "Aucun webhook inbound existant côté Brevo (document_not_found) ; création."
    WEBHOOKS='{"webhooks":[]}'
  else
    echo "Brevo GET /webhooks?type=inbound a échoué HTTP $LIST_HTTP_CODE: $WEBHOOKS" >&2
    exit 22
  fi
fi

export WEBHOOKS
WEBHOOK_ID="$(python3 - <<'PY'
import json, os
url = os.environ["URL"]
domain = os.environ["DOMAIN"]
data = json.loads(os.environ["WEBHOOKS"])
for hook in data.get("webhooks", []):
    if hook.get("type") == "inbound" and hook.get("url") == url and hook.get("domain") == domain:
        print(hook.get("id", ""))
        break
PY
)"

if [ -n "$WEBHOOK_ID" ]; then
  echo "Mise à jour du webhook inbound Brevo id=$WEBHOOK_ID"
  PUT_RESPONSE_FILE="$(mktemp)"
  PUT_HTTP_CODE="$(curl --silent --show-error \
    --output "$PUT_RESPONSE_FILE" \
    --write-out '%{http_code}' \
    -X PUT "https://api.brevo.com/v3/webhooks/$WEBHOOK_ID" \
    -H "accept: application/json" \
    -H "api-key: $BREVO_API_KEY" \
    -H "Content-Type: application/json" \
    --data "$UPDATE_PAYLOAD")"
  PUT_BODY="$(cat "$PUT_RESPONSE_FILE")"
  rm -f "$PUT_RESPONSE_FILE"
  if [ "$PUT_HTTP_CODE" -lt 200 ] || [ "$PUT_HTTP_CODE" -ge 300 ]; then
    echo "Brevo PUT /webhooks/$WEBHOOK_ID a échoué HTTP $PUT_HTTP_CODE: $PUT_BODY" >&2
    exit 22
  fi
else
  echo "Création du webhook inbound Brevo pour $DOMAIN"
  CREATE_RESPONSE_FILE="$(mktemp)"
  CREATE_HTTP_CODE="$(curl --silent --show-error \
    --output "$CREATE_RESPONSE_FILE" \
    --write-out '%{http_code}' \
    -X POST "https://api.brevo.com/v3/webhooks" \
    -H "accept: application/json" \
    -H "api-key: $BREVO_API_KEY" \
    -H "Content-Type: application/json" \
    --data "$CREATE_PAYLOAD")"
  CREATED="$(cat "$CREATE_RESPONSE_FILE")"
  rm -f "$CREATE_RESPONSE_FILE"
  if [ "$CREATE_HTTP_CODE" -lt 200 ] || [ "$CREATE_HTTP_CODE" -ge 300 ]; then
    echo "Brevo POST /webhooks (inbound) a échoué HTTP $CREATE_HTTP_CODE: $CREATED" >&2
    exit 22
  fi
  export CREATED
  WEBHOOK_ID="$(python3 - <<'PY'
import json, os
print(json.loads(os.environ["CREATED"]).get("id", ""))
PY
)"
fi

if [ -z "$WEBHOOK_ID" ]; then
  echo "Impossible de déterminer l'identifiant du webhook inbound Brevo." >&2
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
errors = []
if hook.get("url") != os.environ["URL"]:
    errors.append("URL incorrecte")
if hook.get("type") != "inbound":
    errors.append("type non inbound")
if hook.get("domain") != os.environ["DOMAIN"]:
    errors.append("domaine inbound incorrect")
if "inboundEmailProcessed" not in set(hook.get("events") or []):
    errors.append("événement inboundEmailProcessed manquant")
auth = hook.get("auth") or {}
if str(auth.get("type", "")).lower() != "bearer":
    errors.append("auth Bearer absente")
if errors:
    print("Webhook inbound Brevo non conforme: " + " ; ".join(errors), file=sys.stderr)
    sys.exit(4)
print(f"Webhook inbound Brevo conforme id={hook.get('id')} domain={hook.get('domain')} auth=bearer")
print()
print("DNS requis pour l'inbound Brevo :")
print(f"  {os.environ['DOMAIN']} MX 10 inbound1.sendinblue.com.")
print(f"  {os.environ['DOMAIN']} MX 20 inbound2.sendinblue.com.")
print()
print("Puis transférer une copie des mails reçus sur contact@ilipresto.fr")
print(f"vers contact@{os.environ['DOMAIN']} pour alimenter le widget admin.")
PY

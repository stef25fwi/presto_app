#!/bin/bash
if [ -z "$BREVO_API_KEY" ]; then
  read -rsp "Brevo API key : " BREVO_API_KEY; echo
fi
URL="https://europe-west1-presto-app-74abe.cloudfunctions.net/handleEmailProviderWebhook"
curl -s -X POST "https://api.brevo.com/v3/webhooks" \
  -H "api-key: $BREVO_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"url\":\"$URL\",\"events\":[\"delivered\",\"softBounce\",\"hardBounce\",\"spam\",\"unsubscribed\",\"opened\",\"click\"],\"type\":\"transactional\",\"description\":\"Presto App tracking\"}"
echo

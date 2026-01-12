#!/bin/bash

# Script pour créer le document settings/microia dans Firestore

PROJECT_ID="presto-app-74abe"

# Créer le document via Firebase CLI en utilisant la commande REST
echo "Creating document: settings/microia..."

curl -X POST \
  "https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/settings?documentId=microia" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
  -d '{
    "fields": {
      "mode": {"stringValue": "HYBRID"},
      "fallbackEnabled": {"booleanValue": true},
      "qualityThreshold": {"doubleValue": 0.62},
      "languageCode": {"stringValue": "fr-FR"}
    }
  }'

echo -e "\n✓ Document creation request sent!"

## Ajouter le document settings/microia à Firestore

### Option 1 : Via Firebase Console (Recommandé - Plus simple)

1. Accédez à : https://console.firebase.google.com/project/presto-app-74abe/firestore
2. Créez une nouvelle collection : `settings`
3. Ajoutez un document avec l'ID : `microia`
4. Ajoutez les champs suivants :
   - `mode` (string) : "HYBRID"
   - `fallbackEnabled` (boolean) : true
   - `qualityThreshold` (number) : 0.62
   - `languageCode` (string) : "fr-FR"

### Option 2 : Via Script Node.js (Si authentification gcloud est configurée)

```bash
cd /workspaces/presto_app/functions
gcloud auth application-default login  # Une seule fois
node add_microia_settings.js
```

### Option 3 : Via Cloud Shell (Alternative)

Exécutez ce code dans Google Cloud Shell :

```bash
PROJECT_ID="presto-app-74abe"

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
```

## Vérifier que le document a été créé

```bash
firebase firestore:inspect settings/microia --project presto-app-74abe
```

Ou dans Firebase Console : Collections → settings → microia

# Audit des dépendances Functions

Rapport reproductible généré à partir de `functions/package-lock.json`.

- Critiques : **0**
- Hautes : **0**
- Modérées : **9**
- Faibles : **0**

| Module | Sévérité | Direct | Correctif disponible | Dépendances affectées |
|---|---|---:|---:|---|
| @google-cloud/firestore | moderate | non | oui | firebase-admin |
| @google-cloud/storage | moderate | non | oui | firebase-admin |
| firebase-admin | moderate | oui | oui | firebase-functions |
| firebase-functions | moderate | oui | oui |  |
| gaxios | moderate | non | oui |  |
| google-gax | moderate | non | oui | @google-cloud/firestore |
| retry-request | moderate | non | oui | @google-cloud/storage, google-gax |
| teeny-request | moderate | non | oui | @google-cloud/storage, retry-request |
| uuid | moderate | non | oui | gaxios, google-gax, teeny-request |

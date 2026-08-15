# Audit des dépendances Functions

Rapport reproductible généré à partir de `functions/package-lock.json`.

- Critiques : **0**
- Hautes : **0**
- Modérées : **7**
- Faibles : **0**

| Module | Sévérité | Direct | Correctif disponible | Dépendances affectées |
|---|---|---:|---:|---|
| @google-cloud/storage | moderate | non | oui | firebase-admin |
| firebase-admin | moderate | oui | oui | firebase-functions |
| firebase-functions | moderate | oui | oui |  |
| gaxios | moderate | non | oui |  |
| retry-request | moderate | non | oui | @google-cloud/storage |
| teeny-request | moderate | non | oui | @google-cloud/storage, retry-request |
| uuid | moderate | non | oui | gaxios, teeny-request |

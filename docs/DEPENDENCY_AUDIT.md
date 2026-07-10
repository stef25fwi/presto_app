# Audit des dépendances Functions

Généré sur le commit `eefb919f45d4b4fe4703e13ea82154d2635a20ba`.

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

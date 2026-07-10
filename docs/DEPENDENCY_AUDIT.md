# Audit des dépendances Functions

Généré sur le commit `efb2474b456832c5ab42102562ab18492a9f3d8c`.

- Critiques : **0**
- Hautes : **1**
- Modérées : **10**
- Faibles : **0**

| Module | Sévérité | Direct | Correctif disponible | Dépendances affectées |
|---|---|---:|---:|---|
| @grpc/grpc-js | high | non | oui |  |
| @google-cloud/common | moderate | non | oui | @google-cloud/speech |
| @google-cloud/firestore | moderate | non | oui | firebase-admin |
| @google-cloud/speech | moderate | oui | oui |  |
| @google-cloud/storage | moderate | non | oui | firebase-admin |
| firebase-admin | moderate | oui | oui |  |
| gaxios | moderate | non | oui |  |
| google-gax | moderate | non | oui | @google-cloud/firestore |
| retry-request | moderate | non | oui | @google-cloud/common, @google-cloud/storage, google-gax |
| teeny-request | moderate | non | oui | @google-cloud/common, @google-cloud/storage, retry-request |
| uuid | moderate | non | oui | @google-cloud/speech, gaxios, google-gax, teeny-request |

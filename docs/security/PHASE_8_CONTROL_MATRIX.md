# Phase 8 — matrice des contrôles sécurité

La phase 8 ne peut être clôturée que lorsque chaque contrôle obligatoire est
complet et dispose d'une preuve exploitable.

## Trois natures de contrôle

| Nature | Ce qui fait foi | Statut |
|---|---|---|
| `automated` | Une commande réellement exécutée par le vérificateur | **Dérivé** du code de sortie |
| `source-control` | La présence d'un artefact versionné | Déclaré, vérifiable en relecture |
| `external-evidence` | Une console externe (Firebase, Google Cloud) | Déclaré par un opérateur, preuve à l'appui |

Avant la refonte du 2026-07-29, tout contrôle se résumait à « le champ `status`
vaut `verified` et un fichier existe » : un contrôle pouvait donc être marqué
vérifié sans que rien ne soit vérifié. Les contrôles `automated` ferment cette
faille — leur statut ne peut plus être écrit à la main.

## État au 2026-07-29 (commit `252f190`)

| Contrôle | Nature | État |
|---|---|---|
| `app-check-functions-enforced` | automated | ✅ vérifié |
| `secrets-inventory-current` | automated | ✅ vérifié |
| `dependency-audit-clean` | automated | ✅ vérifié |
| `firebase-preview-production-blocked` | source-control | ✅ vérifié |
| `codeql-enabled` | source-control | ✅ vérifié |
| `owasp-review-complete` | external-evidence | ✅ vérifié |
| `app-check-firestore-enforced` | external-evidence | ⏳ en attente |
| `app-check-storage-enforced` | external-evidence | ⏳ en attente |
| `api-keys-restricted` | external-evidence | ⏳ en attente |

**6 vérifiés sur 9.** Les 3 contrôles restants sont des réglages de console
Firebase et Google Cloud : ils ne sont vérifiables ni depuis le dépôt, ni
depuis la CI, et exigent un opérateur disposant d'un accès au projet
`presto-app-74abe`. Chacun dispose d'un runbook prêt à l'emploi sous
`docs/evidence/security/`.

⚠️ Avant de basculer App Check sur `Enforced` pour Firestore ou Storage, lire
l'avertissement du runbook : le SDK Flutter Web n'attache pas de jeton App
Check aux requêtes Firestore, et une bascule prématurée coupe le client web.

## Exécution

Inventaire non bloquant :

```bash
node tools/quality/check_security_controls.mjs
```

Validation stricte avant go-live :

```bash
node tools/quality/check_security_controls.mjs --enforce
```

Le rapport est généré dans `quality_reports/security/security-controls.json`.

Les preuves vivent sous `docs/evidence/security/`. Pour clôturer un contrôle
`external-evidence`, joindre la preuve datée au document correspondant puis
passer son `status` à `verified` dans `quality/security-controls.json`.

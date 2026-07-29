# Preuve — App Check appliqué aux Cloud Functions

**Contrôle** : `app-check-functions-enforced`
**Nature** : `automated` — vérifié à chaque exécution de la matrice, pas déclaré à la main.

## Commande de vérification

```bash
node tools/quality/check_functions_app_check.mjs
```

Le contrôle échoue si une seule Function `onCall` omet
`enforceAppCheck: ENFORCE_APP_CHECK` (ou `true`) dans ses options.

## Mécanisme

Pour les Functions *callable*, App Check s'applique dans le code, pas dans la
console : c'est l'option `enforceAppCheck` passée à `onCall` qui fait foi. La
vérification statique de la source est donc la vérification de référence pour
ce contrôle — contrairement à Firestore et Storage, dont l'application est un
réglage de console (voir `app-check-firestore.md` et `app-check-storage.md`).

La valeur est centralisée dans `functions/src/config/app_check_policy.ts` :

- en émulateur : jamais appliqué ;
- si `APPCHECK_SAFE_MODE=true` : désactivé (levier d'urgence explicite) ;
- en production (`presto-app-74abe`) : appliqué **sauf** `ENFORCE_APP_CHECK=false` explicite ;
- hors production : appliqué uniquement si `ENFORCE_APP_CHECK=true`.

`assertProdSecurityConfig()` journalise `CRITICAL_APP_CHECK_DISABLED` si la
production démarre sans application — signal à brancher sur une alerte.

## État mesuré au 2026-07-29 (commit `252f190`)

| Indicateur | Valeur |
|---|---:|
| Fichiers TypeScript scannés | 159 |
| Functions `onCall` détectées | 79 |
| Violations | 0 |
| Exceptions tracées | 1 |

## Exception en cours

`functions/src/modules/messaging/callables.ts` —
id `messaging-app-check-web-availability`, échéance **2026-08-31**.

Motif : déploiement web reCAPTCHA/App Check non encore vérifié pour la
messagerie. Les contrôles d'authentification, d'appartenance à la conversation,
de validation et de limitation de débit restent obligatoires sur ce module.

Cette échéance est désormais **appliquée** : depuis le 2026-09-01, l'exception
bascule automatiquement en violation `expired-exception` et fait échouer la
barrière. Auparavant, `reviewBy` n'était qu'un commentaire et l'exception
aurait survécu indéfiniment.

## Limites

Ce contrôle prouve que le code demande l'application d'App Check. Il ne prouve
pas que le fournisseur d'attestation (reCAPTCHA Enterprise sur le web, Play
Integrity, App Attest) est correctement configuré côté console pour chaque
plateforme. Cette partie relève de `app-check-firestore.md` et
`app-check-storage.md`.

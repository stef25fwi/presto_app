# Phase 11 — préparation Stripe

Cette phase ne peut être déclarée terminée que lorsque tous les contrôles requis du fichier `quality/stripe-readiness.json` sont marqués `implemented` avec une preuve existante.

## Contrôles obligatoires

- signature des webhooks ;
- idempotence des opérations sensibles ;
- checkout E2E en mode test ;
- cycle de vie complet des abonnements ;
- remboursement et litige ;
- réconciliation Stripe / Firestore ;
- séparation stricte test / production.

## Commandes

```bash
node tools/quality/check_stripe_readiness.test.mjs
node tools/quality/check_stripe_readiness.mjs
node tools/quality/check_stripe_readiness.mjs --enforce
```

Le mode inventaire mesure l’avancement sans bloquer les PR. Le mode `--enforce` doit être utilisé avant la clôture de la phase et avant le go-live.

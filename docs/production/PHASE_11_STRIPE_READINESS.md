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

## État au 1er août 2026

Six contrôles sur sept sont `implemented`. Le détail de ce qui les couvre :

| Contrôle | Couverture |
|---|---|
| `stripe-webhook-signature` | HMAC SHA-256 à comparaison à temps constant, fenêtre de tolérance de 5 min, rotation de secret (deux `v1=`) — `stripe_signature.test.ts` |
| `stripe-idempotency` | Sortante : en-tête `Idempotency-Key` dérivé d'un condensat stable, fenêtre fixe de 10 min pour Checkout. Entrante : bail transactionnel sur `stripe_webhook_events`, doublon détecté, bail expirable — `idempotency.test.ts` |
| `stripe-checkout-e2e` | **En attente.** Le script existe (`functions/scripts/stripe_checkout_e2e.mjs`) mais n'a jamais été exécuté contre Stripe — voir ci-dessous |
| `stripe-subscription-lifecycle` | Traduction des sept statuts Stripe, plan déduit des métadonnées puis du tarif, refus d'activer un plan inconnu, protection contre les événements hors séquence et les comptes supprimés — `subscription_lifecycle.test.ts` |
| `stripe-refund-dispute` | Remboursements totaux et partiels, litiges et alertes réseau, issue déduite du mouvement de fonds, signalement du compte pour revue — `refunds.ts` |
| `stripe-reconciliation` | Recoupement quotidien Stripe ↔ Firestore sur statut, résiliation programmée, fin de période et tarif — `reconciliation.ts` |
| `stripe-test-mode-isolation` | Mode déduit de la clé, clé réelle refusée hors projet de production, `livemode` de l'événement confronté au mode de la clé — `stripe_mode.ts` |

### Ce qui reste pour clore la phase

Le contrôle `stripe-checkout-e2e` demande un vrai parcours de paiement. Aucun
test automatisé ne peut le prouver : il faut une clé Stripe de test, une carte
de test et le webhook déployé.

```bash
STRIPE_SECRET_KEY=sk_test_... \
STRIPE_PRICE_ILIPRESTO_PLUS=price_... \
STRIPE_PRICE_ILIPRO=price_... \
npm --prefix functions run stripe:checkout:e2e
```

Le script vérifie le compte, contrôle que les deux tarifs existent au bon
montant, ouvre une session Checkout réelle et imprime les vérifications
manuelles restantes (paiement, activation dans Firestore, statut de
l'événement, rejeu marqué en doublon). Il refuse toute clé `sk_live_`.

Une fois le parcours constaté, passer le contrôle à `implemented` avec pour
preuve le script et la trace d'exécution.

## Choix assumés

- **Aucune révocation automatique de droits** sur remboursement ou litige
  perdu : le compte est signalé (`billingIncident`) pour revue humaine. Couper
  un accès payant sur la foi d'un webhook est une décision commerciale, et un
  litige finalement gagné devrait alors être rejoué à l'envers.
- **Recoupement en lecture seule** : le job quotidien constate et journalise,
  il ne réécrit pas les abonnements. Corriger automatiquement un écart
  transitoire (webhook en vol, réplication en retard) ferait plus de dégâts que
  l'écart lui-même.
- **`livemode` absent = événement traité** : refuser ferait perdre les rejeux
  et les charges utiles tronquées. Seule une contradiction explicite est
  rejetée.
- **Nouvelles collections laissées côté serveur** : `billing_refunds`,
  `billing_disputes` et `billing_reconciliation_reports` ne sont déclarées dans
  aucune règle Firestore, donc refusées par le catch-all. Les Functions y
  accèdent par l'Admin SDK et l'exploitation par la console Firebase. Ouvrir la
  lecture à `isMarketplaceAdmin()`, comme `billing_invoices`, le jour où une
  page d'administration consomme le drapeau `requires_review` — pas avant.

## Commandes

```bash
node tools/quality/check_stripe_readiness.test.mjs
node tools/quality/check_stripe_readiness.mjs
node tools/quality/check_stripe_readiness.mjs --enforce

# Tests unitaires du module de facturation
npm --prefix functions test
```

Le mode inventaire mesure l’avancement sans bloquer les PR. Le mode `--enforce` doit être utilisé avant la clôture de la phase et avant le go-live.

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

**Les sept contrôles sont `implemented`.** La phase passe en `--enforce`.

Le détail de ce qui les couvre :

| Contrôle | Couverture |
|---|---|
| `stripe-webhook-signature` | HMAC SHA-256 à comparaison à temps constant, fenêtre de tolérance de 5 min, rotation de secret (deux `v1=`) — `stripe_signature.test.ts` |
| `stripe-idempotency` | Sortante : en-tête `Idempotency-Key` dérivé d'un condensat stable, fenêtre fixe de 10 min pour Checkout. Entrante : bail transactionnel sur `stripe_webhook_events`, doublon détecté, bail expirable — `idempotency.test.ts` |
| `stripe-checkout-e2e` | Parcours complet constaté le 1er août 2026 : catalogue conforme, paiement carte de test, abonnement actif dans Firestore avec le bon plan, événement `checkout.session.completed` en `processed` — voir ci-dessous |
| `stripe-subscription-lifecycle` | Traduction des sept statuts Stripe, plan déduit des métadonnées puis du tarif, refus d'activer un plan inconnu, protection contre les événements hors séquence et les comptes supprimés — `subscription_lifecycle.test.ts` |
| `stripe-refund-dispute` | Remboursements totaux et partiels, litiges et alertes réseau, issue déduite du mouvement de fonds, signalement du compte pour revue — `refunds.ts` |
| `stripe-reconciliation` | Recoupement quotidien Stripe ↔ Firestore sur statut, résiliation programmée, fin de période et tarif — `reconciliation.ts` |
| `stripe-test-mode-isolation` | Mode déduit de la clé, clé réelle refusée hors projet de production, `livemode` de l'événement confronté au mode de la clé — `stripe_mode.ts` |

### Parcours constaté le 1er août 2026

Compte `acct_1Tr9UpCMctJ3ssHG`, mode test, webhook déployé en `europe-west1`.

| Vérification | Résultat |
|---|---|
| Clé de test valide, compte joignable | ✅ `iliprestō` |
| Tarif `ilipresto_plus` | ✅ 1,99 EUR/mois |
| Tarif `ilipro` | ✅ 9,99 EUR/mois |
| Session Checkout créée et ouverte | ✅ |
| Paiement carte 4242 | ✅ |
| Abonnement actif chez Stripe | ✅ `sub_1TzikECMctJ3ssHG68pegKKN` |
| `subscriptions/<id>` actif dans Firestore, bon plan | ✅ |
| `checkout.session.completed` en `processed` | ✅ `evt_1TzikHCMctJ3ssHGfisVUUva` |
| Événements webhook traités | ✅ 17/17 |

`users/<uid>` reste légitimement absent : l'uid `e2e_…` ne correspond à aucun
compte Firebase, et `syncSubscription` n'écrit les droits que sur un
utilisateur existant (`userSnapshot.exists`).

### Reproduire

```bash
# 1. Ouvrir une session Checkout
STRIPE_SECRET_KEY=sk_test_... \
STRIPE_PRICE_ILIPRESTO_PLUS=price_... \
STRIPE_PRICE_ILIPRO=price_... \
npm --prefix functions run stripe:checkout:e2e

# 2. Payer avec 4242 4242 4242 4242 à l'URL affichée

# 3. Constater la chaîne complète
STRIPE_SECRET_KEY=sk_test_... \
npm --prefix functions run stripe:checkout:e2e:verify
```

Le premier script refuse toute clé `sk_live_` et conserve le client de test par
défaut — la session Checkout lui appartient, le supprimer rendrait l'URL
inutilisable. `--cleanup` force la suppression pour un simple contrôle de
catalogue. Le second retrouve seul le dernier client de test ; ses lectures
Firestore demandent `gcloud auth application-default login` et sont ignorées
proprement sans credentials.

### Incident rencontré, et ce qu'il enseigne

Le premier passage a échoué sur `checkout.session.completed` avec
`Expired API Key provided`. Cause : la clé Stripe portée par le secret
`STRIPE_SECRET_KEY` des Functions déployées avait été révoquée, sans que le
secret soit mis à jour ni les fonctions redéployées.

Deux enseignements qui dépassent ce contrôle :

1. **Révoquer une clé Stripe casse les Functions déployées.** Le secret est
   versionné : après `firebase functions:secrets:set`, un redéploiement est
   obligatoire. Sept fonctions utilisaient cette clé — `handleStripeWebhook`,
   les trois callables d'abonnement, `auditStripeCatalog`,
   `reconcileStripeSubscriptions` et `requestAccountDeletion`.

2. **La panne était silencieuse côté utilisateur.** Seule la branche
   `checkout.session.completed` rappelle l'API Stripe (`stripeGet` sur
   l'abonnement) et échouait donc ; les branches `customer.subscription.*`
   reçoivent l'objet dans la charge utile et continuaient d'écrire. L'abonnement
   arrivait quand même dans Firestore, et rien ne signalait l'anomalie hors des
   journaux. C'est exactement le type d'écart que le recoupement quotidien
   `reconcileStripeSubscriptions` est là pour rattraper.

### Reste facultatif

Le rejeu d'un événement déjà traité doit ressortir
`{"received":true,"duplicate":true}`. Cette idempotence d'entrée est déjà
couverte par `evaluateEventLease` et ses tests (`idempotency.test.ts`) ; la
confirmer en conditions réelles est une vérification de confort, pas une
condition de clôture.

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

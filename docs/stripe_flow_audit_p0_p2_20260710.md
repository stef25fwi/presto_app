# Audit et réparation du flow Stripe — P0 à P2

Date : 10 juillet 2026  
Projet Firebase : `presto-app-74abe`  
Environnement demandé : **Stripe test iliprestō**

## P0 — Bloquants et sécurité

### Corrigé dans le code

- validation serveur de chaque Price ID avant création du Checkout ;
- vérification du montant attendu :
  - iliprestō+ : `1,99 EUR / mois` ;
  - ilipro : `9,99 EUR / mois` ;
- vérification que le prix et le produit Stripe sont actifs ;
- détection immédiate d’un Price ID appartenant à un autre compte ou à un autre mode Stripe ;
- prévention des doubles abonnements : un client possédant déjà un abonnement actif, en essai, incomplet ou impayé est renvoyé vers le portail ou sa facture au lieu de créer un second abonnement ;
- idempotence de la création du Customer Stripe ;
- idempotence du Checkout par utilisateur, plan et fenêtre de dix minutes ;
- suppression des anciens noms de Cloud Functions de secours côté Flutter ;
- ouverture limitée aux URL HTTPS appartenant à `stripe.com` ;
- liaison des secrets des deux Price IDs au webhook ;
- refus de rétrograder silencieusement un abonnement actif dont le plan Stripe est inconnu ;
- verrou de traitement des événements webhook concurrents ;
- distinction entre signature invalide (`400`) et erreur interne réessayable (`500`) ;
- persistance de l’erreur et du nombre de tentatives webhook ;
- protection contre la réhydratation Stripe d’un compte Firebase supprimé.

## P1 — Fiabilité du cycle de vie

### Corrigé dans le code

- récupération d’un Customer Stripe devenu invalide ou supprimé ;
- synchronisation du nom, de l’e-mail, de la locale et du `firebaseUid` du Customer ;
- récupération de la facture hébergée pour les abonnements `incomplete`, `past_due` et `unpaid` ;
- prise en charge des événements :
  - `checkout.session.completed` ;
  - `checkout.session.async_payment_succeeded` ;
  - `checkout.session.async_payment_failed` ;
  - `checkout.session.expired` ;
  - créations, mises à jour, suppressions, pauses et reprises d’abonnement ;
  - mises à jour d’abonnement différées ;
  - factures payées, échouées, nécessitant une action, annulées ou irrécouvrables ;
- conservation du dernier événement Stripe appliqué pour éviter les régressions d’état ;
- journalisation Firestore des sessions Checkout, redirections et ouvertures du portail ;
- nouvelle callable `getSubscriptionCheckoutStatus` vérifiant que la session appartient bien à l’utilisateur connecté.

## P2 — Conversion et expérience utilisateur

### Corrigé dans le code

- Checkout et portail forcés en français ;
- collecte automatique de l’adresse de facturation ;
- mise à jour automatique du nom et de l’adresse du Customer ;
- collecte du numéro de TVA pour ilipro ;
- promotions autorisées par défaut, désactivables avec `STRIPE_ALLOW_PROMOTION_CODES=false` ;
- activation facultative de Stripe Tax avec `STRIPE_AUTOMATIC_TAX_ENABLED=true` ;
- expiration explicite des sessions Checkout ;
- URL de succès contenant `{CHECKOUT_SESSION_ID}` ;
- retour sur `/account?section=subscriptions` après succès, annulation ou portail ;
- blocage des doubles clics pendant l’ouverture de Stripe ;
- messages différenciés pour saturation, indisponibilité, authentification et permission.

## Vérifications obligatoires dans le Dashboard Stripe test iliprestō

### Produits et prix

- le Price ID iliprestō+ doit être actif, récurrent, mensuel et égal à `1,99 EUR` ;
- le Price ID ilipro doit être actif, récurrent, mensuel et égal à `9,99 EUR` ;
- la clé `STRIPE_SECRET_KEY` doit commencer par `sk_test_` ;
- les deux Price IDs doivent appartenir exactement au même compte test que cette clé.

### Customer Portal

Activer au minimum :

- mise à jour du moyen de paiement ;
- consultation des factures ;
- annulation à la fin de la période ;
- changement de formule entre iliprestō+ et ilipro si souhaité ;
- URL de retour : `https://ilipresto.web.app/account?section=subscriptions&subscription=portal`.

Si une configuration dédiée est créée, définir :

```text
STRIPE_PORTAL_CONFIGURATION_ID=bpc_...
```

### Webhook test

Endpoint attendu :

```text
https://europe-west1-presto-app-74abe.cloudfunctions.net/handleStripeWebhook
```

Événements minimum :

```text
checkout.session.completed
checkout.session.async_payment_succeeded
checkout.session.async_payment_failed
checkout.session.expired
customer.subscription.created
customer.subscription.updated
customer.subscription.deleted
customer.subscription.paused
customer.subscription.resumed
customer.subscription.pending_update_applied
customer.subscription.pending_update_expired
invoice.created
invoice.finalized
invoice.paid
invoice.payment_succeeded
invoice.payment_failed
invoice.payment_action_required
invoice.marked_uncollectible
invoice.voided
```

Le secret de signature de cet endpoint test doit être la valeur de `STRIPE_WEBHOOK_SECRET` et commencer par `whsec_`.

## Scénarios de recette

1. nouvel utilisateur → iliprestō+ → paiement test réussi → plan actif dans Firestore ;
2. nouvel utilisateur → ilipro → paiement test réussi → plan actif dans Firestore ;
3. double clic sur le bouton → une seule session logique ;
4. utilisateur déjà abonné → clic sur un plan → portail ou facture, aucun second abonnement ;
5. carte refusée → état `payment_failed`, facture accessible, e-mail de relance ;
6. authentification 3DS → retour réussi et état synchronisé ;
7. annulation depuis le portail → accès conservé jusqu’à la fin de période si configuré ainsi ;
8. renouvellement réussi → nouvelle facture payée et date de renouvellement mise à jour ;
9. webhook rejoué → aucune duplication ;
10. événement ancien envoyé après un événement récent → aucune régression ;
11. compte supprimé → un webhook tardif ne restaure aucun identifiant Stripe ;
12. bouton Retour depuis Stripe → page des abonnements, sans splash.

## Limite de vérification externe

Le connecteur Stripe disponible pendant l’audit expose le compte `acct_1Ssn0PCCIRtTE2nO` sous le libellé « Environnement de test New business » et n’y retrouve pas les deux Price IDs fournis. La configuration Dashboard du véritable compte test iliprestō doit donc être vérifiée dans le compte qui détient réellement la clé `STRIPE_SECRET_KEY` utilisée par Firebase.

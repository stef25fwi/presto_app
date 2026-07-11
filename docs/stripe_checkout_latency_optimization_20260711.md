# Optimisation de la latence Stripe Checkout — 11 juillet 2026

## Cause initiale

Avant d’ouvrir Stripe, `createSubscriptionCheckoutSession` exécutait plusieurs opérations synchrones :

1. validation du Price Stripe ;
2. validation du Product Stripe ;
3. lecture du profil Firestore ;
4. récupération du Customer Stripe ;
5. synchronisation du Customer Stripe ;
6. recherche de tous ses abonnements ;
7. création de la Checkout Session ;
8. journalisation Firestore.

Le premier appel pouvait également subir un cold start Cloud Functions.

## Nouveau chemin rapide

- une instance de Checkout reste chaude avec `minInstances: 1` ;
- le catalogue Stripe est contrôlé hors du clic par `auditStripeCatalog` toutes les six heures ;
- la page Compte précharge silencieusement iliprestō+ ;
- la page Abonnements précharge la formule actuellement affichée ;
- Flutter conserve l’URL jusqu’à expiration ;
- le serveur réutilise une session Checkout ouverte ;
- le premier Checkout laisse Stripe créer le Customer si nécessaire ;
- les Customers supprimés sont récupérés automatiquement ;
- les abonnements actifs sont toujours redirigés vers le portail ou la facture ;
- l’idempotence et la protection contre les doubles abonnements restent actives.

## Mesure

Chaque exécution écrit un log structuré `STRIPE_CHECKOUT_PERFORMANCE` avec :

- `durationMs` ;
- `cacheHit` ;
- `customerReused` ;
- `destination` ;
- `plan` ;
- `source`.

Commande de contrôle :

```bash
firebase functions:log \
  --project presto-app-74abe \
  --only createSubscriptionCheckoutSession \
  --lines 100
```

## Objectif utilisateur

- URL déjà préchargée : navigation Stripe immédiate au clic ;
- cache serveur : réponse limitée principalement à deux lectures Firestore ;
- création neuve : une lecture Firestore et un appel de création Checkout, hors écriture de traçabilité.

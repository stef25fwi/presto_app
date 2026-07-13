# Stratégie de tests

## Cibles

- Couverture globale : 70 % minimum.
- Modules critiques : 85 % minimum.
- Paiement et droits d’abonnement : 90 % visé.

## Pyramide

- 55 % de tests unitaires : règles métier, validation, quotas, mapping et repositories.
- 30 % de tests widgets : chargement, erreur, vide, succès, responsive et accessibilité.
- 15 % de tests d’intégration : parcours annonce, messagerie, abonnement, entreprise et administration.

## Règles

Toute correction de bug doit inclure un test de non-régression. Toute extraction d’un gros écran doit commencer par un test de caractérisation. Les tests Firebase doivent utiliser Emulator Suite et ne jamais écrire en production.

## Parcours prioritaires

1. Authentification.
2. Publication et consultation d’annonce.
3. Messagerie et notifications.
4. Checkout Stripe, webhook et activation des droits.
5. Parcours personnalisé et export PDF.
6. Suppression administrative, statistiques et historique.

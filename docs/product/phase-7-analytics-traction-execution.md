# Phase 7 — Analytics produit et traction commerciale

## État au 14 juillet 2026

La fondation est présente : taxonomie sans PII, définitions des KPI et plan commercial Guadeloupe. L'audit du dépôt montre toutefois que les factories d'événements typés ne sont pas encore appelées dans les parcours réels. La phase reste donc à 35 %.

## Ordre d'implémentation obligatoire

1. Instrumenter `registration_completed` après confirmation effective du compte.
2. Instrumenter `activation_first_value` lors de la première annonce publiée ou du premier contact utile.
3. Instrumenter `engagement_listing_contacted` au moment où une mise en relation est réellement déclenchée.
4. Instrumenter l'ouverture de la page abonnement et `conversion_plan_selected`.
5. Émettre `conversion_checkout_completed` uniquement après confirmation backend du paiement.
6. Émettre `revenue_subscription_renewed` depuis le webhook Stripe réconcilié.
7. Calculer `retention_returned` à partir d'une date d'inscription persistée et d'une activité qualifiée.
8. Ajouter `acquisition_landing_viewed` avec source normalisée et territoire, sous consentement Analytics.

Chaque étape doit inclure un test, une preuve d'appel réel et une règle de déduplication.

## Dashboard minimum

Le dashboard doit afficher, pour une période choisie :

- visiteurs acquis ;
- inscriptions confirmées ;
- utilisateurs activés ;
- annonces contactées ou conversations créées ;
- plans sélectionnés ;
- abonnements payés ;
- conversion entre chaque étape ;
- MAU, activation, rétention, churn, MRR, CAC et LTV.

Filtres obligatoires : territoire, plateforme, source d'acquisition, catégorie et plan.

## Revenus récurrents

Les métriques mensuelles doivent distinguer :

- nouveau MRR ;
- MRR d'expansion ;
- contraction ;
- churn ;
- réactivation ;
- MRR de fin de mois.

Les chiffres doivent être réconciliés avec Stripe et ne doivent jamais être déduits uniquement d'un événement client.

## Cohortes

Suivre les cohortes d'inscription hebdomadaires et mensuelles avec rétention D1, D7, D30, M1, M3 et M6. Une activité retenue doit correspondre à une action de valeur : publication, contact, réponse ou abonnement actif.

## Validation de la traction Guadeloupe

L'extension DOM reste bloquée tant que les conditions suivantes ne sont pas satisfaites pendant trois mois consécutifs :

- données du tunnel complètes et réconciliées ;
- progression ou stabilité documentée du MAU et de l'activation ;
- rétention mesurée sur des cohortes réelles ;
- MRR et churn suivis mensuellement ;
- CAC calculé à partir des dépenses réelles ;
- décision go/no-go enregistrée dans le dépôt.

Les seuils numériques doivent être décidés après obtention d'une première baseline réelle, afin de ne pas fabriquer des objectifs sans données.

## Definition of Done

La phase est terminée uniquement lorsque les décisions produit mensuelles citent les métriques réelles du dashboard, que le MRR est réconcilié avec Stripe et que les cohortes de rétention sont disponibles pour la Guadeloupe.

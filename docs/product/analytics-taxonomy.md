# Taxonomie Analytics produit

## Principe

L’objectif est de mesurer le tunnel commercial sans enregistrer d’identité, de contenu libre ou de secret. Les événements ne doivent partir qu’après consentement Analytics.

## Convention

- nom en `snake_case`, 40 caractères maximum ;
- préfixe correspondant à l’étape du tunnel ;
- paramètres courts, catégoriels ou numériques ;
- aucun email, téléphone, nom, adresse, message, description, jeton ou identifiant utilisateur ;
- les identifiants de plan, catégorie ou territoire sont autorisés lorsqu’ils ne permettent pas d’identifier une personne.

## Tunnel de référence

| Étape | Événement principal | Définition |
|---|---|---|
| Acquisition | `acquisition_landing_viewed` | arrivée sur une page de destination |
| Inscription | `registration_completed` | compte créé avec succès |
| Activation | `activation_first_value` | première valeur obtenue : annonce, contact ou parcours |
| Engagement | `engagement_listing_contacted` | prise de contact depuis une annonce |
| Conversion | `conversion_plan_selected` | plan choisi |
| Conversion | `conversion_checkout_completed` | paiement confirmé par le backend |
| Rétention | `retention_returned` | retour à J1, J7, J30 ou au-delà |
| Revenu | `revenue_subscription_renewed` | renouvellement confirmé par webhook |

## Paramètres communs

| Paramètre | Usage |
|---|---|
| `funnel_stage` | étape normalisée, injectée automatiquement |
| `source` | organic, referral, social, paid, partner |
| `territory` | GP, MQ, GF, RE ou code futur |
| `category_id` | catégorie métier normalisée |
| `plan_id` | free, ilipresto_plus, ilipro |
| `billing_period` | monthly, annual |
| `amount` | montant numérique confirmé |
| `currency` | EUR |
| `days_since_registration` | mesure de rétention |
| `seconds_since_registration` | délai avant première valeur |

## Source de vérité

Les événements client mesurent l’intention et l’usage. Les événements de revenu, de renouvellement, de remboursement et d’activation des droits doivent être confirmés côté backend après validation Stripe. Un retour navigateur ne constitue pas une preuve de paiement.

## Qualité

Le catalogue statique est généré avec :

```bash
python3 tools/quality/audit_analytics_events.py \
  --output-dir quality_reports/analytics
```

Toute nouvelle instrumentation doit documenter : propriétaire, définition, moment de déclenchement, paramètres, consentement, KPI alimenté et règle de déduplication.

## Données interdites

- email et téléphone ;
- prénom, nom et adresse ;
- texte d’annonce, message ou description ;
- contenu vocal ou transcription ;
- jetons Auth, App Check, Stripe ou API ;
- identifiant utilisateur brut ;
- coordonnées précises.

Les analyses territoriales utilisent des catégories suffisamment larges pour éviter la ré-identification.

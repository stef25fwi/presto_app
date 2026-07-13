# Plan de traction commerciale — année 1

## Finalité

Créer un marché local suffisamment liquide en Guadeloupe avant toute extension : une demande publiée doit recevoir des réponses pertinentes et un prestataire actif doit trouver régulièrement des opportunités.

Les objectifs ci-dessous sont des cibles de pilotage, pas des revenus garantis.

## Proposition de valeur

**Demandeur :** trouver rapidement une personne disponible pour un service ou micro-service local.

**Prestataire :** recevoir des opportunités correspondant à son savoir-faire, son territoire et sa disponibilité.

**Différenciation :** ancrage ultramarin, publication assistée par IA, alertes ciblées et outils de création d’activité.

## North Star Metric

**Nombre hebdomadaire de mises en relation qualifiées**, défini comme une annonce ayant généré au moins un contact pertinent et non signalé.

Cette mesure est plus utile que le simple nombre d’inscriptions.

## Objectifs annuels

| Période | Inscrits cumulés | MAU | Prestataires actifs mensuels | Abonnés payants | MRR cible |
|---|---:|---:|---:|---:|---:|
| Fin T1 | 1 500 | 700 | 250 | 50 | 300–700 € |
| Fin T2 | 4 000 | 1 800 | 600 | 150 | 1 000–2 000 € |
| Fin T3 | 8 000 | 3 500 | 1 100 | 350 | 2 500–5 000 € |
| Fin T4 | 15 000 | 6 000 | 1 800 | 700 | 4 000–10 000 € |

Le MRR dépend du mix entre iliprestō+ à 1,99 € et ilipro à 9,99 €, des promotions, de la TVA, des remboursements et du churn.

## Garde-fous de liquidité

Avant d’augmenter fortement l’acquisition payante, viser par commune et catégorie :

- délai médian avant première réponse inférieur à 4 heures ;
- au moins 60 % des annonces avec un contact qualifié sous 48 heures ;
- au moins 5 prestataires actifs dans les catégories prioritaires ;
- taux de signalement et fraude sous contrôle ;
- rétention J30 des prestataires supérieure à 20 %.

## Trimestre 1 — Validation Guadeloupe

### Offre

- recruter manuellement les premiers prestataires par catégorie et commune ;
- vérifier identité, disponibilité et qualité du profil selon le cadre légal ;
- cibler ménage, jardinage, bricolage, aide administrative, numérique, beauté à domicile et événementiel ;
- accompagner la première annonce et la première réponse.

### Demande

- contenus sociaux orientés besoins concrets ;
- partenariats de proximité ;
- QR codes et supports locaux ;
- programme de parrainage limité et mesuré ;
- collecte structurée des besoins non satisfaits.

### Produit

- réduire le temps inscription → première valeur ;
- suivre les catégories sans offre suffisante ;
- corriger les abandons de publication ;
- améliorer les alertes et la qualité des réponses.

## Trimestre 2 — Répétabilité

- automatiser onboarding et relances ;
- développer les ambassadeurs par commune ;
- créer pages SEO par catégorie et territoire ;
- lancer des campagnes payantes uniquement sur les zones liquides ;
- segmenter demandeurs, prestataires et professionnels ;
- tester parrainage, essai pro et alertes premium.

## Trimestre 3 — Monétisation

- optimiser page abonnement et délai d’ouverture Stripe ;
- présenter la valeur avant le prix ;
- convertir les prestataires ayant déjà reçu des opportunités ;
- tester limites gratuites sans dégrader l’activation ;
- mesurer conversion par plan, catégorie, commune et source ;
- déclencher des relances utiles, non intrusives.

## Trimestre 4 — Consolidation et réplication

- réduire churn et améliorer renouvellement ;
- documenter le playbook d’ouverture d’un territoire ;
- vérifier support, modération, fraude et coût cloud ;
- préparer la Martinique seulement si les seuils de liquidité et rétention sont atteints ;
- conserver une séparation claire des métriques par territoire.

## Funnel mesuré

```text
visite
→ inscription
→ profil complété
→ première consultation ou publication
→ premier contact qualifié
→ retour J7
→ retour J30
→ choix du plan
→ checkout confirmé
→ renouvellement
```

## KPI hebdomadaires

| Domaine | KPI |
|---|---|
| Acquisition | visiteurs, source, CAC, conversion visite → inscription |
| Activation | profil complété, délai avant première valeur, première annonce/contact |
| Liquidité | annonces avec réponse, délai avant réponse, contacts par annonce |
| Engagement | WAU/MAU, favoris, messages, alertes ouvertes |
| Rétention | J1, J7, J30, cohortes demandeurs/prestataires |
| Revenu | conversion payante, MRR, ARPU, churn, remboursements |
| Qualité | signalements, litiges, blocages, faux profils, satisfaction |
| Efficacité | coût cloud par MAU et par mise en relation qualifiée |

## Seuils de décision

- **Accélérer :** liquidité, rétention et coût d’acquisition sont dans les objectifs.
- **Corriger le produit :** inscriptions élevées mais première valeur faible.
- **Renforcer l’offre :** demandes sans réponse dans certaines catégories/communes.
- **Réduire les dépenses :** CAC supérieur à la valeur vie client attendue.
- **Reporter l’expansion :** Guadeloupe non encore répétable ou support saturé.

## Expérimentation

Chaque test doit définir : hypothèse, population, événement principal, métrique de garde-fou, durée, seuil de décision et résultat. Ne pas multiplier les expériences simultanées sur un faible volume.

## Responsabilité

Le code permet la mesure. La traction exige ensuite acquisition, animation du marché, support, partenariats, qualité des prestataires et exécution commerciale régulière.

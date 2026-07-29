# Environnements et promotion des versions

## Objectif

Séparer les validations, les aperçus de pull request et la production afin qu’aucun test ou développement ne modifie les données réelles.

## Environnements

| Environnement | Usage | Déploiement | Données |
|---|---|---|---|
| Développement local | Développement et tests rapides | Manuel, émulateurs Firebase | Synthétiques |
| Preview PR | Validation visuelle d’une branche | Canal Firebase Hosting isolé, expiration 7 jours | Production non modifiée ; fonctionnalités protégées selon configuration App Check |
| Staging cible | Tests d’intégration complets avant release | Projet Firebase distinct à provisionner | Jeu de données de test |
| Production | Utilisateurs réels | Workflow `Validate and Deploy Firebase` depuis `main` | Réelles |

## Règles

- Une pull request ne dispose jamais de droits d’écriture sur le dépôt.
- Une pull request ne déploie jamais Functions, règles, index ou Storage en production.
- Le canal Preview ne publie que le build Hosting validé.
- Toute release de production est archivée avant déploiement pendant 90 jours.
- Les secrets ne doivent pas être partagés entre staging et production.
- Les webhooks Stripe de test et de production doivent utiliser des endpoints et secrets distincts.

## Situation actuelle

Les secrets de production sont associés à l’environnement GitHub nommé `recaptcha`. Ce nom doit être remplacé par `production` uniquement après migration et vérification de tous les secrets, afin d’éviter une interruption du déploiement.

## Cible suivante

Provisionner un projet Firebase staging distinct avec Auth, Firestore, Functions, Storage, App Check, Remote Config, FCM et Stripe test. Une release ne doit être promue en production qu’après validation du staging.

La procédure détaillée est dans [`staging-environment-setup.md`](staging-environment-setup.md).

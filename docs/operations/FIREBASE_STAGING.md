# Firebase staging

## Objectif

Les previews de pull request et les validations préproduction doivent utiliser un projet Firebase distinct du projet production `presto-app-74abe`.

## Secrets GitHub attendus

Créer un environnement GitHub nommé `staging`, puis y ajouter :

- `FIREBASE_STAGING_PROJECT_ID` : identifiant du projet Firebase staging ;
- `FIREBASE_STAGING_TOKEN` : jeton ayant accès uniquement au projet staging.

Ne jamais placer l'identifiant production dans `FIREBASE_STAGING_PROJECT_ID`.

## Vérification

Exécuter manuellement le workflow **Firebase staging readiness**. Il vérifie :

1. la présence des deux secrets ;
2. que le projet n'est pas `presto-app-74abe` ;
3. que le jeton peut lister et atteindre le projet staging.

## Configuration minimale du projet staging

Activer les mêmes familles de services que la production, avec des données de test uniquement :

- Authentication ;
- Firestore ;
- Functions ;
- Hosting ;
- Storage ;
- App Check ;
- Remote Config ;
- Cloud Messaging si les tests le nécessitent.

Les clés Stripe, Brevo, Resend et autres fournisseurs doivent être des clés de test ou des comptes sandbox dédiés.

## Interdictions

- aucune donnée utilisateur réelle ;
- aucun secret production ;
- aucun webhook Stripe production ;
- aucune preview GitHub sur `presto-app-74abe`.

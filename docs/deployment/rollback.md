# Procédure de rollback production

## Quand déclencher

Déclencher un rollback lorsqu’une release provoque notamment :

- indisponibilité ou écran blanc ;
- échec massif de connexion, publication, messagerie ou paiement ;
- hausse significative des erreurs ou de la latence ;
- règles Firebase trop permissives ou trop restrictives ;
- corruption ou suppression inattendue de données.

## Priorité immédiate

1. Suspendre les nouveaux déploiements.
2. Identifier le dernier commit sain sur `main`.
3. Conserver les logs, identifiants de workflow, métriques et horodatages.
4. Évaluer séparément Hosting, Functions, règles, index et données.
5. Restaurer uniquement les composants nécessaires.

## Hosting

Chaque workflow de production conserve un artefact nommé :

```text
production-release-<commit-sha>
```

Télécharger l’artefact du dernier commit sain, puis restaurer le contenu de `build/web` :

```bash
firebase deploy --project presto-app-74abe --only hosting --force
```

Une restauration Hosting ne restaure pas Functions, règles, index ou données.

## Code et Functions

Créer une branche de rollback depuis le dernier commit sain ou utiliser `git revert` sur le ou les commits fautifs. Ouvrir une PR urgente, exécuter tous les contrôles, puis fusionner dans `main` pour utiliser le pipeline normal.

Ne jamais réécrire l’historique de `main` avec un push forcé.

## Règles Firestore et Storage

Restaurer les fichiers versionnés du dernier commit sain :

```bash
firebase deploy --project presto-app-74abe --only firestore:rules,storage --force
```

Tester les règles dans Emulator Suite avant déploiement.

## Index Firestore

Les suppressions d’index peuvent interrompre des requêtes. Restaurer `firestore.indexes.json` depuis le commit sain, vérifier l’impact, puis redéployer :

```bash
firebase deploy --project presto-app-74abe --only firestore:indexes --force
```

## Données

Un rollback de code ne restaure pas les documents supprimés ou modifiés. Utiliser les exports Firestore, l’historique métier et les journaux d’audit. Toute restauration de données doit être testée sur un projet isolé avant production.

## Validation après rollback

- page d’accueil et manifeste accessibles ;
- authentification ;
- consultation et publication d’annonce ;
- messagerie ;
- checkout Stripe en environnement approprié ;
- Functions et webhooks sans hausse d’erreurs ;
- règles Firebase conformes ;
- métriques revenues au niveau de référence.

## Compte rendu

Dans les 48 heures, documenter la cause, l’impact, la détection, la chronologie, les mesures correctives, les tests manquants et les actions préventives.

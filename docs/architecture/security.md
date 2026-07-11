# Architecture de sécurité

## Frontières de confiance

Le client Flutter est considéré comme non fiable. Les décisions sensibles sont exécutées ou confirmées dans Cloud Functions : rôles, publication, modération, accès au téléphone, messagerie, abonnements, paiement, administration et suppression.

## Défense en profondeur

1. **Firebase Auth** identifie l’utilisateur.
2. **App Check** atteste l’application lorsque le service est activé.
3. **Firestore/Storage Rules** limitent les lectures et écritures directes.
4. **Cloud Functions** appliquent les règles métier et contrôles de rôle.
5. **Validation des entrées** normalise taille, format, type et valeurs autorisées.
6. **Rate limiting et idempotence** réduisent abus, doubles clics et relecture de requêtes.
7. **Journaux d’audit** tracent les actions sensibles sans secret ni contenu personnel inutile.
8. **CI/CD** teste règles, Functions, dépendances, CodeQL, bundle et garde-fous avant production.

## Données et secrets

- aucun secret Stripe, fournisseur email, clé privée ou credential Google dans le client ou le dépôt ;
- les secrets sont stockés dans les secrets Firebase/GitHub et injectés par environnement ;
- les clés publiques nécessaires au Web restent limitées à leur usage prévu ;
- les logs n’enregistrent jamais jetons Auth/App Check, moyens de paiement, messages, transcriptions ou données personnelles non indispensables ;
- toute rotation de secret doit inclure test staging, déploiement progressif et révocation de l’ancien secret.

## Rôles

Les contrôles doivent utiliser une source autoritaire backend. Un simple champ client ou document modifiable par l’utilisateur ne suffit pas. Toute modification de rôle doit :

- être réservée à une fonction administrateur ;
- vérifier la portée de l’administrateur ;
- synchroniser les custom claims ;
- produire une entrée d’audit ;
- invalider les sessions ou caches concernés lorsque nécessaire.

## Paiement

- la session Checkout est créée côté backend ;
- seules les URL HTTPS appartenant à Stripe sont ouvertes ;
- les webhooks sont vérifiés avec leur signature ;
- les événements sont traités de façon idempotente ;
- les droits sont dérivés de l’état backend, jamais d’un paramètre de retour du navigateur ;
- remboursements, impayés, résiliations et renouvellements recalculent les droits.

## Fichiers et médias

- contrôler type MIME réel, extension, taille et dimensions ;
- stocker dans un chemin dépendant de l’utilisateur ou du brouillon autorisé ;
- utiliser des noms générés, pas le nom fourni par l’utilisateur ;
- supprimer les brouillons abandonnés et fichiers orphelins ;
- analyser/modérer les images avant exposition publique lorsque requis.

## Messagerie et abus

- vérifier que l’émetteur appartient à la conversation ;
- appliquer blocage, archivage, suppression et signalement côté backend ;
- limiter taille, fréquence et types de pièces jointes ;
- empêcher la modification d’un message par un autre compte ;
- conserver les preuves strictement nécessaires aux signalements selon la politique de conservation.

## Administration

Les opérations destructrices exigent rôle, portée, confirmation explicite, traitement backend, résultat par élément et journal d’audit. Les historiques ne sont pas modifiables par le client administrateur.

## Contrôles CI

- `flutter analyze --fatal-infos` ;
- tests Flutter avec couverture globale et modules critiques ;
- build/tests Functions ;
- tests Firestore Rules dans Emulator Suite ;
- CodeQL et audit des dépendances ;
- vérification des patchs générés et absence de diff ;
- contrôle du bundle, artefact de release et smoke tests.

## Revue périodique

Tous les trimestres, vérifier les rôles, règles, secrets, dépendances, webhooks, politiques de conservation, comptes administrateurs, journaux d’audit, coûts anormaux et tentatives d’abus.

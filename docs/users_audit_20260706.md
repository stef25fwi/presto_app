# Audit Users 2026-07-06

Contexte : audit de la collection users après préparation de l’architecture abonnement, migration des champs manquants et premiers lots de nettoyage.

## Résumé global

- documents users scannés : 24
- documents avec champs abonnement manquants : 0
- canonical_user : 24
- test_or_seed : 0
- legacy_stub : 0
- noncanonical_but_hydrated : 0

Exports de référence :

- audit_logs/users_audit_export_20260706.json
- audit_logs/users_audit_export_20260706_post_cleanup.json
- audit_logs/users_audit_export_20260706_post_cleanup_v2.json
- audit_logs/users_audit_export_20260706_final.json

## Lecture opérationnelle

### À conserver

- canonical_user
- les comptes test_or_seed encore utiles à la QA ou aux scénarios de démonstration

### À auditer puis probablement nettoyer

- aucun legacy_stub restant dans Firestore users

### État test_or_seed

- les documents users test_or_seed ont été supprimés de Firestore
- sur 12 sources historiques test_or_seed, 2 comptes Firebase Auth existaient encore et ont été supprimés
- 10 comptes Auth étaient déjà absents au moment de l’audit final

## Exemples legacy_stub restants

- aucun document users legacy_stub restant dans Firestore

Profil historique : pas d’email, pas de createdAt, pas de displayName, pas de phone, pas de city.

## Exemples test_or_seed restants

- aucun document users test_or_seed restant dans Firestore

## Exemples canonical_user

Les identifiants réels ont été retirés de ce document : ce dépôt est public et
ces UID désignent de vrais comptes utilisateurs. Ils n'apportaient rien à la
lecture de l'audit (6 documents `canonical_user` pris comme échantillon).

Pour retrouver l'échantillon en cas de besoin, relancer l'audit sur la
collection `users` avec les outils de `tools/`.

## Scripts préparés

### Nettoyage legacy_stub

```bash
node tools/cleanup_legacy_user_stubs.cjs
node tools/cleanup_legacy_user_stubs.cjs --uid=A
node tools/cleanup_legacy_user_stubs.cjs --apply --limit=25
```

### Gestion test_or_seed

```bash
node tools/manage_test_seed_users.cjs
node tools/manage_test_seed_users.cjs --uid=team_ilipresto_demo
node tools/manage_test_seed_users.cjs --apply --limit=25
node tools/manage_test_seed_users.cjs --apply --with-auth --limit=25
```

## Recommandation

1. lancer d’abord les deux scripts en dry-run
2. conserver les exports d’audit comme preuve de nettoyage
3. ne pas supprimer automatiquement les canonical_user
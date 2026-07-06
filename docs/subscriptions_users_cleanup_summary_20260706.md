# Synthèse finale 2026-07-06

Cette synthèse couvre deux volets :

- préparation non bloquante des abonnements ilipresto
- nettoyage progressif des documents users legacy et test

## Abonnements

- section profil prête, pilotée par app_config/subscriptions
- tuile admin prête pour afficher ou masquer la section
- architecture des plans et des features en place
- aucune restriction fonctionnelle activée
- aucune intégration Stripe réelle ajoutée
- champs abonnement préparés sur les users existants

## Migration abonnement

- champs ciblés : subscriptionPlan, subscriptionStatus, subscriptionExpiresAt, phoneVerified, proVerified
- migration effectuée uniquement sur les champs manquants
- aucun plan existant n’est écrasé par les sauvegardes profil ou login

## Nettoyage users

État initial :

- total users : 91
- canonical_user : 24
- legacy_stub : 55
- test_or_seed : 12

État final Firestore users :

- total users : 24
- canonical_user : 24
- legacy_stub : 0
- test_or_seed : 0

État final Firebase Auth pour les anciennes sources test_or_seed :

- 12 sources historiques test_or_seed auditées
- 2 comptes Auth encore présents puis supprimés
- 10 comptes Auth déjà absents

## Exports et rapports

- audit_logs/users_audit_export_20260706.json
- audit_logs/users_audit_export_20260706_post_cleanup.json
- audit_logs/users_audit_export_20260706_post_cleanup_v2.json
- audit_logs/users_audit_export_20260706_final.json
- docs/users_audit_20260706.md

## Scripts utiles

```bash
node tools/seed_subscription_fields.cjs
node tools/cleanup_legacy_user_stubs.cjs
node tools/manage_test_seed_users.cjs
node tools/manage_test_seed_auth.cjs
```

## Garanties maintenues

- aucune restriction d’accès utilisateur activée
- aucun secret Stripe ajouté
- aucun paiement réel branché
- séparation claire entre nettoyage Firestore users et suppression Auth
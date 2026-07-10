# Déploiement ilipresto.web.app

Déploiement de production déclenché depuis `main` le 9 juillet 2026.

Contenu inclus :
- synchronisation complète des abonnements Stripe ;
- webhook Stripe signé et idempotent ;
- activation automatique des plans iliprestō+ et ilipro ;
- gestion des renouvellements, annulations, factures et impayés ;
- dernières améliorations des pages Mon compte et Mon abonnement.

Cible Firebase Hosting : `production` → `ilipresto` → https://ilipresto.web.app

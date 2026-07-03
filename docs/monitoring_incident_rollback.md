# Procédure monitoring / incident / rollback — ilipresto

## Objectif

Le socle monitoring doit permettre de voir rapidement :

- erreurs frontend ;
- erreurs Firebase Functions ;
- refus App Check ;
- paiements Stripe ;
- webhooks Stripe ;
- notifications FCM ;
- publication d'annonce ;
- messagerie ;
- uploads Storage ;
- actions admin ;
- connexion compte admin ;
- dernier build ;
- dernier commit.

## Collection Firestore

Collection :

```txt
app_monitoring_events
```

Champs utiles :

- `createdAt` : horodatage serveur ;
- `createdAtClient` : ISO UTC côté client ;
- `level` : `info`, `warning`, `error`, `critical` ;
- `scope` : frontend, app_check, stripe_payment, fcm, offer_publication, messaging, storage_upload, admin ;
- `action` : nom de l'événement ;
- `message` : résumé lisible ;
- `userId` : uid Firebase Auth ou `anonymous` ;
- `emailVerified` : booléen ;
- `platform` : web, android, ios, macos, windows, linux ;
- `releaseMode` : booléen ;
- `appBuild` : identifiant de build ;
- `gitCommit` : commit court ;
- `buildTime` : timestamp du build ;
- `data` : charge utile nettoyée.

## Utilisation

### Flutter

Initialiser une seule fois au démarrage avec `AppMonitoringService.instance.configureGlobalErrorHandling()` puis journaliser les événements métier via les méthodes spécialisées.

### Admin

Ouvrir le panneau admin puis la tuile "Monitoring" pour consulter les derniers événements des dernières 24h.

## Incident

1. Identifier le scope touché.
2. Filtrer les événements `error` et `critical`.
3. Relever `appBuild`, `gitCommit` et `buildTime`.
4. Vérifier si l'incident est lié à App Check, Auth, Firestore ou Functions.
5. Si le problème vient d'un déploiement récent, revenir au dernier build sain.

## Rollback

1. Restaurer la version applicative précédente.
2. Vérifier les règles Firestore et Storage si l'incident concerne les accès.
3. Si nécessaire, désactiver temporairement la fonctionnalité fautive côté UI ou Functions.
4. Refaire un contrôle dans la page Monitoring après le rollback.

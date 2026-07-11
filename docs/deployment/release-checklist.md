# Checklist de release production

## Avant fusion

- [ ] Portée de la release clairement décrite.
- [ ] Aucun secret, jeton ou donnée personnelle dans le diff.
- [ ] Correctifs générés déjà commités ; la CI n’écrit rien dans la branche.
- [ ] `flutter analyze --fatal-infos` vert.
- [ ] Tests Flutter avec couverture verts et seuil non régressif.
- [ ] Build et tests Functions verts.
- [ ] Tests Firestore Rules dans Emulator Suite verts.
- [ ] Build web et budget bundle verts.
- [ ] Preview Hosting consultée sur mobile, tablette et desktop pour toute modification UI.
- [ ] Documentation et ADR mis à jour si nécessaire.

## Parcours critiques

- [ ] Connexion Email, Google et Apple selon plateformes concernées.
- [ ] Consultation, filtres et détail d’annonce.
- [ ] Publication complète avec et sans IA.
- [ ] Photos, ville, code postal, téléphone et budget.
- [ ] Messagerie et notifications.
- [ ] Page abonnement, checkout, retour et activation des droits.
- [ ] Parcours entrepreneur, sauvegarde et PDF.
- [ ] Administration, suppression, statistiques et historique.

## Avant déploiement

- [ ] Migration de données testée et réversible, si applicable.
- [ ] Index Firestore prêts avant activation du code qui les utilise.
- [ ] Compatibilité ascendante des Functions et clients existants.
- [ ] Webhooks Stripe et email vérifiés.
- [ ] App Check et clés publiques configurés.
- [ ] Responsable du suivi post-déploiement identifié.

## Après déploiement

- [ ] Smoke tests Hosting réussis.
- [ ] Crashlytics et logs Functions sans pic d’erreurs.
- [ ] Latences principales dans les objectifs.
- [ ] Publication, messagerie et paiement contrôlés.
- [ ] Artefact `production-release-<sha>` disponible.
- [ ] Commit et workflow de release consignés.

## Décision

Une release présentant une régression sur un parcours critique doit être corrigée ou annulée ; elle ne doit pas être acceptée uniquement parce que le build compile.

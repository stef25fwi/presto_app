# Sauvegarde et restauration

## Objectifs

- restaurer les données critiques après erreur humaine, défaut logiciel ou incident cloud ;
- restaurer le code et l’hébergement indépendamment des données ;
- vérifier régulièrement que les sauvegardes sont lisibles ;
- limiter l’accès aux exports et tracer chaque restauration.

## Code et artefacts

GitHub est la source du code versionné. Chaque déploiement production conserve un artefact `production-release-<sha>` pendant 90 jours avec build Web, Functions compilées, règles, index et rapports qualité.

Une restauration de code utilise une PR de revert ou le dernier commit sain. Ne jamais forcer la branche `main`.

## Firestore

Configurer des exports planifiés vers un bucket dédié, chiffré et soumis à une politique de rétention. Les exports doivent inclure les collections critiques et être séparés de l’environnement staging.

À documenter dans l’exploitation :

- projet et bucket ;
- fréquence ;
- durée de conservation ;
- classe de stockage ;
- comptes de service autorisés ;
- alertes en cas d’échec ;
- coût estimé ;
- dernière restauration testée.

## Storage

- activer versioning ou politique de conservation lorsque pertinent ;
- sauvegarder les médias indispensables selon leur valeur métier ;
- distinguer médias publics, privés, temporaires et re-générables ;
- supprimer automatiquement les brouillons orphelins après le délai défini ;
- ne pas considérer un fichier public comme une sauvegarde.

## Auth et configuration

Les comptes Firebase Auth nécessitent une procédure d’export/import autorisée et protégée. Les secrets, Remote Config, index, règles et paramètres fournisseurs doivent être inventoriés séparément. Les secrets ne sont jamais inclus dans un artefact téléchargeable standard.

## Restauration Firestore

1. Déclarer l’incident et geler les écritures concernées si nécessaire.
2. Identifier l’heure du défaut et le dernier export sain.
3. Restaurer d’abord dans un projet isolé.
4. Vérifier schéma, volumes, références, règles et cohérence métier.
5. Définir si la restauration est complète ou sélective.
6. Préparer une compensation pour les écritures valides réalisées après l’export.
7. Exécuter avec un compte temporaire à privilèges minimaux.
8. Contrôler les agrégats, abonnements, historiques et fichiers liés.
9. Réactiver progressivement les écritures.
10. Révoquer l’accès temporaire et produire le compte rendu.

## Données de paiement

Stripe reste la source autoritaire des paiements. Après restauration Firestore, réconcilier clients, abonnements, factures et événements Stripe de manière idempotente. Ne jamais inventer un statut payé depuis une sauvegarde locale.

## Tests de restauration

Au minimum chaque trimestre :

- restaurer un export dans un projet isolé ;
- vérifier un échantillon d’utilisateurs, annonces, conversations, parcours et abonnements ;
- reconstruire les agrégats ;
- mesurer RTO et RPO réels ;
- documenter écarts et corrections.

## Cibles initiales

| Domaine | RPO cible | RTO cible |
|---|---:|---:|
| Code/Hosting | dernier commit validé | 1 h |
| Configuration versionnée | dernier commit validé | 2 h |
| Firestore critique | 24 h maximum, à réduire selon activité | 4–8 h |
| Storage critique | 24 h maximum | 8 h |
| Paiement | réconciliation Stripe | 4 h |

Ces cibles doivent être révisées après mesure de la traction et du coût d’une interruption.
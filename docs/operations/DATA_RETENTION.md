# Politique de rétention des données iliprestō

## Statut

Cette politique est versionnée dans `functions/src/modules/privacy/data_retention_policy.ts`.
Elle constitue une base technique à faire valider par le responsable de traitement et le conseil juridique avant toute purge destructive en production.

## Sécurité par défaut

La purge est inactive tant que `RETENTION_PURGE_ENABLED` n'est pas exactement `true`.
Même après activation, elle reste en simulation tant que `RETENTION_PURGE_DRY_RUN` n'est pas exactement `false`.

Une suppression réelle exige donc simultanément :

```text
RETENTION_PURGE_ENABLED=true
RETENTION_PURGE_DRY_RUN=false
```

La taille de lot est bornée entre 1 et 400 documents par `RETENTION_PURGE_BATCH_SIZE`.

## Durées techniques initiales

| Collection | Champ date | Durée | Catégorie | Validation juridique |
|---|---|---:|---|---|
| `app_monitoring_events` | `createdAt` | 90 jours | Exploitation | À confirmer |
| `notifications` | `createdAt` | 90 jours | Exploitation | À confirmer |
| `email_logs` | `createdAt` | 180 jours | Exploitation | À confirmer |
| `adminActions` | `createdAt` | 365 jours | Audit sécurité | Obligatoire |
| `deletedListings` | `deletedAt` | 365 jours | Audit/litiges | Obligatoire |
| `billing_invoices` | `createdAt` | 3 650 jours | Comptabilité | Obligatoire |

## Procédure avant activation

1. Valider les durées avec le registre des traitements et les obligations fiscales.
2. Exécuter un rapport en simulation sur staging.
3. Vérifier le volume par collection et les index Firestore nécessaires.
4. Sauvegarder les collections concernées.
5. Tester une restauration complète.
6. Activer sur production avec un faible lot et une alerte de volume.
7. Conserver les rapports d'exécution dans le journal d'exploitation.

## Interdictions

- Ne jamais purger les contenus utilisateurs ou données financières sans base légale validée.
- Ne jamais utiliser une date client non vérifiée comme unique critère de suppression.
- Ne jamais activer une purge destructive directement depuis une pull request.
- Ne jamais utiliser le projet Firebase production pour les essais de rétention.

# Modèle Firestore et conventions

## Principes

- les collections publiques contiennent uniquement les champs nécessaires à l’affichage ;
- les données privées, administratives et de paiement sont séparées et protégées ;
- les listes longues utilisent un tri stable, une limite et un curseur ;
- les statistiques utilisent des agrégats reconstructibles ;
- toute dénormalisation possède une source de vérité et une stratégie de réparation ;
- les timestamps métier sont écrits côté serveur lorsque l’ordre ou l’audit est important.

## Domaines principaux

| Domaine | Collections observées / attendues | Autorité d’écriture |
|---|---|---|
| Utilisateurs | `users` et sous-collections privées | utilisateur limité + backend |
| Annonces historiques | `offers` | backend / triggers hérités |
| Marketplace | `listings`, brouillons et médias associés | callables backend |
| Favoris | `users/{uid}/favorites`, compatibilité `favorites` et `favoriteOffers` | callable `toggleFavorite` |
| Conversations | `conversations/{id}/messages` | callables messagerie |
| Notifications | `notifications` et préférences utilisateur | backend |
| Parcours entrepreneur | `parcours`, `toolbox_journey_index`, `toolbox_journeys` | backend et utilisateur autorisé |
| Professionnels | `pros`, `pro_profiles` | propriétaire limité + vérification backend |
| Abonnements | documents utilisateur, factures et événements de billing | webhooks/callables backend |
| Administration | paramètres, signalements et journaux d’audit | backend administrateur |

Cette table doit être synchronisée avec le catalogue automatique Firestore et les règles déployées.

## Convention d’un document actif

```text
id
status: active | pending | archived | deleted
createdAt
updatedAt
createdBy / ownerId selon le domaine
schemaVersion
```

Les champs sensibles ne doivent pas être copiés dans un document public.

## Suppression logique

Pour les entités importantes :

```text
status: deleted
deletedAt
deletedBy
deletionReason
```

Avant une suppression physique éventuelle, enregistrer un résumé autorisé dans l’historique : type, identifiant, champs non sensibles nécessaires, auteur de l’action, date, motif et identifiant de corrélation.

## Pagination

Une requête de liste doit définir :

- filtre de portée ;
- `orderBy` stable ;
- `limit` raisonnable ;
- curseur `startAfterDocument` ou équivalent ;
- détection de fin ;
- prévention des chargements concurrents ;
- stratégie de rafraîchissement.

Éviter la pagination par offset, coûteuse et instable avec des données changeantes.

## Agrégats

Les tableaux de bord ne recomptent pas les collections complètes. Utiliser des documents d’agrégat par territoire, statut et période, mis à jour de manière idempotente. Prévoir une Function de reconstruction pour corriger une dérive.

## Index

- versionner tous les index dans `firestore.indexes.json` ;
- créer l’index avant d’activer le code qui en dépend ;
- supprimer un index seulement après vérification de toutes les versions clientes ;
- documenter la requête, l’écran et le coût attendu.

## Règles

Chaque collection doit avoir des tests positifs et négatifs : propriétaire, autre utilisateur, anonyme, rôle professionnel, administrateur limité et super-administrateur lorsque applicable.

## Compatibilité et migrations

- ajouter un `schemaVersion` aux documents complexes ;
- tolérer temporairement les anciens champs en lecture ;
- écrire uniquement le nouveau format ;
- migrer par lots bornés, idempotents et repris après échec ;
- mesurer le nombre de documents restants ;
- retirer la compatibilité seulement après vérification.

## Catalogue

Exécuter :

```bash
python3 tools/quality/audit_firestore_queries.py \
  --output-dir quality_reports/firestore
```

Le rapport signale listeners, lectures ponctuelles, limites, curseurs, agrégations et risques à examiner. Il ne remplace pas la mesure des lectures facturées dans Firebase.
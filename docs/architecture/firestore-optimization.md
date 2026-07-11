# Plan d’optimisation Firestore

## Objectifs

- réduire de 30 à 50 % les lectures évitables ;
- supprimer les requêtes N+1 ;
- paginer toutes les listes potentiellement longues ;
- réserver le temps réel aux flux qui le nécessitent ;
- produire les statistiques depuis des agrégats ;
- garantir la cohérence entre données actives, suppressions et historique.

## Catalogue automatique

Le script suivant génère un inventaire par fichier :

```bash
python3 tools/quality/audit_firestore_queries.py \
  --output-dir quality_reports/firestore
```

Il recense notamment :

- collections littérales ;
- filtres et tris ;
- limites et curseurs ;
- lectures ponctuelles ;
- listeners temps réel ;
- agrégations, batches et transactions ;
- signaux de lecture non bornée ou de N+1 à examiner.

## Ordre de traitement

1. Messagerie et notifications : conserver le temps réel, limiter la fenêtre chargée et paginer l’historique.
2. Consultation des annonces : lecture paginée, cache des filtres et aucun chargement intégral.
3. Favoris et compte : pagination et résumés dénormalisés.
4. Administration : agrégats, suppressions logiques, sélection multiple et historique.
5. Statistiques : documents de compteurs mis à jour par Functions ou agrégations ciblées.

## Pagination standard

Toute liste longue doit utiliser :

- un `limit` explicite ;
- un tri stable incluant un critère déterministe ;
- un curseur `startAfterDocument` ou équivalent ;
- une gestion de fin de liste ;
- une prévention des chargements simultanés ;
- un rafraîchissement qui réinitialise le curseur.

## Temps réel

Un listener est justifié pour :

- conversation ouverte ;
- badge de messages non lus ;
- notifications critiques ;
- résultat immédiat d’un paiement ou d’une modération.

Pour les catalogues, historiques, paramètres et statistiques, préférer une lecture ponctuelle avec rafraîchissement et cache.

## Suppression et historique

Les entités administratives importantes doivent supporter :

```text
status: active | archived | deleted
deletedAt
deletedBy
deletionReason
```

Avant suppression physique éventuelle, enregistrer un snapshot minimal dans une collection d’historique autorisée uniquement au backend. Les tableaux de bord actifs excluent immédiatement les éléments supprimés, tandis que l’historique conserve la trace.

## Agrégats

Ne pas relire toutes les communes, annonces ou utilisateurs à chaque ouverture d’un tableau de bord. Maintenir des documents d’agrégat par période, territoire et statut, avec une stratégie de reconstruction vérifiable.

## Critères d’acceptation

- aucune liste métier non bornée ;
- aucun listener sans propriétaire et cycle de vie clair ;
- aucun N+1 connu sur les parcours principaux ;
- tests Emulator Suite pour chaque règle et requête sensible ;
- index versionnés ;
- coût et latence comparés avant/après ;
- historique cohérent après suppression multiple.

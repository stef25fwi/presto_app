# Architecture cible des données des fiches parcours

## Principe

Une fiche générée résulte de la composition contrôlée de cinq sources. Aucun bloc métier ne doit être copié dans un pack de statut ou dans un bloc territorial.

## A. Socle universel

Contient uniquement les règles communes à toute création :

- Guichet unique ;
- immatriculation ;
- facturation et conservation ;
- livre de recettes ;
- déclaration de chiffre d'affaires ;
- CFE, TVA et compte dédié sous conditions ;
- organisation des échéances.

## B. Pack situation utilisateur

Un pack par situation : salarié, agent public, demandeur d'emploi, étudiant, retraité, minima sociaux, handicap, indépendant existant ou dirigeant.

Ce pack contient uniquement :

- cumul ou compatibilité ;
- autorisation, déclaration ou information ;
- droits sociaux et effets sur les aides ;
- courriers liés à la situation ;
- organismes liés au statut personnel.

## C. Pack activité

Une source métier unique par activité :

- définition et exclusions ;
- famille et sous-famille ;
- réglementation ;
- qualification ;
- code APE indicatif ;
- assurances ;
- matériel et risques ;
- documents commerciaux ;
- coûts indicatifs ;
- organismes métier ;
- sources officielles.

## D. Pack territoire

Contient uniquement :

- région et département ;
- chambres consulaires compétentes ;
- collectivités et dispositifs locaux ;
- aides territoriales ;
- particularités ultramarines ou locales vérifiées.

## E. Registre réglementaire daté

Les seuils et taux évolutifs sont référencés par identifiant et période de validité, jamais recopiés librement dans chaque fiche.

Champs cibles :

- `id` ;
- `label` ;
- `value` ;
- `effective_from` ;
- `effective_to` ;
- `source_url` ;
- `verified_at` ;
- `reviewer`.

## Règles de composition

1. Identifier l'activité par un identifiant stable, jamais seulement par recherche de mots-clés.
2. Charger un seul pack activité principal.
3. Ajouter le pack de situation correspondant au profil.
4. Ajouter le territoire demandé.
5. Résoudre les références réglementaires actives à la date de génération.
6. Exécuter les règles de compatibilité et de déduplication.
7. Refuser la publication en cas de blocage métier.
8. Générer le guide selon l'ordre chronologique commun.

## Stratégie de migration

- Conserver les champs historiques en lecture pendant la transition.
- Ajouter les métadonnées de révision aux fiches corrigées.
- Migrer famille par famille.
- Comparer l'ancien et le nouveau rendu sur le lot pilote.
- Activer le mode CI `--enforce` sur chaque famille terminée.
- Retirer les anciens champs seulement lorsque toutes leurs fiches sont migrées et archivées.

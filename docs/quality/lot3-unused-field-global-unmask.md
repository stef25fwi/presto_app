# Lot 3 — réactivation globale de `unused_field`

## Base

PR #1315, base `a6c5aefe9b3133e31d0185844d7d61f5617910b9`.

## Sonde réelle

Le retrait de `unused_field: ignore` dans `analysis_options.yaml` a été exécuté sur le SHA `71b88d090f0a74abffb782e2b948d3788971a84c`.

Le run `Pull request validation` `31255062500` a confirmé :

- dépendances Flutter : succès ;
- tests Flutter + couverture : succès ;
- seuils qualité : succès ;
- couverture des modules critiques : succès ;
- analyse Flutter : échec uniquement à cause de 20 diagnostics `unused_field` désormais exposés.

Les 20 diagnostics concernent uniquement des champs/constantes privés jamais lus. Le correctif de cette PR retire ces états morts et leurs écritures sans réintroduire de masque, sans diminuer de seuil et sans ajouter de skip/exclusion.

## Nettoyage appliqué

Le nettoyage atomique des 20 diagnostics a été appliqué par le commit `cf0737961056b08882d90706056a8bfe39e18315`. Les workflows temporaires utilisés uniquement pour appliquer ce patch se sont auto-supprimés et ne font pas partie du diff final de la PR.

## Certification attendue

Après le nettoyage, le SHA final doit repasser avec succès l’analyse Flutter, les tests, les quality gates, les contrôles Functions/Firestore, le build Web et tous les workflows requis avant fusion.

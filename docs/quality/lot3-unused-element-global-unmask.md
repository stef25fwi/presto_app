# Lot 3 — réactivation globale de `unused_element`

## Base

PR #1317, base `6a93f12f85892f865dfc5a060424ca57fe1a632f`.

## Sonde globale

La suppression de `unused_element: ignore` a été appliquée sans baisse de seuil, skip ou exclusion LCOV.

La sonde a exposé les déclarations privées réellement mortes puis leurs cascades. Le nettoyage a été effectué en trois vagues contrôlées :

- 57 déclarations privées initiales confirmées par l'analyseur ;
- 32 déclarations/champs devenus morts après la première vague ;
- 11 diagnostics finaux confirmés par l'analyseur, plus les écritures devenues sans lecteur.

Les imports devenus inutiles et un paramètre privé devenu inutile ont ensuite été corrigés avec les correctifs Dart standards.

## Validation locale CI du nettoyage

Le workflow ciblé `Lot 3 unused_element targeted fix v3`, run `31261207868`, a validé avec succès sur le contenu final :

- reproduction de la première vague : succès ;
- seconde cascade : succès ;
- nettoyage des retombées : succès ;
- suppression des 11 derniers diagnostics : succès ;
- `flutter analyze` : succès ;
- commit du nettoyage définitif : succès.

Le commit produit est `b88d2ace07ac321a13fb2de4089a1f108f92f7d8`.

Les trois workflows temporaires de nettoyage ont été supprimés dans ce même commit et ne figurent pas dans le diff final de la PR.

## Garde-fous

La certification finale exige encore que tous les workflows requis de la PR soient réellement exécutés et verts sur le SHA final retenu avant fusion. Cette preuve ne remplace pas la validation GitHub requise.

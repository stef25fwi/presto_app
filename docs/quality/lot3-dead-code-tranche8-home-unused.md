# Lot 3 — Code mort, tranche 8 — home

Base certifiée production : `93e801dda9685720f8e7d08c3df6a8085ee1eb79`.

## Cible

`lib/pages/home_page.dart`

## Sonde Flutter ciblée

Le workflow léger `Dart format quality` a retiré le masque global `unused_element, unused_field, unused_local_variable, unused_element_parameter` uniquement dans le workspace GitHub Actions, puis a exécuté :

`flutter analyze --fatal-infos lib/pages/home_page.dart`

Preuve archivée : run `31235994921`, artefact `lot3-home-unused-probe` (id `9015409641`).

Résultat :

- code de sortie analyseur : `0` ;
- aucun diagnostic `unused_*` ;
- sortie finale : `No issues found!`.

## Changement

Aucun symbole métier n'est supprimé. Le correctif retire uniquement le masque global `unused_*` devenu inutile dans `home_page.dart`.

## Garde-fous

- aucune route, Auth, App Check, Firebase, Firestore, Functions ou deep link modifiée ;
- aucun seuil qualité abaissé ;
- aucun skip/exclusion ajouté ;
- aucune mission LCOV créée ou relancée ;
- fusion uniquement après validation complète du SHA final.

# Lot 3 — Code mort, tranche 7 — compte

Base : `f873b0845f9ca691e9e7bba1ac23e5a938af9221`.

## Cible

`lib/pages/account_page.dart`

## Preuve de code mort

Une première sonde Flutter 3.44.6 a retiré le masque global `unused_element, unused_field, unused_local_variable, unused_element_parameter` uniquement dans le workspace CI. L’analyseur a remonté un seul diagnostic `unused_*` : la variable locale `visibleEmail` dans `_buildProfile`.

Avant application, la tranche vérifie aussi que `_profileEmail` reste réellement lu pendant l’hydratation via `fallbackValues: <String>[_profileEmail, user.email ?? '']`. La suppression de `visibleEmail` ne neutralise donc pas la gestion de l’adresse e-mail du profil.

Le patch supprime uniquement ce bloc local mort et le masque global `unused_*` de `account_page.dart`.

## Validation requise avant fusion

La PR finale doit réussir sur son SHA exact :

- `flutter analyze --fatal-infos` ;
- tests Flutter requis par la validation PR ;
- garde-fous architecture, sécurité, Firestore, App Check et production ;
- build Web requis ;
- aucun seuil abaissé, aucun skip/exclusion ajouté.

## Lot 1

Le Lot 1 LCOV reste en pause. Cette tranche ne crée, ne relance et ne fusionne aucune mission LCOV.

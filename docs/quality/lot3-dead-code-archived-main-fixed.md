# Lot 3 — Code mort — suppression de `dev/archive/main_fixed.dart`

## Base

Cette tranche part du commit `2d823dc4537444382ebbfc7550ae50689a10908f`, issu de la fusion validée de la PR #1309.

## Constat

`dev/archive/main_fixed.dart` est un ancien fragment manuel de `main.dart` conservé dans `dev/archive/`. Le fichier contient des imports volontairement invalides masqués par `// ignore_for_file: uri_does_not_exist` et se termine par des commentaires de reconstruction manuelle (`À copier depuis main.dart...`). Il ne constitue donc pas une unité de production exploitable.

Une recherche du chemin/nom `main_fixed.dart` dans le dépôt ne retourne aucun consommateur ou import.

## Changement

- suppression de `dev/archive/main_fixed.dart` uniquement ;
- ajout de cette preuve de sûreté.

## Garde-fous

- aucune route modifiée ;
- aucune logique Auth, App Check, Firebase, Firestore, Functions ou deep link modifiée ;
- aucun seuil qualité, skip ou exclusion ajouté ;
- aucune mission LCOV créée, relancée ou fusionnée ;
- fusion uniquement après tous les contrôles requis verts sur le SHA final exact de la PR.

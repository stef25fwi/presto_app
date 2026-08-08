# Lot 3 — Code mort, tranche 6

Base : `ace7a1024f71101e0bb9925005f5cc6daec0251f`.

## Cible

`lib/pages/account_page.dart`

## Suppressions prouvées

Deux wrappers privés sans consommateur ont été supprimés :

- `_loadUserProfile(User user, {int attempt = 0})`, simple délégation vers `_startInstantProfileHydration(user)` ;
- `_toggleFavoriteSubcategory(User user, String subcategory)`, ancien chemin de mutation remplacé par les pickers et `_applyDraftFavorites`.

La recherche dans le contenu complet du fichier ne retournait qu'une occurrence pour chacun de ces symboles : leur déclaration.

## Garde-fous

- aucune logique Auth, App Check, Firebase, Firestore, Functions ou deep link modifiée ;
- aucun seuil qualité modifié ;
- aucun skip/exclusion ajouté ;
- aucune mission LCOV créée ou relancée ;
- le workflow temporaire d'application atomique s'est auto-supprimé avant ouverture de PR.

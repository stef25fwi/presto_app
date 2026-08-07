# Lot 3 — Code mort — tranche 2

## Suppression

`lib/google_places_config.dart` a été supprimé.

## Preuve de code mort

Le fichier ne contenait qu'une constante `kGooglePlacesApiKey` vide et marquée `@Deprecated`, avec instruction d'utiliser le proxy Cloud Functions pour Google Places.

Avant suppression :
- recherche du symbole `kGooglePlacesApiKey` : aucun consommateur hors de sa propre définition ;
- recherche de `google_places_config.dart` : aucun import dans le dépôt.

Cette suppression ne modifie aucune route, Auth, App Check, Firebase, deep link ou logique métier. Aucun seuil qualité, skip ou exclusion n'est ajouté.

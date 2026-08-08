# Lot 3 — Code mort, tranche 5

Base : `550cc3628f4eb23ee9a1f7e3d8ddfa8472b42592`.

## Cible

`lib/pages/account_page.dart`

## Suppressions prouvées

Deux helpers privés étaient sans consommateur :

- `_isAdminAccessDenied(Object?)`
- `_isAdminAccessUnauthenticated(Object?)`

La recherche dans le contenu complet du fichier retournait exactement une occurrence pour chacun, correspondant à leur seule déclaration. Le helper `_adminErrorDetail(Object?)`, lui, est conservé car il possède plusieurs appels dans l'UI admin.

## Garde-fous

- aucune logique Auth, App Check, Firebase, Firestore, Functions ou deep link modifiée ;
- aucun seuil qualité modifié ;
- aucun skip/exclusion ajouté ;
- aucune mission LCOV créée ou relancée ;
- le workflow temporaire utilisé uniquement pour appliquer le patch atomique s'est auto-supprimé avant l'ouverture de la PR.

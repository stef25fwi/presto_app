# Lot 3 — Code mort, tranche 8 — flag profil

Base : `93e801dda9685720f8e7d08c3df6a8085ee1eb79`.

## Cible

`lib/pages/account_page.dart`

## Preuve

Le symbole privé `_profileLoadRequested` comportait exactement cinq occurrences :

- une déclaration `bool` initialisée à `false` ;
- quatre affectations (`false` ou `true`) ;
- aucune lecture, aucune condition, aucun rendu et aucun appel consommateur.

Le patch fail-fast a vérifié ces formes avant suppression et a refusé toute autre occurrence. Le workflow temporaire s’est ensuite auto-supprimé.

## Diff métier

Cinq lignes supprimées dans `account_page.dart`, sans ajout métier.

## Garde-fous

- aucun seuil qualité modifié ;
- aucun skip ou exclusion ajouté ;
- aucun changement Auth, App Check, Firebase, Firestore, Functions, routing ou deep link ;
- fusion uniquement après CI complète verte sur le SHA final ;
- Lot 1 LCOV conservé en pause.

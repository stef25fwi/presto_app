# Lot 3 — Code mort, tranche 7

Base : `f873b0845f9ca691e9e7bba1ac23e5a938af9221`.

## Cible

`lib/pages/account_page.dart`

## Suppression prouvée

Le champ privé `_profileLoadRequested` était un état mort.

La vérification fail-fast a confirmé que toutes ses occurrences étaient limitées à :

- une déclaration initialisée à `false` ;
- une affectation à `false` lors de la réinitialisation du profil ;
- trois affectations à `true` pendant les chemins de chargement/synchronisation.

Aucune occurrence n'était une lecture, une condition, un rendu, un argument ou un retour. La suppression retire donc uniquement un état jamais consommé, sans modifier le comportement.

## Diff métier

- 1 fichier de production modifié ;
- 5 lignes supprimées ;
- 0 ligne métier ajoutée.

## Garde-fous

- aucune route modifiée ;
- aucune logique Auth, App Check, Firebase, Firestore, Functions ou deep link modifiée ;
- aucun seuil qualité abaissé ;
- aucun skip ou exclusion ajouté ;
- aucune mission LCOV créée, relancée ou fusionnée ;
- le workflow temporaire utilisé pour appliquer et vérifier la suppression a été retiré avant le diff final.

La tranche ne doit être fusionnée que lorsque tous les contrôles requis du SHA final sont verts.

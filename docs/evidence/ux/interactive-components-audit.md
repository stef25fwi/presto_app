# Audit des composants interactifs personnalisés

## Statut

- Date : 2026-08-02
- Point 18/18 : 2 — UX/UI et design system
- Sous-lot : 2B — clavier et sémantique
- Statut : **en cours**

## Problème traité

Plusieurs surfaces utilisaient directement `GestureDetector`. Ce composant gère correctement le tactile et la souris, mais ne garantit pas à lui seul :

- une activation par Entrée et Espace ;
- un focus visible ;
- un rôle de bouton pour le lecteur d’écran ;
- l’annonce des états sélectionné, désactivé ou doté d’un badge ;
- l’absence de double activation lorsque plusieurs détecteurs sont imbriqués.

## Composant commun

`lib/widgets/presto_accessible_action.dart` fournit maintenant :

- rôle sémantique de bouton ;
- libellé, aide, valeur et état sélectionné ;
- activation tactile, souris, Entrée et Espace ;
- focus visible ;
- curseur souris ;
- état pressé ;
- désactivation cohérente ;
- possibilité d’exclure la sémantique visuelle redondante du contenu enfant.

## Composants migrés

| Composant | Parcours | Amélioration |
|---|---|---|
| `PrestoTapScale` | Home et actions réutilisées | Activation clavier, focus, libellé optionnel et retour pressé |
| `HomeCategoryChip` | Découverte/recherche | Annonce « Catégorie … » et aide explicite |
| `HomeBottomNavItem` | Navigation principale | Rôle d’onglet-bouton, sélection et nombre non lu annoncés |
| `PremiumInfoButton` | Information premium | Suppression du double détecteur, libellé accessible et activation clavier |

## Tests

`test/widgets/presto_accessible_action_test.dart` vérifie :

- une seule activation par clic ;
- activation par Entrée ;
- activation par Espace ;
- état désactivé ;
- rôle sémantique de bouton ;
- libellé, aide, valeur et sélection ;
- annonce du badge de navigation ;
- absence de double activation du bouton premium.

## Éléments restant à auditer

La recherche de `GestureDetector` montre encore des surfaces à traiter, notamment :

- contrôles de publication IA et microphone ;
- Hero et carrousels ;
- publication et consultation d’annonces ;
- compte et profil professionnel ;
- parcours Je me lance ;
- messagerie ;
- administration.

Ces éléments seront migrés ou justifiés par groupes de parcours. Les contrôles `keyboard-focus` et `screen-reader` restent `pending` tant que cette liste et les validations de parcours ne sont pas fermées.

## Critère de fermeture du sous-lot

- composant commun analysé et testé ;
- composants migrés sans régression ;
- tests Flutter complets verts ;
- liste restante documentée ;
- aucune déclaration prématurée des contrôles globaux clavier/lecteur d’écran.

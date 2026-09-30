# Consultation : panneau de filtres (U04)

## Problème

À partir du troisième critère, le debounce réutilisait l'action du bouton
« Rechercher ». Cette action refermait le panneau alors que la sélection venait
d'être appliquée, ce qui interrompait le parcours et obligeait à le rouvrir.

## Correction

- L'application automatique après le debounce met les résultats à jour et
  garde le panneau ouvert pour poursuivre ou ajuster la recherche.
- Le bouton « Rechercher » garde son comportement de validation explicite et
  replie le panneau.
- Le repli lors du défilement des résultats, la réinitialisation des filtres
  et le filtre département du profil conservent leur comportement.

## Vérification

Un test widget charge la liste locale des villes, choisit une catégorie, une
région et une ville (trois critères), constate l'application différée sans
repli, puis vérifie que « Rechercher » referme toujours le panneau.

La CI doit confirmer analyse, tests, seuils de couverture et compilation web.

## Portée

Le hero Home et ses trois affiches restent hors de ce lot. Aucun changement
Firestore, publication, règle de sécurité ou asset.

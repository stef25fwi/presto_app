# ADR-0001 — Garde-fous qualité progressifs

## Statut

Accepté.

## Contexte

Le dépôt dispose déjà de validations Flutter, Functions, règles Firestore et build web. En revanche, la couverture n’est pas mesurée comme un indicateur obligatoire et plusieurs diagnostics de l’analyseur sont ignorés globalement. Activer immédiatement des seuils élevés rendrait les branches impossibles à fusionner sans réduire d’abord la dette existante.

## Décision

1. Générer une baseline automatique à chaque PR et sur `main`.
2. Mesurer la couverture avec LCOV.
3. Conserver un seuil minimal explicite dans `quality/quality-gates.json`.
4. Augmenter ce seuil uniquement lorsque `main` respecte durablement le palier suivant.
5. Interdire toute baisse de seuil sans décision documentée.
6. Refactoriser les fichiers surdimensionnés après ajout de tests de caractérisation.

## Conséquences

La qualité devient visible immédiatement sans provoquer une réécriture risquée. La cible finale reste 70 % globalement et 85 % sur les modules critiques.

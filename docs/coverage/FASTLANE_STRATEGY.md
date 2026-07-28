# Coverage FastLane

## Objectif

Monter la couverture globale réelle vers 90 % avec deux voies maximum, sans perdre du temps sur des micro-cibles tant que de gros gains testables existent.

La source de vérité reste exclusivement `flutter test --coverage` et son fichier `coverage/lcov.info`. FastLane ne retire aucune ligne, ne modifie pas le dénominateur et n’autorise ni exclusion, ni `skip`, ni faux test, ni baisse de seuil.

## Logique de sélection

FastLane calcule pour chaque fichier de production :

- le nombre exact de lignes LCOV manquantes ;
- un indice de testabilité : logique pure, modèles et widgets injectables sont favorisés ;
- une pénalité pour les dépendances dures Firebase, plugins natifs, réseau et gros fichiers ;
- une priorité métier pour Paiement, Authentification, Publication, Messagerie et Administration ;
- un gain attendu rapporté à l’effort estimé.

Les fichiers sont regroupés en packs cohérents de quatre fichiers maximum. Une voie peut donc produire plusieurs dizaines de lignes en une seule PR au lieu d’ouvrir une PR par ligne.

## Seuils adaptatifs

| Couverture globale | Gain minimum attendu par voie |
|---|---:|
| moins de 80 % | 25 lignes |
| de 80 % à moins de 87,5 % | 10 lignes |
| à partir de 87,5 % | 2 lignes |

Une petite cible n’est autorisée tôt dans le processus que si elle complète un pack dépassant le seuil.

## Cycle d’exécution

1. Réutiliser l’artefact LCOV validé de la PR qui vient d’être fusionnée ; recalculer la suite complète uniquement si l’artefact est indisponible.
2. Parser toutes les lignes LCOV sans exclusion.
3. Maintenir au maximum deux missions ou PR `coverage/*` actives.
4. Affecter les deux packs au meilleur rendement, dans des sous-systèmes distincts lorsque possible.
5. Pendant l’écriture, exécuter les tests ciblés pour une boucle rapide.
6. Avant fusion, exécuter une seule validation globale : `flutter analyze --fatal-infos` puis `flutter test --coverage`.
7. Télécharger l’artefact et mesurer le gain réel.
8. Fusionner d’abord la PR au meilleur gain réel.
9. Fermer et recréer l’autre voie sur le nouveau `main`.
10. Une PR à zéro gain est fermée sans fusion et remplacée immédiatement.

## Garde-fous

- deux voies maximum ;
- aucune fusion sans artefact LCOV parsé ;
- aucune annonce de gain basée seulement sur le nombre de tests ;
- aucun mélange avec Dependabot ou une fonctionnalité produit non liée ;
- fermeture automatique des missions FastLane sans PR ni preuve après deux heures ;
- commentaire dans #553 uniquement lorsqu’une mission est créée, libérée ou lorsque 90 % est atteint.

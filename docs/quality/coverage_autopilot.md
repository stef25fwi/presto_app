# Coverage Autopilot

`Coverage Autopilot` mesure la couverture Flutter réelle et entretient deux files
de travail indépendantes sur les cinq parcours critiques.

## Périmètres traités

Les fichiers sont définis précisément dans
`quality/critical-coverage.json` :

1. abonnements et paiement ;
2. authentification ;
3. publication d'annonces ;
4. messagerie ;
5. administration et modération.

La cible de ces cinq périmètres est **100 % LCOV réel**. Les seuils
`minimum_percent` restent des garde-fous de non-régression ; ils ne remplacent
pas l'objectif final.

À chaque mesure, l'agent sélectionne un fichier rentable encore incomplet dans
chaque périmètre. La factory remplit au maximum deux lanes indépendantes à la
fois. Lorsqu'un fichier atteint 100 %, le cycle suivant choisit le fichier
incomplet suivant du même parcours.

## Déclenchement

Le workflow `.github/workflows/coverage-agent.yml` s'exécute :

- chaque heure ;
- après une modification de `main` touchant le code, les tests ou la
  configuration de couverture ;
- après une validation de pull request réussie ;
- manuellement depuis GitHub Actions.

Une mesure complète est évitée lorsque `main` n'a pas changé, sauf lancement
manuel avec `force_measure=true`.

## Objectif global

La valeur par défaut reste `80 %` de couverture globale LCOV. La mission
continue toutefois si cet objectif global est atteint mais qu'au moins un des
cinq parcours critiques reste sous 100 %.

Pour modifier l'objectif global sans changer le code, créer la variable de
dépôt `COVERAGE_GLOBAL_TARGET`.

## Agent de codage

Le workflow crée jusqu'à deux issues structurées, une par lane disponible, avec :

- la couverture globale ;
- la couverture de chaque parcours critique ;
- un fichier exact et indépendant par worker ;
- les lignes non couvertes ;
- une branche `coverage/w1-*` ou `coverage/w2-*` réservée ;
- les commandes de validation et les garde-fous.

Pour assigner automatiquement la mission, définir la variable de dépôt
`COVERAGE_AGENT_ASSIGNEE` avec l'identifiant GitHub exact du compte ou de
l'agent de codage disponible. Sans cette variable, la mission reste ouverte et
prête à être prise en charge, sans assignation erronée.

## Garde-fous

- deux issues `coverage-worker` et deux PR `coverage/w*` actives au maximum ;
- les deux workers doivent viser des fichiers indépendants ;
- les validations peuvent s'exécuter en parallèle, mais les fusions restent
  séquentielles avec revalidation du second worker sur le nouveau `main` ;
- aucun abaissement de seuil ;
- aucune exclusion LCOV artificielle ;
- aucun `skip`, test vide ou faux succès ;
- aucun push automatique direct sur `main` ;
- validation ciblée pendant le développement, puis
  `dart format`, `flutter analyze --fatal-infos` et
  `flutter test --coverage` avant la PR ;
- aucune régression globale ou par parcours.

## Validation locale du sélecteur

```bash
python3 -m unittest tools/coverage/test_coverage_agent.py
```

## Cycle attendu

1. mesurer `flutter test --coverage` sur `main` ;
2. calculer l'état des cinq parcours ;
3. sélectionner deux fichiers précis et indépendants ;
4. créer jusqu'à deux missions, une par lane libre ;
5. produire jusqu'à deux PR de tests ;
6. vérifier la couverture avant/après de chaque worker ;
7. fusionner la première PR verte ;
8. revalider puis fusionner la seconde PR verte ;
9. recommencer jusqu'à 100 % sur les cinq parcours et au moins 80 % global.

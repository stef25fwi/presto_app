# Coverage Autopilot

`Coverage Autopilot` mesure la couverture Flutter réelle, sélectionne une cible prioritaire et crée une seule tâche de couverture active à la fois.

## Priorités

1. paiements et Stripe ;
2. authentification ;
3. publication d'annonces ;
4. messagerie ;
5. reste du code de production.

À priorité égale, le fichier ayant le plus faible pourcentage de couverture est sélectionné.

## Déclenchement

Le workflow `.github/workflows/coverage-agent.yml` s'exécute :

- toutes les heures, à la minute 17 ;
- après une modification de `main` touchant le code ou les tests ;
- manuellement depuis GitHub Actions.

GitHub n'exécute les planifications que lorsque le workflow est présent sur la branche par défaut. Le cycle horaire commencera donc après fusion de la PR d'installation.

## Objectif

La valeur par défaut est `80 %` de couverture globale LCOV. Pour la modifier sans changer le code, créer la variable de dépôt :

- nom : `COVERAGE_GLOBAL_TARGET` ;
- valeur initiale conseillée : `25`, puis `40`, `60` et `80` progressivement.

Un lancement manuel peut également fournir un objectif temporaire.

## Agent de codage

Le workflow crée une issue structurée avec la mesure LCOV, le fichier cible, les lignes non couvertes et les garde-fous.

Pour assigner automatiquement cette issue à un agent disponible dans le dépôt, créer la variable :

- nom : `COVERAGE_AGENT_ASSIGNEE` ;
- valeur : identifiant GitHub exact de l'agent ou du compte chargé des tests.

Si la variable est absente, la tâche est créée sans assignation. Le système de mesure et de sélection continue de fonctionner normalement.

## Garde-fous

- une seule issue `coverage-agent` ouverte à la fois ;
- aucune baisse de seuil ;
- aucune exclusion LCOV ajoutée par l'agent ;
- aucun `skip` ou test vide ;
- aucun push automatique direct sur `main` ;
- conservation de l'artefact `lcov.info` pendant 30 jours ;
- nouveau cycle après fermeture de la tâche précédente et nouvelle exécution du workflow.

## Validation locale du sélecteur

```bash
python3 -m unittest tools/coverage/test_coverage_agent.py
```

## Cycle attendu

1. mesure de `flutter test --coverage` ;
2. sélection déterministe de la prochaine cible ;
3. création d'une issue de travail ;
4. production d'une PR par l'agent assigné ;
5. validation CI et fusion ;
6. fermeture de l'issue ;
7. sélection de la cible suivante au prochain cycle.

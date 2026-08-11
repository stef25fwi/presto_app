# Correctif Coverage Autopilot — 2026-08-11

Ce correctif traite le blocage où une issue `coverage-worker` non assignée pouvait être considérée comme une lane active alors qu'aucun code n'était produit.

## Changements

- la Coverage Factory ne compte plus les issues non assignées comme workers actifs ;
- les missions créées sont assignées par défaut au propriétaire du dépôt lorsque `COVERAGE_AGENT_ASSIGNEE` n'est pas défini ;
- une ancienne mission identique non assignée est fermée avant de recréer une mission fraîche ;
- le superviseur utilise désormais 2 workers par défaut, comme `Coverage Factory 5x2` ;
- les missions orphelines sont fermées automatiquement et libèrent immédiatement leur lane ;
- le label `coverage-stalled` est créé de manière déterministe avant utilisation.

## Limite GitHub Copilot

L'affectation automatique d'une issue au GitHub Copilot coding agent nécessite une authentification utilisateur compatible avec l'API d'agent. Le `GITHUB_TOKEN`/GitHub App du workflow ne doit pas être considéré comme un substitut à ce jeton utilisateur. En l'absence de ce jeton, la mission reste attribuée au propriétaire du dépôt et peut être traitée par un agent connecté ou manuellement.

## Garde-fous conservés

- aucun abaissement de seuil LCOV ;
- aucune exclusion LCOV ;
- aucun test `skip` ou faux succès ;
- fusion séquentielle des PR `coverage/w*` après CI verte.

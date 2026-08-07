# Lot 3 — Code mort — tranche 1

## Objectif

Supprimer les exports de compatibilité historiques de `lib/main.dart` devenus inutiles après la certification du Lot 2.

## Preuve de sûreté

Le garde-fou `tools/quality/check_flutter_entrypoint_coupling.py` impose une allowlist vide et interdit les imports de `lib/main.dart` depuis `lib/` et `test/`.

La suppression ne modifie aucun import runtime du point d'entrée, aucune route, Auth, App Check, Firebase, deep link ou logique métier.

## Changement

`lib/main.dart` devient un point d'entrée pur :

- import de `PrestoApp` ;
- import du bootstrap ;
- délégation directe à `bootstrapPrestoApp(const PrestoApp())`.

Aucun seuil qualité n'est modifié et aucun test n'est ignoré.

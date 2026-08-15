# Preuve — App Check appliqué sur les Cloud Functions

Contrôle : `app-check-functions-enforced` (`quality/security-controls.json`).

## Nature de la preuve

Reproductible en CI et en local. Contrairement aux autres API Firebase,
l'enforcement App Check des Cloud Functions **ne se règle pas dans la console** :
la page App Check n'y propose qu'un lien de documentation. Il s'agit d'un
paramètre de code, `enforceAppCheck` sur chaque callable.

## Vérification automatisée

```
$ node tools/quality/check_functions_app_check.mjs
{
  "scannedFileCount": 169,
  "callableCount": 83,
  "violations": [],
  "exceptions": []
}
```

**83 callables, aucune violation, aucune exception.** Ce gate s'exécute en
intégration continue via le job `app-check-source`
(`.github/workflows/app-check-source.yml`), vert sur `main`.

## Politique fail-closed en production

`functions/src/config/app_check_policy.ts` :

```ts
if (isEmulator) return false;
// Production is fail-closed: environment flags may not disable App Check.
if (isProduction) return true;
```

En production, l'enforcement est donc structurellement non désactivable : ni
`ENFORCE_APP_CHECK` ni le mode sans échec ne peuvent l'inhiber. Un garde-fou
supplémentaire (`assertProdSecurityConfig`, `env.ts` l. 62) journalise
`CRITICAL_APP_CHECK_DISABLED` si l'invariant était rompu.

Le comportement de `resolveAppCheckEnforcement` est couvert par
`functions/src/config/app_check_policy.test.ts`.

## Comment rejouer

```bash
node tools/quality/check_functions_app_check.mjs
npm --prefix functions test
```

Vérifié le 2026-08-15.

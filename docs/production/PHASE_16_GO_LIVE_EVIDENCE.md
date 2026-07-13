# Phase 16 — clôture production et go-live

## Objectif

Transformer la décision de mise en production en contrôle explicite, traçable et réversible.

## Contrôles

Le registre `quality/production_go_live_readiness.json` suit la revue des phases précédentes, le tag release candidate, les smoke tests production, le rollback, les contacts incident, le support, les tableaux de bord, les éléments légaux et stores, la décision go/no-go et la revue post-lancement.

Le statut `verified` exige une preuve versionnée. Les validations qui nécessitent un environnement réel restent `pending` jusqu’à production de la preuve.

## Exécution

```bash
node tools/quality/check_production_go_live_readiness.mjs
node --test tools/quality/check_production_go_live_readiness.test.mjs
node tools/quality/check_production_go_live_readiness.mjs --enforce
```

Le mode standard valide la cohérence du registre. Le mode `--enforce` bloque tant qu’un contrôle n’est pas vérifié.

## Critère de clôture

La phase est clôturable lorsque la release candidate est identifiée, les smoke tests et le rollback sont éprouvés, les responsabilités opérationnelles sont confirmées et la décision go/no-go est consignée avec ses preuves.

# Phase 15 — scalabilité, coûts et résilience

## Objectif

Rendre mesurables la montée en charge, les budgets d’infrastructure et la capacité de reprise après incident.

## Contrôles

Le registre `quality/scalability_resilience_readiness.json` suit les paliers de charge 1 000, 10 000 et 50 000 sessions, les budgets Firestore/Functions/Storage, les alertes coûts, la sauvegarde/restauration, l’exercice chronométré, la stratégie régionale et les dépendances critiques.

Le statut `verified` exige une preuve versionnée. Les contrôles nécessitant une exécution réelle, des métriques Cloud ou une restauration complète restent `pending` jusqu’à production de la preuve.

## Exécution

```bash
node tools/quality/check_scalability_resilience_readiness.mjs
node --test tools/quality/check_scalability_resilience_readiness.test.mjs
node tools/quality/check_scalability_resilience_readiness.mjs --enforce
```

Le mode standard vérifie la cohérence du registre. Le mode `--enforce` échoue tant qu’un contrôle n’est pas vérifié.

## Clôture

La phase est clôturable quand les paliers de charge sont reproduits, les coûts sont bornés et alertés, et une restauration réelle respecte le RTO documenté.

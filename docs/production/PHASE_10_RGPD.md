# Phase 10 — RGPD et cycle de vie des données

## Objectif

Ne pas déclarer la conformité RGPD terminée sans preuve technique, fonctionnelle et documentaire.

## Contrôles suivis

- information utilisateur et politique de confidentialité ;
- export portable des données ;
- suppression de compte orchestrée côté serveur ;
- politique de conservation par collection ;
- journal d'audit non sensible des suppressions ;
- registre des sous-traitants et transferts ;
- test E2E export puis suppression.

## Commandes

Inventaire non bloquant :

```bash
node --test tools/quality/check_rgpd_readiness.test.mjs
node tools/quality/check_rgpd_readiness.mjs
```

Décision de clôture de phase :

```bash
node tools/quality/check_rgpd_readiness.mjs --enforce
```

Le mode strict doit rester rouge tant que chaque contrôle n'est pas `implemented` avec au moins une preuve exploitable.

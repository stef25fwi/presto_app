# Observabilité et SLO — phase 9

## Objectif

Fournir un cadre mesurable pour la disponibilité, les erreurs clientes, les incidents et les alertes d’iliprestō.

## SLO initial

- Disponibilité web et API : au moins 99,5 % sur une fenêtre glissante de 30 jours.
- Taux d’erreurs critiques : inférieur à 1 % des sessions actives.
- Temps de détection d’un incident critique : inférieur à 15 minutes.
- Temps de prise en charge : inférieur à 30 minutes pendant les heures de support.

## Contrôles

Le registre `quality/observability_slo.json` distingue les éléments implémentés des preuves opérationnelles encore manquantes.

Exécution d’inventaire :

```bash
node tools/quality/check_observability_slo.mjs
```

Décision stricte avant go-live :

```bash
node tools/quality/check_observability_slo.mjs --enforce
```

Le mode strict doit rester rouge tant que les tests synthétiques, le routage d’alertes et un exercice d’incident documenté ne sont pas fournis.

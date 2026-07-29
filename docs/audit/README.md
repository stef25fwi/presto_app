# Audit qualité iliprestō

La phase 0 transforme la qualité du dépôt en données reproductibles. Elle ne modifie pas le comportement fonctionnel de l’application.

## Exécution locale

```bash
flutter pub get
flutter test --coverage
python3 tools/quality/audit_repository.py --output-dir quality_reports/local --enforce
```

Les rapports générés sont :

- `baseline.json` : métriques exploitables par automatisation ;
- `baseline.md` : résumé lisible ;
- `oversized-files.md` : classement des fichiers à découper ;
- `technical-debt-register.md` : registre initial de dette technique.

## Politique de progression

Le seuil de couverture démarre au niveau réellement mesuré, puis monte par paliers jusqu’à 70 %. Les modules critiques — authentification, abonnements, paiement, publication, messagerie et administration — visent 85 % minimum.

Un seuil ne doit jamais être abaissé pour faire passer une PR. Toute exception doit être documentée dans un ADR et limitée dans le temps.

## Derniers audits

- [Audit complet — 2026-07-29](audit-complet-2026-07-29.md)

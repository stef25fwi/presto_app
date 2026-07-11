# Feuille de route vers un niveau de référence

## Phase 0 — Baseline et dette technique

- [x] Script d’audit reproductible.
- [x] Rapport des fichiers surdimensionnés.
- [x] Mesure LCOV dans GitHub Actions.
- [x] Registre de seuils versionné.
- [ ] Exécuter la baseline et enregistrer les valeurs réelles de `main`.

## Phase 1 — Architecture Flutter

- [ ] Classer les écrans par criticité et taille.
- [ ] Ajouter les tests de caractérisation.
- [ ] Extraire widgets, controllers et repositories sans changer les routes.
- [ ] Traiter en premier publication, consultation, détail, messagerie, abonnement et compte.

## Phase 2 — Couverture automatisée

- [ ] Monter les paliers 10 → 25 → 40 → 55 → 70 %.
- [ ] Atteindre 85 % sur les modules critiques.
- [ ] Ajouter les tests Emulator Suite et les scénarios d’intégration.

## Phase 3 — CI/CD

- [ ] Rendre les workflows de validation strictement read-only.
- [ ] Ajouter staging et preview Hosting.
- [ ] Ajouter smoke tests, contrôle de bundle et rollback documenté.
- [ ] Protéger `main` par checks obligatoires et revue.

## Phase 4 — Performance

- [ ] Réduire la portée des rebuilds et calculs dans `build()`.
- [ ] Définir cache mémoire/local et invalidation.
- [ ] Paginer annonces, messages, notifications, favoris et historiques.
- [ ] Précharger seulement les données probables.
- [ ] Mesurer p50/p95 des pages et Functions.

## Phase 5 — Firestore

- [ ] Cataloguer toutes les requêtes et index.
- [ ] Supprimer les N+1 et listeners permanents inutiles.
- [ ] Mettre en place agrégats, suppressions logiques et audit logs.
- [ ] Tester les règles par rôle et par propriétaire.

## Phase 6 — Documentation et exploitation

- [ ] Compléter diagrammes, runbooks, sauvegarde et reprise.
- [ ] Ajouter ADR pour les décisions majeures.
- [ ] Instrumenter Crashlytics, Performance, Analytics et alertes.

## Phase 7 — Traction commerciale

- [ ] Instrumenter visite → inscription → première valeur → abonnement → renouvellement.
- [ ] Fixer objectifs MAU, conversion, churn, MRR et coût d’acquisition.
- [ ] Lancer Guadeloupe, mesurer, puis répliquer territoire par territoire.

## Definition of Done

Une fonctionnalité est terminée lorsque le code est relu, les tests passent, la CI est verte, les métriques sont présentes, la documentation est à jour, l’accessibilité et les performances ont été vérifiées.

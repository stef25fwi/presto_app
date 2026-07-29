# iliprestō

Plateforme Flutter de services et micro-services locaux, déployée sur Web, Android et iOS, avec Firebase, Cloud Functions, Stripe, notifications et outils d’accompagnement à la création d’entreprise.

## Architecture

- **Client** : Flutter Web, Android et iOS.
- **Identité et sécurité** : Firebase Auth et App Check.
- **Données** : Cloud Firestore et Cloud Storage.
- **Backend** : Cloud Functions v2.
- **Paiement** : Stripe côté backend et webhooks vérifiés.
- **Communication** : Firebase Cloud Messaging et fournisseurs email.
- **Qualité** : Flutter analyze, tests Flutter, tests Functions, règles Firestore, budgets de bundle et audits automatisés.

La vue d’ensemble est disponible dans [`docs/architecture/system-overview.md`](docs/architecture/system-overview.md).

## Prérequis

- Flutter `3.44.6` pour reproduire les workflows GitHub Actions ;
- Dart compatible avec `pubspec.yaml` ;
- Node.js `22` pour les Functions ;
- Firebase CLI `13` pour les validations et déploiements.

## Installation locale

```bash
flutter config --enable-web
flutter pub get
npm --prefix functions ci
```

Les clés, secrets Firebase, Stripe, App Check et fournisseurs externes ne doivent jamais être ajoutés au dépôt.

## Validation

```bash
flutter analyze --fatal-infos
flutter test --coverage --reporter expanded
npm --prefix functions run build
npm --prefix functions test
npm --prefix functions run test:firestore
python3 tools/quality/audit_repository.py --output-dir quality_reports/local --enforce
```

Les objectifs de qualité et leurs paliers sont versionnés dans [`quality/quality-gates.json`](quality/quality-gates.json). La stratégie de tests se trouve dans [`docs/development/testing-strategy.md`](docs/development/testing-strategy.md).

## Build Web

```bash
bash tools/flutter_with_build_stamp.sh build web --release --no-wasm-dry-run
node tools/check_web_bundle_size.mjs
```

## Déploiement

Le déploiement web de production est assuré par GitHub Actions après validation complète sur `main`. Un déploiement manuel ne doit être réalisé qu’en procédure d’urgence documentée.

La publication mobile (AAB Play Store, IPA TestFlight) passe par des workflows manuels décrits dans [`docs/deployment/mobile-release.md`](docs/deployment/mobile-release.md).

## Documentation

- [Audit et baseline qualité](docs/audit/README.md)
- [Architecture système](docs/architecture/system-overview.md)
- [Feuille de route niveau de référence](docs/architecture/production-reference-roadmap.md)
- [Publication mobile Android et iOS](docs/deployment/mobile-release.md)
- [Checklist de release](docs/deployment/release-checklist.md)
- [Procédure de rollback](docs/deployment/rollback.md)
- [Décisions d’architecture](docs/adr/)

## Règle de contribution

Une fonctionnalité est terminée lorsque le code est relu, les tests passent, la CI est verte, la documentation et les métriques sont à jour, et les impacts accessibilité, sécurité et performance ont été vérifiés.

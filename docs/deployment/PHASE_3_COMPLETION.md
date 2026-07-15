# Phase 3 — finalisation CI/CD, staging et previews

## État livré par le dépôt

- CI de pull request en lecture seule ;
- builds Flutter Web reproductibles ;
- artefacts Web et diagnostics LCOV ;
- budgets bundle, CodeQL, formatage, contrôles Firestore et Analytics ;
- garde-fou Firebase refusant `presto-app-74abe` et tout projet ambigu ;
- workflow de preview dédié au projet staging ;
- workflow de builds Android/iOS avec publication Google Play et TestFlight optionnelle ;
- runbooks release, rollback et preuves de production.

## Configuration Firebase staging obligatoire

Créer un projet Firebase séparé dont l’identifiant contient explicitement `staging`, `preview`, `dev`, `test` ou `qa`, par exemple `ilipresto-staging`.

Le projet staging doit avoir ses propres ressources :

- Firebase Hosting ;
- Authentication et fournisseurs nécessaires aux tests ;
- Firestore, Storage et Functions séparés ;
- App Check avec une clé Web staging ;
- quotas, alertes et comptes de service distincts de la production.

Ne jamais rattacher le workflow de preview à `presto-app-74abe`.

## GitHub Environment `staging`

Créer l’environnement GitHub `staging`, puis ajouter :

- `FIREBASE_STAGING_PROJECT_ID` ;
- `FIREBASE_STAGING_TOKEN` ;
- `STAGING_APPCHECK_RECAPTCHA_SITE_KEY`.

Le garde-fou compare aussi le projet staging à `presto-app-74abe` et refuse tout identifiant sans marqueur d’environnement.

## GitHub Environment `mobile-release`

Secrets Android :

- `ANDROID_KEYSTORE_BASE64` ;
- `ANDROID_KEYSTORE_PASSWORD` ;
- `ANDROID_KEY_ALIAS` ;
- `ANDROID_KEY_PASSWORD` ;
- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`.

Secrets iOS :

- `IOS_CERTIFICATE_BASE64` ;
- `IOS_CERTIFICATE_PASSWORD` ;
- `IOS_PROVISIONING_PROFILE_BASE64` ;
- `IOS_KEYCHAIN_PASSWORD` ;
- `APP_STORE_CONNECT_API_KEY_ID` ;
- `APP_STORE_CONNECT_ISSUER_ID` ;
- `APP_STORE_CONNECT_API_PRIVATE_KEY`.

Sans secret de signature iOS, le workflow produit un build `Runner.app` non signé. Avec les secrets, il produit un IPA et peut l’envoyer vers TestFlight.

## Protection de `main`

À configurer dans GitHub Settings > Branches ou Rulesets :

- pull request obligatoire ;
- au moins une review approuvée ;
- rejet des reviews obsolètes après nouveau commit ;
- conversations résolues obligatoires ;
- branche à jour avant fusion ;
- interdiction des push directs et force-push ;
- checks obligatoires :
  - `Pull request validation / validate` ;
  - `CodeQL` ;
  - `Dart format quality` ;
  - `Firestore query quality` ;
  - `Product analytics quality` ;
  - `Security controls readiness` ;
  - `RGPD readiness` ;
  - `Stripe readiness` ;
  - `App Check source quality` ;
  - `Accessibility UX readiness` ;
  - `Production guardrails`.

La protection du dépôt est une configuration GitHub administrative et ne peut pas être prouvée par un simple commit. Une capture ou un export de ruleset doit être archivé comme preuve.

## Critères de fin de phase

La phase 3 ne passe à 100 % que lorsque :

1. le projet Firebase staging existe ;
2. les trois secrets staging sont configurés ;
3. une PR produit une URL preview staging et un smoke test vert ;
4. le ruleset `main` est actif avec review et checks obligatoires ;
5. un AAB signé est généré automatiquement ;
6. un IPA signé est généré automatiquement ;
7. un envoi de test Google Play interne et TestFlight est prouvé par les runs et artefacts.

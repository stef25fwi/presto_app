# Audit complet iliprestō — 2026-07-29

## Périmètre et méthode

Cet audit couvre l'état du dépôt à la racine de `main` (commit `b4c7b8f`). Il s'appuie
uniquement sur des outils exécutables dans l'environnement d'exécution (le SDK Flutter
n'y est pas installé — voir limites en fin de document) :

- baseline quantitative via `tools/quality/audit_repository.py` ;
- build TypeScript (`tsc`) et suite de tests Node (`npm test`) des Cloud Functions ;
- `npm audit` sur `functions/` et sur la racine ;
- gate de sécurité `tools/quality/check_security_controls.mjs` ;
- revue manuelle de `firestore.rules` (885 lignes) ;
- recherche de secrets en dur (clés API, clés privées, tokens Stripe) ;
- historique des exécutions GitHub Actions sur `main`.

## Résumé exécutif

| # | Constat | Sévérité |
|---|---|---|
| 1 | 7 des 9 contrôles de sécurité obligatoires de la Phase 8 sont `pending`, sans aucune preuve déposée (`docs/evidence/security/` n'existe pas) | P0 avant tout go-live |
| 2 | `docs/DEPENDENCY_AUDIT.md` est périmé : 13 vulnérabilités réelles (7 modérées, 6 élevées) contre 9 modérées/0 élevée documentées | P1 |
| 3 | Dette structurelle : 19 fichiers Dart/TS dépassent 1200 lignes (jusqu'à 7218 lignes) | P2 |
| 4 | Cloud Functions : build et 223/223 tests passent sans échec | ✅ sain |
| 5 | `firestore.rules` : design solide, anti-élévation de privilèges vérifiée | ✅ sain (1 remarque) |
| 6 | Aucun secret en dur détecté dans le code source | ✅ sain |

## 1. Gate de sécurité production — contrôles obligatoires sans preuve (P0)

```
node tools/quality/check_security_controls.mjs
→ {"ready":true,"total":9,"verified":2,"pending":7}
```

`ready:true` uniquement parce que le script tourne sans `--enforce`. Avec `--enforce`
(mode go-live), il échouerait : le dossier `docs/evidence/security/` n'existe pas du
tout, donc les 7 preuves suivantes sont manquantes :

- `app-check-firestore-enforced`
- `app-check-storage-enforced`
- `app-check-functions-enforced`
- `api-keys-restricted`
- `secrets-inventory-current`
- `dependency-audit-clean`
- `owasp-review-complete`

Seuls 2 contrôles sont `verified` (blocage des previews Firebase vers la prod, CodeQL
actif). `docs/security/PHASE_8_CONTROL_MATRIX.md` indique explicitement que la phase 8
« ne peut être clôturée que lorsque chaque contrôle obligatoire est marqué `verified` » :
ce n'est pas le cas aujourd'hui. À clarifier avec l'équipe : soit produire les preuves
externes (App Check console, restrictions de clés API, inventaire de secrets, revue
OWASP), soit documenter explicitement que ces contrôles restent en attente pour une
phase ultérieure.

## 2. Dépendances — vulnérabilités et documentation périmée (P1)

`npm audit` (racine et `functions/`) remonte **13 vulnérabilités (7 modérées, 6
élevées)**, toutes transitives via les SDK Google Cloud (`@google-cloud/firestore`,
`@google-cloud/storage`, `google-gax` → `gaxios`, `glob`, `minimatch`, `rimraf`,
`uuid`, `teeny-request`, `retry-request`, `brace-expansion`, `gcp-metadata`).

`docs/DEPENDENCY_AUDIT.md` déclare **9 modérées / 0 élevée** : ce rapport est périmé et
sous-estime l'état réel (6 vulnérabilités élevées non documentées, dont
`brace-expansion` — DoS par expansion non bornée). À régénérer.

Le correctif proposé par `npm audit fix --force` impose un **downgrade cassant de
`firebase-admin` vers 10.3.0** : à ne pas appliquer sans étudier l'impact, le projet
utilise des API `firebase-admin` v13. Recommandation : vérifier s'il existe des
résolutions ciblées (overrides npm) pour `uuid`/`brace-expansion` sans repasser par un
major bump de `firebase-admin`/`google-gax`.

## 3. Dette technique structurelle (P2)

Baseline générée (724 fichiers source, 178 312 lignes, 428 fichiers de test, 62 452
lignes de test) :

- 53 fichiers dépassent 500 lignes, 31 dépassent 800, **19 dépassent 1200 lignes**
  (seuil jugé critique par l'outil interne) ;
- en tête : `lib/pages/toolbox_je_me_lance_page.dart` (7218 lignes),
  `lib/pages/admin_space_page.dart` (5777), `lib/pages/messages/conversation_thread_page.dart`
  (5181), `lib/pages/publish_offer_page.dart` (5116), `lib/pages/offers/offer_details_page.dart`
  (4518), `functions/index.js` (2591) ;
- 383 appels `debugPrint`/`print` détectés côté Flutter — à vérifier qu'ils sont bien
  neutralisés en production ;
- 5 règles analyzer ignorées globalement dans `analysis_options.yaml`.

Ce registre est déjà suivi dans `quality/technical-debt-register.md` (TECH-001 à
TECH-054) ; aucun nouvel écart significatif par rapport à ce registre existant, il reste
d'actualité.

## 4. Règles Firestore (sain, une remarque)

Revue manuelle de `firestore.rules` : le design est robuste.

- `protectedUserFields()` bloque explicitement l'auto-modification des champs
  sensibles (`roles`, `admin`, `subscriptionStatus`, `stripeCustomerId`, etc.) sur
  `users/{userId}` — un utilisateur ne peut pas s'auto-élever admin ni falsifier son
  abonnement côté client.
- La résolution du rôle admin combine plusieurs sources cohérentes (custom claims,
  document `users`, document `admins`/`adminUsers` avec expiration) sans ouvrir de
  chemin de contournement évident.
- Les collections serveur (`_rate_limits`, `admins`) sont verrouillées
  (`allow read, write: if false`), écriture réservée aux Cloud Functions Admin SDK.
- Remarque documentée dans le fichier lui-même : `hasAppCheck()` est volontairement
  omis sur l'écriture de `users/{userId}` car le SDK Flutter Web n'attache pas de jeton
  App Check aux requêtes Firestore. Compensé par le contrôle de propriétaire + les
  champs protégés. À réévaluer si App Check Web devient disponible pour Firestore.

Non vérifié ici : exécution des règles contre l'émulateur Firestore (nécessite
`firebase-tools` ; scripts prévus dans `functions/package.json`,
`test:firestore:*` — à exécuter via `firestore-quality.yml` en CI).

## 5. Secrets et identifiants

Aucune clé secrète en dur trouvée (recherche `sk_live_`/`sk_test_`/`BEGIN PRIVATE
KEY`/`AKIA...`). `STRIPE_SECRET_KEY` est chargé via Firebase Secret Manager
(`defineSecret`), jamais committé. Les clés `AIzaSy...` présentes dans
`lib/firebase_options.dart`, `android/app/google-services.json` et le service worker
sont des clés Web Firebase publiques (identifiants de projet, pas des secrets
d'authentification) — usage standard, à condition que les restrictions d'API (origine
HTTP, nom de package) soient bien configurées côté console Google Cloud. C'est
justement l'objet du contrôle `api-keys-restricted`, actuellement `pending` (§1).

## 6. Cloud Functions — build et tests

- `npm run build` (`tsc`) : compile sans erreur.
- `npm test` : **223/223 tests passent**, 0 échec.

## 7. CI/CD

37 workflows actifs sous `.github/workflows/`. Historique récent sur `main` :
`quality-baseline.yml` : dernière exécution en succès (2026-07-29T22:31Z), après un
échec isolé plus tôt dans la journée (12:36Z) résolu depuis. `security-controls.yml` :
succès continu (mode non-`enforce`, cohérent avec le constat du §1).

## Recommandations priorisées

- **P0** — Statuer sur les 7 contrôles de sécurité en attente (§1) : soit produire les
  preuves manquantes avant tout go-live, soit documenter formellement le report de
  phase.
- **P1** — Régénérer `docs/DEPENDENCY_AUDIT.md` et évaluer une résolution ciblée des
  vulnérabilités `uuid`/`brace-expansion` sans downgrade cassant de `firebase-admin`.
- **P2** — Poursuivre le découpage des fichiers > 1200 lignes déjà suivi dans
  `quality/technical-debt-register.md`, en commençant par les P0 du registre.

## Limites de cet audit

Le SDK Flutter n'est pas installé dans cet environnement d'exécution : `flutter
analyze --fatal-infos`, `flutter test --coverage` et le build web n'ont pas pu être
exécutés ici. Ces vérifications restent couvertes par la CI GitHub Actions
(`quality-baseline.yml`, `flutter-architecture-size.yml`) — dernière exécution connue
en succès. De même, les tests Firestore avec émulateur et la vérification live d'App
Check / des restrictions de clés API dans les consoles Firebase/GCP n'ont pas pu être
exécutés depuis ce sandbox (accès externe requis).

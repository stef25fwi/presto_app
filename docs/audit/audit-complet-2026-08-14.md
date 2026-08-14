# Audit complet iliprestō — 2026-08-14

## Périmètre et méthode

Cet audit couvre l'état du dépôt à la racine de `main` (commit `09bae36`,
2026-08-14T16:14Z). Le SDK Flutter n'est pas installé dans cet environnement
d'exécution (voir limites en fin de document) ; l'audit s'appuie sur :

- baseline quantitative via `tools/quality/audit_repository.py` ;
- `npm ci` + build TypeScript (`tsc`) + suite de tests Node (`npm test`) des
  Cloud Functions ;
- `npm audit` sur `functions/` et sur la racine ;
- gate de sécurité `tools/quality/check_security_controls.mjs` ;
- historique des exécutions GitHub Actions sur `main` (`quality-baseline.yml`,
  `security-controls.yml`, `ai-production-smoke.yml`, `release_android.yml`) ;
- recherche de secrets en dur (clés API, clés privées, tokens Stripe) ;
- revue croisée de `docs/deployment/playstore-launch-checklist.md` (sujet de
  la branche `aab-production-conditions`) contre l'état réel observable.

## Résumé exécutif

| # | Constat | Sévérité |
|---|---|---|
| 1 | `ai-production-smoke.yml` échoue en continu sur `main` depuis au moins le 10/08 (30/30 dernières exécutions) : `iam.serviceAccounts.signBlob` refusé au compte de service CI lors de la création de jetons Auth personnalisés | P0 |
| 2 | La checklist Play Store affirme au point 1.1 qu'« aucun AAB release n'a jamais été produit » — **faux** : un run réussi existe (`release_android.yml`, run du 2026-07-30, AAB construit et signé, upload Play Console volontairement `skipped`) | P1 — doc à corriger |
| 3 | 7 des 9 contrôles de sécurité Phase 8 restent `pending` sans preuve déposée, inchangé depuis le dernier audit (29/07) | P0 avant tout go-live |
| 4 | `docs/DEPENDENCY_AUDIT.md` reste périmé : déclare 9 modérées / 0 haute, la réalité est 7-9 modérées + 1 haute (`brace-expansion`, DoS) | P1 |
| 5 | Cloud Functions : build et **307/307 tests passent** (223 lors du dernier audit — progression réelle) | ✅ sain |
| 6 | Dette structurelle : 18 fichiers Dart/TS dépassent 1200 lignes (19 au dernier audit) ; le plus gros fichier est passé de 7218 à 3901 lignes — découpage réel en cours | 🟡 en amélioration |
| 7 | Aucun secret en dur détecté ; `firestore.rules` quasi inchangé depuis le 29/07, design toujours sain | ✅ sain |

## 1. CI rouge persistante — `ai-production-smoke.yml` (P0)

Les 30 dernières exécutions sur `main` (10/08 → 14/08) sont toutes en échec
(ou `skipped`), à la même étape : *Verify production Functions, Auth, App
Check, fallback and logs*. Log de la dernière exécution (run `31820005895`,
commit `09bae36`) :

```
Error: Permission 'iam.serviceAccounts.signBlob' denied on resource
(or it may not exist). ... functions/scripts/microia_production_smoke_test.mjs:41
```

Le script crée des jetons Auth personnalisés (`createFirebaseTokens`) via
Workload Identity Federation. Le compte de service utilisé par la CI n'a pas
(ou plus) le rôle **Service Account Token Creator** (`roles/iam.serviceAccountTokenCreator`)
sur lui-même — condition requise par `signBlob` quand `firebase-admin` génère
un jeton personnalisé sans clé privée locale. C'est une régression IAM côté
projet GCP, pas une régression de code : rien dans l'historique récent du
script ni des workflows ne l'explique.

C'est exactement le blocage documenté au point 6.1 de
`docs/deployment/playstore-launch-checklist.md`, qui conditionne le point 2.1
(empreintes de signature / App Check) — mais il est actif en continu depuis au
moins 5 jours, pas seulement au moment où la checklist a été rédigée le
1er août.

**Recommandation** : dans la console GCP du projet `presto-app-74abe`, accorder
au compte de service utilisé par `ai-production-smoke.yml` (identité fédérée
`Authenticate to Google Cloud`) le rôle `roles/iam.serviceAccountTokenCreator`
sur lui-même (IAM → compte de service → Accorder l'accès), puis relancer le
workflow.

## 2. Checklist Play Store — un point factuellement faux (P1, doc)

Le point 1.1 de `docs/deployment/playstore-launch-checklist.md` affirme :
« Aucun AAB release n'a jamais été produit. `release_android.yml` existe mais
n'apparaît dans aucun run GitHub Actions. » Ceci est inexact : le workflow a
été déclenché manuellement le **2026-07-30T03:29Z** (run `30511313716`,
commit `33b6cc2`), et a **réussi** — build, tests, signature, génération de
l'AAB et upload de l'artefact GitHub tous verts ; seule l'étape *Upload to
Play Console* est `skipped` (comportement attendu, upload désactivé
volontairement). Un premier passage « sans upload » existe donc déjà,
contrairement à ce que dit la checklist écrite le 1er août (un jour après ce
run).

Ce fait ne rend pas les autres points 🔴 de la section 1 obsolètes (le secret
`PLAY_SERVICE_ACCOUNT_JSON` manque toujours, le premier dépôt manuel sur la
Play Console reste à faire), mais la formulation du point 1.1 est trompeuse et
sous-estime l'avancement réel. Corrigé dans ce même commit (voir diff sur
`playstore-launch-checklist.md`).

Aucune autre modification n'a été apportée depuis le 1er août à
`quality/mobile_readiness.json` (toujours 7/8 contrôles `pending`) ni à
`quality/security-controls.json` : le reste de la checklist reste
d'actualité.

## 3. Sécurité — contrôles Phase 8 (P0, inchangé)

```
node tools/quality/check_security_controls.mjs
→ {"ready":true,"total":9,"verified":2,"pending":7}
```

Toujours seulement 2 contrôles `verified` (blocage previews Firebase → prod,
CodeQL actif) ; les 7 mêmes contrôles restent `pending` sans preuve dans
`docs/evidence/security/` (le dossier n'a que `ai/`, `go-live/`,
`messaging/`, `ux/`) : App Check Firestore/Storage/Functions, restriction des
clés API, inventaire des secrets, audit de dépendances propre, revue OWASP.
Aucun changement depuis l'audit du 29/07.

## 4. Dépendances (P1, inchangé)

`npm audit` :

- `functions/` (après `npm ci`) : **8 vulnérabilités (7 modérées, 1 haute)** —
  chaîne `uuid` → `gaxios`/`teeny-request` → `@google-cloud/storage` →
  `firebase-admin` → `firebase-functions`, et `brace-expansion` (haute, DoS
  par expansion non bornée).
- racine : **10 vulnérabilités (9 modérées, 1 haute)** — même chaîne plus
  `google-gax`/`@google-cloud/firestore` (dépendances directes
  `@google-cloud/speech`, `@google-cloud/vision`).

`docs/DEPENDENCY_AUDIT.md` déclare toujours 9 modérées / **0 haute** : la
vulnérabilité `brace-expansion` (haute) reste non documentée. Le correctif
`npm audit fix --force` imposerait toujours un downgrade cassant de
`firebase-admin` vers 10.3.0 — à ne pas appliquer sans étude d'impact.

## 5. Cloud Functions — build et tests (sain, progression)

- `npm ci` : 388 paquets installés sans erreur (nécessaire ici, `node_modules`
  n'était pas présent dans ce sandbox).
- `npm run build` (`tsc`) : compile sans erreur.
- `npm test` : **307/307 tests passent**, 0 échec — en hausse par rapport aux
  223 tests du dernier audit (29/07), cohérent avec les commits
  `test(coverage): ...` récents sur `main`.

## 6. Dette technique structurelle (P2, amélioration mesurable)

Baseline régénérée (838 fichiers source, 188 980 lignes, 491 fichiers de
test, 72 043 lignes de test) :

- 52 fichiers dépassent 500 lignes, 29 dépassent 800, **18 dépassent 1200
  lignes** (19 lors du dernier audit) ;
- le fichier le plus volumineux du dépôt était `toolbox_je_me_lance_page.dart`
  à 7218 lignes le 29/07 ; il est aujourd'hui à **3901 lignes** — découpage
  effectif, pas seulement planifié ;
- en tête désormais : `lib/pages/admin_space_page.dart` (5766),
  `lib/pages/messages/conversation_thread_page.dart` (5177),
  `lib/pages/publish_offer_page.dart` (4913), `functions/index.js` (2591) ;
- 375 appels `debugPrint`/`print` détectés côté Flutter (en légère baisse) ;
- 3 règles analyzer ignorées globalement (`deprecated_member_use`,
  `use_build_context_synchronously`, `strict_top_level_inference`).

Registre suivi dans `quality/technical-debt-register.md` ; aucun nouvel écart
significatif.

## 7. Règles Firestore et secrets (sain)

Un seul commit a touché `firestore.rules` depuis le 29/07 (`0ee2f1a`, retrait
d'un masque inutilisé sur publish offer) : pas de changement de fond sur le
modèle de sécurité, les conclusions du dernier audit restent valides
(`protectedUserFields()`, résolution du rôle admin, collections serveur
verrouillées).

Recherche de secrets (`sk_live_`/`sk_test_`/`BEGIN PRIVATE KEY`/`AKIA...`) :
seules occurrences dans `functions/src/modules/billing/stripe_mode.ts` (et
son `.js` compilé/tests), qui valide des **préfixes** de clé pour détecter le
mode Stripe — pas une clé en dur. Aucun secret réel trouvé.

## 8. CI/CD

- `quality-baseline.yml` et `security-controls.yml` : 5 dernières exécutions
  sur `main` toutes en succès (jusqu'au 2026-08-14T16:14Z).
- `ai-production-smoke.yml` : rouge en continu (§1) — seule anomalie CI
  détectée dans ce périmètre.

## Recommandations priorisées

- **P0** — Corriger le rôle IAM `serviceAccountTokenCreator` manquant sur le
  compte de service CI pour rétablir `ai-production-smoke.yml` (§1) : c'est le
  seul bloquant technique nouveau et il conditionne la vérification App
  Check/Auth avant toute release Android.
- **P0** — Statuer sur les 7 contrôles de sécurité Phase 8 en attente (§3),
  inchangé depuis deux audits consécutifs.
- **P1** — Régénérer `docs/DEPENDENCY_AUDIT.md` pour refléter la vulnérabilité
  haute (`brace-expansion`) non documentée (§4).
- **P1** — Le point 1.1 de la checklist Play Store a été corrigé dans ce
  commit (§2) ; revalider les autres points 🔴 de la section 1
  (`PLAY_SERVICE_ACCOUNT_JSON`, dépôt manuel initial) qui restent d'actualité.
- **P2** — Poursuivre le découpage des fichiers > 1200 lignes (§6), tendance
  positive à maintenir.

## Limites de cet audit

Le SDK Flutter n'est pas installé dans cet environnement d'exécution :
`flutter analyze --fatal-infos`, `flutter test --coverage` et le build web
n'ont pas pu être exécutés ici (couverture non mesurée dans la baseline
générée). Ces vérifications restent couvertes par la CI GitHub Actions
(`quality-baseline.yml`), dont les dernières exécutions sur `main` sont
vertes. La vérification live des restrictions de clés API et de l'état App
Check dans les consoles Firebase/GCP n'a pas pu être effectuée depuis ce
sandbox (accès console requis) ; de même pour la correction IAM recommandée
au §1, qui doit être appliquée manuellement dans la console GCP.

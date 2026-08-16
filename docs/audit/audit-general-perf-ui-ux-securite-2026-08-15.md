# Audit général — performance / UI / UX / sécurité — 2026-08-15

Ce document synthétise l'état des quatre axes demandés à partir des audits déjà
produits cette semaine — [audit complet du 14/08](audit-complet-2026-08-14.md),
[audit qualité Play Store du 15/08](audit-qualite-code-playstore-2026-08-15.md),
[plan pré-prod du 15/08](pre-prod-readiness-plan-2026-08-15.md) et [audit
performance/UI du 19/07](perf-ui-audit-2026-07-19.md) — complétés par des
vérifications exécutées directement dans cette session (`npm audit`, gate de
sécurité, recherche de secrets, en-têtes HTTP). Aucun nouveau correctif de
code n'est appliqué ici : c'est un état des lieux, pas une intervention.

**Limite méthodologique commune à tout ce document** : le SDK Flutter n'est
pas installé dans cet environnement d'audit. `flutter analyze`,
`flutter test --coverage` et un build web (donc une mesure Lighthouse ou un
budget de bundle à jour) n'ont pas pu être exécutés ici. Ces vérifications
restent couvertes par la CI GitHub Actions (`quality-baseline.yml`), verte au
15/08.

## Résumé exécutif

| Axe | État | Point le plus urgent |
|---|---|---|
| Performance | 🟡 mesures d'il y a 4 semaines, jamais reprises | Décodage JSON bloquant (2,2 Mio) sur le thread UI + bootstrap réseau séquentiel avant le premier rendu |
| UI / UX | 🟡 socle sain, accessibilité inachevée | 5 des 8 contrôles d'accessibilité restent `pending` : navigation clavier, lecteur d'écran, responsive, cohérence des états, audit final |
| Sécurité | 🟢 aucune faille active identifiée, dette documentaire | `owasp-review-complete`, `secrets-inventory-current` et `api-keys-restricted` toujours `pending` ; **1 vulnérabilité haute non corrigée à la racine du dépôt** (nouveau constat, voir §3.2) |
| Transverse | 🟡 dette structurelle en résorption | 18 fichiers Dart/TS dépassent 1200 lignes ; `use_build_context_synchronously` reste désactivé faute d'une mesure fiable |

---

## 1. Performance

Source : [audit du 19/07](perf-ui-audit-2026-07-19.md), sur le run de
déploiement 1876. **Aucune mesure de performance n'a été refaite depuis un
mois** — ni bundle, ni runtime — alors que le code a continué de bouger
(fusion Cloud Functions, corrections STT, etc.). Les chiffres ci-dessous sont
donc probablement encore représentatifs pour le bootstrap et les patterns de
code (peu susceptibles d'avoir changé), mais **à considérer comme périmés
pour toute décision de budget bundle**.

### 1.1 Poids et budget

| Poste | Dernière mesure (19/07) | Budget |
|---|---:|---:|
| `main.dart.js` | 6,06 Mio | 12 Mio |
| `build/web` total | 67,17 Mio | 75 Mio |

À noter : une exécution ultérieure sur une branche annexe
(`audit_logs`/`AUDIT_VALIDATION_STATUS.md`, commit `158274f`) a rapporté un
`build/web` à **67,29 Mio pour un budget alors fixé à 50 Mio**, donc en
échec — signe que le budget a été resserré à un moment donné et que le poids
réel du bundle mérite d'être re-mesuré au budget actuel (75 Mio) avant toute
conclusion. `check_web_bundle_size.mjs` n'a pas pu être exécuté ici (pas de
build Flutter web dans ce sandbox).

Postes identifiés comme compressibles sans changement fonctionnel :
- ~8 Mio de fichiers `.js.symbols` (symboles de debug CanvasKit) publiés en
  production sans être jamais téléchargés par un utilisateur ;
- `cities_compact.json` (2,21 Mio) et 7 fichiers `parcours_fiches_*.json`
  (jusqu'à 1,9 Mio chacun) embarqués tels quels ;
- deux logos PNG non optimisés (0,75 Mio + 0,63 Mio, alors qu'un logo WebP
  pèse typiquement < 50 Kio).

### 1.2 Démarrage (time-to-first-frame)

`lib/main.dart` exécute avant `runApp()` une chaîne **séquentielle** :
init Firebase → App Check (reCAPTCHA) → Firestore + `enableNetwork` → Remote
Config → persistence → `getRedirectResult()`. Sur une connexion mobile à
latence élevée (typiquement les DOM-TOM, marché explicitement ciblé par le
produit), cette seule chaîne peut consommer le budget de 2,5 s avant même le
téléchargement du bundle. Seule une partie des services a été poussée après
le premier rendu ; le cœur Firebase/AppCheck/RemoteConfig reste bloquant.

**Correctif partiel appliqué le 15/08** (`lib/bootstrap/app_bootstrap.dart`) :
Remote Config (+ l'activation réseau Firestore côté natif) et l'état
d'authentification (persistence + `getRedirectResult`) sont deux chaînes
réseau indépendantes qui s'exécutaient en série ; elles tournent désormais en
parallèle via `Future.wait`. Cela ne supprime aucun aller-retour réseau mais
transforme leur coût de « somme des deux latences » en « la plus longue des
deux ». Init Firebase et App Check restent volontairement séquentiels et
bloquants : App Check doit être actif avant tout appel Firestore/Storage
pour éviter des lectures initiales rejetées par l'enforcement (voir §3), donc
seule la partie sans risque de sécurité a été parallélisée. Non vérifié par
`flutter analyze`/`flutter test` (SDK Flutter indisponible dans ce sandbox,
voir limites en tête de document) : à confirmer par la CI.

### 1.3 Fluidité (jank)

Signaux mesurés par analyse statique sur `lib/` (dernier comptage 19/07) :

| Signal | Occurrences | Risque |
|---|---:|---|
| `setState(` | 658 | rebuilds larges dans des pages de 4 000 à 7 000 lignes |
| `FirebaseFirestore.instance` direct | 114 | requêtes non centralisées/cachées |
| `ListView(` non virtualisé (vs `.builder`) | 39 vs 14 | construction intégrale de listes |
| Décodage JSON `jsonDecode` sur fichiers > 1 Mio depuis un widget | ≥ 3 chemins | gel de l'UI (pas d'isolates sur le web) |

Le point le plus concret : `cities_compact.json` (2,2 Mio) est décodé
directement depuis `city_postal_autocomplete_field.dart`, déclenché au
premier focus du champ ville de la publication d'annonce — un des parcours
les plus fréquentés de l'app.

**Cause précise identifiée et corrigée le 15/08.** `CityPostalService`
(dans ce même fichier) n'était pas un singleton : `_CityPostalAutocompleteFieldState`
en créait une nouvelle instance à chaque montage du widget
(`CityPostalService()` en initialiseur de champ `State`). Chaque fois qu'un
utilisateur ouvrait — ou rouvrait — l'écran de publication, les 2,2 Mio de
JSON étaient donc retéléchargés depuis le bundle puis redécodés sur le thread
UI, alors que `CitySearch.instance` (le service équivalent utilisé ailleurs
dans l'app) les avait déjà chargés une fois au démarrage. Corrigé en donnant
à `CityPostalService` une instance partagée (`CityPostalService.instance`,
même pattern que `CitySearch.instance`) réutilisée par le widget ; le
constructeur public reste disponible pour les tests existants
(`test/city_postal_service_test.dart`), qui n'ont pas eu besoin d'être
modifiés. Effet attendu : le décodage ne se produit plus qu'une fois par
session au lieu d'une fois par visite de l'écran de publication. Non mesuré
en runtime (SDK Flutter indisponible dans ce sandbox) — à confirmer en CI ou
sur un poste avec Flutter.

Le classement « ≥ 3 chemins » ci-dessus recensait aussi `CitySearch`
(`services/city_search.dart`, singleton, sain) et `CityRepoCompact`
(`services/city_repo_compact.dart`) : ce dernier n'est en réalité **jamais
instancié nulle part dans `lib/`** — code mort, sans impact runtime, à
retirer dans un nettoyage séparé plutôt que dans ce correctif de performance.

### 1.4 Recommandations (par priorité)

1. ~~**P0** — décharger le décodage JSON volumineux~~ — **traité en partie le
   15/08** : la cause de la duplication (rechargement à chaque montage du
   widget de publication) est corrigée. Le format du fichier lui-même
   (2,2 Mio en un seul bloc, décodé de façon synchrone) reste inchangé et
   continuera de geler l'UI un instant au premier chargement de session ;
   un format compact/indexé reste la suite logique si ce coût résiduel est
   encore perçu après mesure.
2. **P0** — ne garder bloquant avant `runApp()` que l'initialisation Firebase
   cœur ; paralléliser App Check, Remote Config, persistence et
   `getRedirectResult` derrière le premier frame. **Traité en partie le
   15/08** (Remote Config et l'état d'authentification tournent désormais en
   parallèle, voir §1.2) ; App Check reste bloquant par nécessité de
   sécurité, donc le P0 n'est que partiellement résorbé.
3. **P1** — re-mesurer le budget bundle avec un build à jour : la dernière
   mesure a un mois, et une mesure intermédiaire suggère un dépassement selon
   le budget appliqué à ce moment.
4. **P1** — poursuivre la décomposition des pages géantes (voir §4), qui est
   le premier facteur de jank perçu.
5. **P2** — exclure `.js.symbols`/`NOTICES` du déploiement, WebP pour les
   logos, instrumenter LCP/INP réels (web-vitals déjà présent dans
   `web/web-vitals-rum.js`, à vérifier qu'il remonte des données exploitées).

---

## 2. UI / UX

### 2.1 Ce qui est acquis

- Design system centralisé (`lib/app/presto_design_tokens.dart`,
  `lib/app/theme.dart`) : jetons de couleur et d'espacement, pas de valeur
  codée en dur en dehors du thème — **vérifié** par test automatisé.
- Contrastes WCAG AA **vérifiés** par test (`presto_design_system_accessibility_test.dart`),
  y compris l'interdiction explicite du texte blanc sur fond orange.
- Cibles tactiles ≥ 48 px imposées par le thème — **vérifié**.
- En-têtes de sécurité et cache HTTP cohérents (voir §3), ce qui limite les
  effets de bord visuels liés au cache (pas de contenu figé après déploiement).

### 2.2 Ce qui reste ouvert

Le registre `quality/accessibility_ux_readiness.json` (phase 13,
`in_progress`) compte 3 contrôles vérifiés sur 8 :

| Contrôle | État | Ce qu'il manque concrètement |
|---|---|---|
| Navigation clavier et focus | `pending` | Parcours manuel clavier sur publication / messagerie / compte, non consigné |
| Lecteur d'écran (TalkBack/VoiceOver) | `pending` | Validation sur appareil réel requise — l'émulateur ne suffit pas d'après le registre lui-même |
| Responsive 320–1440 px + texte à 200 % | `pending` | Matrice `docs/evidence/ux/responsive-matrix.md` non renseignée |
| Cohérence des états loading/empty/error | `pending` | Revue écran par écran non faite |
| Audit accessibilité final | `pending` | Bloqué par construction tant que les 4 précédents ne sont pas clos |

Ce chantier correspond au **point 2 sur 18** du programme séquentiel
`18-point-completion` (`quality/18-point-completion.json`), actuellement le
seul point actif. Il conditionne directement `all-prior-phases-reviewed`
côté go-live : rien après ce point ne peut avancer tant qu'il n'est pas clos.

Constat annexe (P2, non bloquant) : aucun `assetlinks.json` ni
`intent-filter` de lien web côté Android — les notifications et partages
n'ouvrent pas l'app sur le contenu visé, seulement le navigateur/l'app par
défaut.

### 2.3 Recommandations

1. **P1** — dérouler les 4 contrôles d'accessibilité restants dans l'ordre du
   registre ; le clavier et les états loading/empty/error sont vérifiables
   sans appareil physique et peuvent avancer en premier.
2. **P1** — programmer une session TalkBack/VoiceOver sur appareil réel : ce
   contrôle ne peut être satisfait par aucune revue de code.
3. **P2** — ajouter les App Links si les notifications doivent router vers un
   écran précis (impact perçu réel, effort limité).

---

## 3. Sécurité

### 3.1 Contrôles vérifiés dans cette session

`node tools/quality/check_security_controls.mjs` → **5/9 `verified`, 4
`pending`, 0 échec de gate** :

- ✅ App Check appliqué sur Firestore, Storage et 83/83 callables Cloud
  Functions (politique fail-closed en production).
- ✅ Aucun déploiement de preview ne peut cibler le projet de production.
- ✅ CodeQL actif sur chaque PR et sur `main`.
- ⏳ `api-keys-restricted`, `secrets-inventory-current`, `owasp-review-complete`
  restent `pending` : ce sont des livrables de preuve à produire (console
  GCP, inventaire, revue documentée), pas des failles techniques connues.

### 3.2 Dépendances — un écart entre `functions/` et la racine (constat nouveau)

Le correctif `brace-expansion` du 14–15/08 a été appliqué **uniquement dans
`functions/`** :

| Périmètre | `npm audit` | Sévérité haute |
|---|---|---|
| `functions/` | 7 modérées, **0 haute** | corrigé le 15/08 |
| racine du dépôt (`package-lock.json`) | 9 modérées, **1 haute** (`brace-expansion`) | **toujours présent** |

`docs/DEPENDENCY_AUDIT.md` ne documente que le périmètre `functions/` : la
racine du dépôt (qui déclare `@google-cloud/speech`, `@google-cloud/vision`,
`firebase-admin`, `firebase-functions`, `openai` en dépendances directes,
utilisées par les scripts `bin/` et `tools/`) n'a pas de rapport équivalent
et porte toujours la vulnérabilité haute. `npm audit fix` (sans `--force`)
n'a pas pu être vérifié comme suffisant depuis ce sandbox (pas de
`node_modules` installé à la racine), mais le même correctif non cassant
appliqué à `functions/` est a priori transposable puisque la chaîne de
dépendance (`uuid` → `gaxios`/`teeny-request` → `@google-cloud/*` →
`firebase-admin`) est identique.

Aucun secret en dur détecté (`sk_live_`, `sk_test_`, clés privées, clés AWS) :
les seules occurrences sont dans `functions/lib/modules/billing/stripe_mode.js`
et son test, qui valident des **préfixes** de clé Stripe pour déterminer le
mode (live/test), pas des clés réelles.

### 3.3 En-têtes HTTP (vérifié dans cette session)

`firebase.json` applique sur toutes les routes de production et de miroir :
`Strict-Transport-Security` (2 ans, `includeSubDomains; preload`),
`Content-Security-Policy`, `X-Content-Type-Options: nosniff`,
`X-Frame-Options: SAMEORIGIN`, `Referrer-Policy`, `Permissions-Policy`
(caméra/micro/géoloc restreints à `self`), `X-XSS-Protection`. Configuration
saine dans l'ensemble.

Point d'attention mineur : `script-src` inclut `'unsafe-inline'` (en plus de
`'wasm-unsafe-eval'` nécessaire à CanvasKit). C'est un compromis courant pour
Flutter web/reCAPTCHA, mais il affaiblit la protection XSS que la CSP est
censée apporter — à ne pas considérer comme un défaut isolé, plutôt comme une
limite structurelle du CSP tant que du JS inline reste nécessaire.

### 3.4 Règles Firestore

Inchangées depuis le dernier audit de fond (29/07), un seul commit mineur
depuis. `isAdmin()`/`isAdminClaim()` et `protectedUserFields()` toujours en
place pour verrouiller les champs sensibles et la résolution du rôle admin.
Rien de nouveau à signaler ici.

### 3.5 Recommandations

1. **P1** — appliquer à la racine du dépôt le même traitement
   `brace-expansion` que dans `functions/` (§3.2), et étendre
   `docs/DEPENDENCY_AUDIT.md` ou créer son équivalent pour la racine, sans
   quoi cet écart peut se reproduire silencieusement.
2. **P2** — les trois contrôles `pending` de sécurité (§3.1) sont des
   livrables de preuve, pas des correctifs de code : à traiter par
   attestation datée dans `docs/evidence/security/`.
3. **P2** — documenter explicitement l'acceptation de `'unsafe-inline'` dans
   la CSP (raison, portée, compensation) plutôt que de la laisser implicite.

---

## 4. Dette transverse (impacte les trois axes ci-dessus)

- **18 fichiers Dart/TS dépassent 1200 lignes** (`admin_space_page.dart`
  5766 l., `conversation_thread_page.dart` 5177 l., `publish_offer_page.dart`
  4913 l., `functions/index.js` 2626 l. mesurés dans cette session). C'est à
  la fois un facteur de jank (un `setState` reconstruit un arbre énorme), un
  facteur de risque UX (logique d'état difficile à auditer manuellement) et
  un facteur de risque sécurité indirect (code legacy `functions/index.js`
  hors périmètre des tests automatisés `npm test`, comme relevé dans l'audit
  du 14/08 pour le correctif STT).
- **316 appels `debugPrint`** dans `lib/` : neutralisés en release depuis le
  15/08 par un point de contrôle unique (`lib/bootstrap/release_logging.dart`),
  vérifié présent dans cette session. La règle analyzer `avoid_print` reste
  cependant désactivée (`analysis_options.yaml:26`) : rien n'empêche la
  réintroduction d'un `print` brut non neutralisé demain.
- **`use_build_context_synchronously` toujours désactivé** dans
  `analysis_options.yaml`. Trois tentatives de mesure par détecteur maison
  ont donné trois résultats contradictoires (116, 61, puis 0 occurrence) ; la
  réactivation tentée le 15/08 a été annulée car `flutter analyze` (seule
  source fiable) n'est pas exécutable depuis un environnement sans SDK
  Flutter. Cela reste donc une classe de bugs de plantage potentiels non
  quantifiée à ce jour.

---

## Priorités consolidées

| # | Action | Axe | Effort |
|---|---|---|---|
| 1 | Décharger le décodage JSON (`cities_compact.json`, fiches parcours) du thread UI | Perf | **partiel, fait le 15/08** — cause de duplication corrigée (§1.3) ; format compact/indexé encore à faire |
| 2 | Paralléliser le bootstrap réseau avant `runApp()` | Perf | **partiel, fait le 15/08** — Remote Config + état auth en parallèle (§1.2) ; App Check reste bloquant par nécessité |
| 3 | Corriger `brace-expansion` à la racine du dépôt (même correctif que `functions/`) | Sécurité | faible |
| 4 | Dérouler les contrôles d'accessibilité restants (clavier, lecteur d'écran, responsive, états) | UI/UX | élevé (nécessite du test manuel/appareil) |
| 5 | Ré-exécuter une mesure de bundle et de runtime à jour (le dernier chiffre a un mois) | Perf | faible (CI existante) |
| 6 | Réactiver `use_build_context_synchronously` à partir d'une sortie réelle de `flutter analyze` | Transverse | moyen |
| 7 | Réactiver `avoid_print` pour verrouiller le correctif de journalisation | Sécurité/Transverse | faible |
| 8 | Produire les livrables de preuve sécurité restants (clés API, inventaire secrets, revue OWASP) | Sécurité | moyen (documentaire) |

## Sources

- [Audit performance/UI — 19/07/2026](perf-ui-audit-2026-07-19.md)
- [Audit complet — 14/08/2026](audit-complet-2026-08-14.md)
- [Audit qualité Play Store — 15/08/2026](audit-qualite-code-playstore-2026-08-15.md)
- [Plan pré-prod — 15/08/2026](pre-prod-readiness-plan-2026-08-15.md)
- `quality/accessibility_ux_readiness.json`, `quality/security-controls.json`,
  `quality/18-point-completion.json`
- Vérifications exécutées dans cette session : `check_security_controls.mjs`,
  `npm audit` (racine et `functions/`), recherche de secrets en dur, lecture
  des en-têtes HTTP dans `firebase.json`, comptage `debugPrint` et lignes de
  fichiers.

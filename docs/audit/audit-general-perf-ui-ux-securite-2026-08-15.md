# Audit général — performance / UI / UX / sécurité — 2026-08-15

Ce document synthétise l'état des quatre axes demandés à partir des audits déjà
produits cette semaine — [audit complet du 14/08](audit-complet-2026-08-14.md),
[audit qualité Play Store du 15/08](audit-qualite-code-playstore-2026-08-15.md),
[plan pré-prod du 15/08](pre-prod-readiness-plan-2026-08-15.md) et [audit
performance/UI du 19/07](perf-ui-audit-2026-07-19.md) — complété par des
vérifications exécutées directement en session (`npm audit`, gate de
sécurité, recherche de secrets, en-têtes HTTP). La version initiale était un
état des lieux sans intervention ; trois correctifs ciblés, à faible risque
et documentés à l'endroit où ils s'appliquent (§1.2, §1.3, §3.2) ont été
apportés depuis, dans le prolongement direct des constats de l'audit.

**Limite méthodologique commune à tout ce document** : le SDK Flutter n'est
pas installé dans cet environnement d'audit. `flutter analyze`,
`flutter test --coverage` et un build web (donc une mesure Lighthouse ou un
budget de bundle à jour) n'ont pas pu être exécutés ici. Ces vérifications
restent couvertes par la CI GitHub Actions (`quality-baseline.yml`), verte au
15/08.

## Résumé exécutif

| Axe | État | Point le plus urgent |
|---|---|---|
| Performance | 🟡 mesures d'il y a 4 semaines ; 2 correctifs ciblés faits le 15/08 | Le rechargement de `cities_compact.json` à chaque montage du widget de publication (§1.3) et une partie du bootstrap séquentiel (§1.2) sont corrigés ; le format du JSON et App Check restent à traiter |
| UI / UX | 🟡 socle sain, accessibilité inachevée | 5 des 8 contrôles restent `pending` (navigation clavier, lecteur d'écran, responsive, cohérence des états, audit final) ; revues de code partielles + 1 correctif faits le 15/08 sur 2 d'entre eux (§2.2) |
| Sécurité | 🟢 **0 vulnérabilité**, dette documentaire résiduelle | Les 16 modérées et la haute sont éliminées (15 et 16/08, §3.2 bis) sans downgrade. Restent `owasp-review-complete`, `secrets-inventory-current` et `api-keys-restricted` — trois livrables de preuve hors d'atteinte d'une session de code |
| Transverse | 🟡 dette structurelle en résorption | 18 fichiers Dart/TS dépassent 1200 lignes ; `avoid_print` réactivée le 16/08 ; `use_build_context_synchronously` reste le seul point réellement bloqué par l'absence de SDK Flutter |

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
(`services/city_repo_compact.dart`) : ce dernier n'était **jamais instancié
nulle part**. **Supprimé le 16/08**, avec le widget qui en dépendait
(`city_postal_autocomplete_compact.dart`, lui-même référencé nulle part) —
231 lignes formant une boucle morte fermée.

Ce n'est pas qu'un nettoyage cosmétique : `CityRepoCompact` était la
troisième implémentation du chargement de `cities_compact.json`, et la seule
à ne **pas** avoir reçu le correctif singleton du §1.3. La laisser en place,
c'était garder à disposition la version qui recharge 2,2 Mio à chaque usage —
soit exactement le défaut qu'on venait de corriger, prêt à être réintroduit
par quiconque aurait choisi cette classe. Il reste désormais deux chemins,
tous deux mémoïsés.

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
5. **P2** — exclure `.js.symbols` du déploiement — **fait le 16/08** :
   `firebase.json` ignore désormais `**/*.js.symbols` et `**/*.wasm.symbols`
   sur les deux cibles d'hébergement. Restent : WebP pour les logos,
   instrumenter LCP/INP réels (web-vitals déjà présent dans
   `web/web-vitals-rum.js`, à vérifier qu'il remonte des données exploitées).

   **Correction apportée à la recommandation d'origine** : l'audit du 19/07
   proposait d'exclure aussi `assets/NOTICES` (1,44 Mio). À ne pas faire.
   Ce fichier porte l'attribution des licences open-source embarquées par le
   moteur Flutter (Skia, ICU…), dont plusieurs — BSD, MIT — **exigent** que
   l'avis de copyright accompagne toute redistribution. Le retirer d'un
   déploiement public échange 1,4 Mio sur un build de 67 Mio contre un risque
   de conformité de licence réel : le compromis n'est pas favorable. Seuls les
   symboles de debug, qui n'ont aucune fonction légale ni runtime, sont
   exclus.

   À noter : cette exclusion allège l'artefact **déployé**, mais pas la mesure
   de `tools/check_web_bundle_size.mjs`, qui pèse le répertoire `build/web`
   sur disque. Le budget affiché en CI ne bougera donc pas — ce qui est
   cohérent, le budget mesurant la production du build et non ce qui est
   servi.

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
| Navigation clavier et focus | `pending` | Parcours manuel clavier sur publication / messagerie / compte, non consigné. **Revue de code faite le 15/08** (`docs/evidence/ux/accessibility-audit.md` §3bis) : 1 défaut réel trouvé et corrigé (carte d'annonce du carrousel d'accueil, `GestureDetector` nu → `Semantics`+`InkWell`), 37 autres occurrences non triées restent des pistes |
| Lecteur d'écran (TalkBack/VoiceOver) | `pending` | Validation sur appareil réel requise — l'émulateur ne suffit pas d'après le registre lui-même. Le correctif ci-dessus améliore aussi ce point pour la carte concernée, sans s'y substituer |
| Responsive 320–1440 px + texte à 200 % | `pending` | Matrice `docs/evidence/ux/responsive-matrix.md` non renseignée |
| Cohérence des états loading/empty/error | `pending` | Revue écran par écran non faite. **Revue partielle faite le 15/08** (`docs/evidence/ux/accessibility-audit.md` §7bis) : 4 des 9 parcours principaux (messagerie, compte, publication, consultation d'offres) examinés, comportement cohérent constaté sur cet échantillon, aucun correctif nécessaire |
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

`node tools/quality/check_security_controls.mjs` → **6/9 `verified`, 3
`pending`, 0 échec de gate** (5/9 avant le correctif de dépendances du 16/08,
§3.2) :

- ✅ App Check appliqué sur Firestore, Storage et 83/83 callables Cloud
  Functions (politique fail-closed en production).
- ✅ Aucun déploiement de preview ne peut cibler le projet de production.
- ✅ CodeQL actif sur chaque PR et sur `main`.
- ✅ `dependency-audit-clean` — 0 vulnérabilité sur les deux périmètres du
  dépôt depuis le 16/08 (§3.2), preuve dans
  `docs/evidence/security/dependency-audit.md`.
- ⏳ `api-keys-restricted`, `secrets-inventory-current`, `owasp-review-complete`
  restent `pending` : ce sont des livrables de preuve à produire (console
  GCP, inventaire, revue documentée), pas des failles techniques connues.
  **Aucun des trois n'est instruisible depuis une session de code** : les deux
  premiers exigent un accès console GCP, le troisième un jugement humain sur
  ce qui est accepté et pourquoi.

### 3.2 Dépendances — écart entre `functions/` et la racine, corrigé le 15/08

Le correctif `brace-expansion` du 14–15/08 avait été appliqué **uniquement
dans `functions/`**, laissant la racine du dépôt (qui déclare
`@google-cloud/speech`, `@google-cloud/vision`, `firebase-admin`,
`firebase-functions`, `openai` en dépendances directes, utilisées par les
scripts `bin/` et `tools/`) avec la même vulnérabilité haute non traitée :

| Périmètre | `npm audit` avant | `npm audit` après (15/08) |
|---|---|---|
| `functions/` | 7 modérées, 0 haute | inchangé |
| racine du dépôt (`package-lock.json`) | 9 modérées, **1 haute** (`brace-expansion`) | **9 modérées, 0 haute** |

**Première correction (15/08)** par `npm audit fix` (sans `--force`) à la
racine : la vulnérabilité haute disparaît, `firebase-admin` reste en 13.10.0.
Restaient alors 9 modérées à la racine et 7 dans `functions/`.

### 3.2 bis — Les 16 modérées éliminées le 16/08, sans downgrade

Les 16 entrées restantes n'étaient **pas 16 problèmes** : elles remontaient
toutes à une cause racine unique, **`uuid@9.0.1`**
([GHSA-w5hq-g745-h8pq](https://github.com/advisories/GHSA-w5hq-g745-h8pq)).
Les huit autres noms (`gaxios`, `google-gax`, `teeny-request`,
`retry-request`, `@google-cloud/storage`, `@google-cloud/firestore`,
`firebase-admin`, `firebase-functions`) n'en étaient que la propagation
transitive.

Les audits des 14 et 15/08 s'étaient arrêtés sur le constat que la seule
correction proposée par npm — `audit fix --force`, qui downgrade
`firebase-admin` de 13/14 vers 10.3.0 — était inacceptable. C'était juste,
mais la conclusion « non corrigeable sans étude d'impact » ne l'était pas :
un **`overrides` npm sur `uuid`** traite la cause sans toucher à
`firebase-admin`. Le mécanisme était d'ailleurs déjà en usage dans ce dépôt,
`functions/package.json` portant déjà un `overrides` sur `@grpc/grpc-js`.

| Périmètre | Avant | Après (16/08) |
|---|---|---|
| racine | 9 modérées | **0 vulnérabilité** |
| `functions/` | 7 modérées | **0 vulnérabilité** |

Vérifications conduites avant de basculer le contrôle :

- `firebase-admin` **inchangé** — 13.10.0 à la racine, 14.2.0 dans
  `functions/` : aucun downgrade ;
- `uuid` résolu en 11.1.1 en **copie unique**, aucun `uuid` imbriqué —
  l'override s'applique bien à tout l'arbre ;
- les SDK consommateurs n'appellent que **`uuid.v4()`**
  (`gaxios/build/src/gaxios.js` l. 417, `teeny-request` l. 135, `google-gax`
  l. 108), dont la signature est identique entre v9 et v11 ;
- **308/308 tests `functions/` passent**, compilation `tsc` incluse.

**Portée réelle, à ne pas surestimer** : `v4` n'est pas visée par l'avis de
sécurité, qui porte sur `v3`/`v5`/`v6` avec un paramètre `buf`. Dans ce
projet précis, l'exposition était donc vraisemblablement nulle. Le gain n'est
pas la fermeture d'une brèche exploitée mais la disparition d'un bruit
permanent qui, tant qu'il occupait le rapport, rendait invisible toute
vulnérabilité réellement sérieuse qui s'y serait ajoutée.

`docs/DEPENDENCY_AUDIT.md` a été régénéré avec la logique exacte du workflow
`dependency-audit-report.yml` et rapporte 0 partout. Il ne couvre toujours que
le périmètre `functions/` : produire son équivalent racine reste souhaitable
(§3.5).

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

1. ~~**P1** — appliquer à la racine du dépôt le même traitement
   `brace-expansion` que dans `functions/`~~ — **fait le 15/08**, puis
   ~~éliminer les 16 modérées restantes~~ — **fait le 16/08** via l'override
   `uuid` (§3.2 bis). Les deux périmètres sont à 0 vulnérabilité.
2. **P2** — étendre `docs/DEPENDENCY_AUDIT.md` au périmètre racine (il ne
   couvre que `functions/`), pour qu'un écart entre les deux ne puisse plus
   passer inaperçu à la prochaine vulnérabilité publiée. C'est ce décalage de
   couverture qui avait laissé la haute `brace-expansion` invisible côté
   racine pendant que `functions/` était déclaré sain.
3. **P2** — les trois contrôles `pending` de sécurité (§3.1) sont des
   livrables de preuve, pas des correctifs de code : à traiter par
   attestation datée dans `docs/evidence/security/`. Aucun n'est instruisible
   sans accès console GCP ou décision humaine.
4. **P2** — documenter explicitement l'acceptation de `'unsafe-inline'` dans
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
  vérifié présent dans cette session. La règle `avoid_print` a été
  **réactivée le 16/08**, ce qui verrouille le correctif : un `print` brut
  réintroduit dans `lib/` fera désormais échouer `flutter analyze
  --fatal-infos`. Les 2 seuls `print` bruts qui subsistaient
  (`lib/widgets/ad_banner.dart`, déjà gardés par `kDebugMode`) sont passés à
  `debugPrint`. La règle est désactivée par `analysis_options.yaml` imbriqués
  dans `bin/`, `tools/` et `test/`, où les 61 `print` restants sont légitimes
  — sortie standard des scripts CLI, et code de test jamais livré.
- **`use_build_context_synchronously` toujours désactivé** dans
  `analysis_options.yaml`. Trois tentatives de mesure par détecteur maison
  ont donné trois résultats contradictoires (116, 61, puis 0 occurrence) ; la
  réactivation tentée le 15/08 a été annulée car `flutter analyze` (seule
  source fiable) n'est pas exécutable depuis un environnement sans SDK
  Flutter. Cela reste donc une classe de bugs de plantage potentiels non
  quantifiée à ce jour.
- **`functions/lib/` est du build output versionné, et il est périmé**
  (constat nouveau du 16/08). Le répertoire compte 428 fichiers suivis par
  git, mais lancer `npm --prefix functions run build` produit une centaine de
  fichiers modifiés et treize non suivis : le compilé de `web_vitals`,
  `inbound_contact`, `seo/` et `firebase_admin_compat` existe en source
  (`functions/src/`) sans avoir jamais été committé, et `lib/index.js` ne les
  exporte donc pas dans la version versionnée.

  **Sans effet sur la production** : `scripts/deploy_all.sh` exécute
  `npm --prefix functions run build` (l. 35) avant `firebase deploy`, et le
  script `npm test` reconstruit également. Ce qui est déployé est donc
  toujours recompilé depuis `src/`, jamais le `lib/` du dépôt.

  L'enjeu est la lisibilité : tant que `lib/` est suivi mais dérive, tout
  `npm test` local salit l'arbre de travail avec une centaine de fichiers
  générés, ce qui noie les vraies modifications dans les revues. Deux issues
  cohérentes, l'une comme l'autre défendable, mais qui relèvent d'une décision
  d'équipe et non d'une branche d'audit : soit régénérer `lib/` en CI pour
  qu'il reste fidèle, soit l'ajouter à `.gitignore` puisque rien ne le
  consomme tel quel. **L'état actuel — suivi mais non maintenu — est le seul
  qui n'ait aucun avantage.**

---

## Ce que « 10/10 » demanderait réellement (mesuré le 16/08)

Deux choses très différentes se cachent derrière ce chiffre, et les confondre
mène à des conclusions fausses.

### 1. Les gates automatiques : déjà tous verts

27 contrôles exécutables ont été lancés dans cette session. **24 passent.**
Les 3 restants n'échouent pas sur un défaut du dépôt :

| Gate | Cause de l'échec local | Réalité |
|---|---|---|
| `check_firebase_staging_readiness` | `missing-project-id`, `missing-staging-token` | Secrets d'environnement absents du sandbox |
| `check_live_structured_data` | Réseau | Interroge le site de production, inaccessible ici |
| `check_programmatic_local_seo` | `ENOENT: web/sitemap-local.xml` | **Faux positif de ma part** : l'artefact est généré. Après `node tools/seo/generate_programmatic_local_pages.mjs`, le gate passe (« 36 pages validées »). Les workflows `deploy.yml` et `seo-acquisition-readiness.yml` exécutent toujours le générateur juste avant le contrôle |

**Aucun gate n'est cassé.** Sur le plan automatisable, le dépôt est déjà au
vert.

### 2. Les attestations : 36/157 (23 %)

Ce ne sont pas des échecs, ce sont des **déclarations humaines non encore
posées**. Répartition par registre :

| Registre | Vérifiés | Ce qui bloque |
|---|---:|---|
| `seo-monitoring-readiness` | 12/12 | — |
| `product-readiness` | 5/5 | — |
| `security-controls` | 6/9 | Console GCP (clés API, secrets), revue OWASP humaine |
| `ai-readiness` | 7/15 | Historique de runs, corpus |
| `accessibility_ux_readiness` | 3/8 | **Appareil réel** (TalkBack/VoiceOver), passes manuelles |
| `mobile_readiness` | 0/8 | **Play Console**, dont un test fermé de 12 testeurs sur 14 jours |
| `stripe-readiness` | 0/7 | Statut `implemented`, pas `verified` — voir la note ci-dessous |
| autres registres | le solde | Console, décisions humaines, ou périmètre à définir |

### 3. Le piège de vocabulaire

Les registres n'emploient pas le même vocabulaire de statut : les gates
acceptent `verified`, `implemented`, `complete`, `pending`, `blocked` et
`in_progress` selon le registre. `stripe-readiness` affiche ainsi 7
`implemented` et 0 `verified` — ce qui se lit « 0/7 » ou « 7/7 » suivant la
convention retenue. **Tout total agrégé sur les 157 contrôles est donc
ambigu**, et c'est une raison de plus de ne pas piloter par ce chiffre.

### 4. Pourquoi 157/157 est structurellement impossible

`quality/18-point-completion.json` porte ces règles :

```json
"singleActivePoint": true,
"laterPointsMustRemainBlocked": true
```

et `tools/quality/check_18_point_completion.mjs` (l. 123-125) **échoue** si un
point postérieur au point actif n'est pas `blocked` :

> `Le point N doit rester blocked tant que le point M n'est pas verified.`

Les 16 points `blocked` sont donc l'état **normal et exigé** d'un programme
séquentiel arrêté au point 2 sur 18. Les basculer pour afficher 18/18 ne
serait pas seulement malhonnête : **cela ferait échouer le gate**. Le dépôt
s'est explicitement outillé pour rendre ce raccourci impossible.

### 5. Le chemin réel vers un pré-prod sans réserve

Aucune de ces étapes ne s'obtient depuis une session de code :

1. **Lancer le test fermé Play** (12 testeurs, 14 jours) — seul délai
   incompressible, à démarrer en premier ;
2. **Une passe accessibilité sur appareil** avec TalkBack et VoiceOver ;
3. **Trois relevés en console GCP** : restrictions de clés API, inventaire
   des secrets, dashboards ;
4. **Une revue OWASP** avec, pour chaque catégorie, une décision assumée ;
5. **Dérouler les 18 points** dans l'ordre, en partant du point 2.

## Priorités consolidées

| # | Action | Axe | Effort |
|---|---|---|---|
| 1 | Décharger le décodage JSON (`cities_compact.json`, fiches parcours) du thread UI | Perf | **partiel, fait le 15/08** — cause de duplication corrigée (§1.3) ; format compact/indexé encore à faire |
| 2 | Paralléliser le bootstrap réseau avant `runApp()` | Perf | **partiel, fait le 15/08** — Remote Config + état auth en parallèle (§1.2) ; App Check reste bloquant par nécessité |
| 3 | ~~Corriger `brace-expansion`, puis les 16 modérées restantes~~ | Sécurité | **fait les 15 et 16/08** — 0 vulnérabilité sur les deux périmètres (§3.2 bis) |
| 4 | Dérouler les contrôles d'accessibilité restants (clavier, lecteur d'écran, responsive, états) | UI/UX | **partiel, fait le 15/08** — revues de code sur 2 des 4 (§2.2) ; le clavier/lecteur d'écran sur appareil réel et la matrice responsive restent à faire, élevé |
| 5 | Ré-exécuter une mesure de bundle et de runtime à jour (le dernier chiffre a un mois) | Perf | faible (CI existante) |
| 6 | Réactiver `use_build_context_synchronously` à partir d'une sortie réelle de `flutter analyze` | Transverse | moyen — **reste ouvert**, seul point que le SDK absent empêche réellement de traiter ici |
| 7 | ~~Réactiver `avoid_print`~~ | Sécurité/Transverse | **fait le 16/08** (§4) |
| 8 | Produire les livrables de preuve sécurité restants (clés API, inventaire secrets, revue OWASP) | Sécurité | moyen (documentaire) — **hors d'atteinte d'une session de code** : console GCP ou décision humaine |
| 9 | ~~Exclure les `.js.symbols` du déploiement~~ | Perf | **fait le 16/08** — `NOTICES` volontairement conservé (attribution de licences, §1.4) |
| 10 | Trancher le statut de `functions/lib/` : régénéré en CI, ou ignoré par git (§4) | Transverse | faible — mais c'est une décision d'équipe, pas un correctif |
| 11 | ~~Supprimer le code mort `CityRepoCompact` + widget associé~~ | Perf/Propreté | **fait le 16/08** — 231 lignes, dont la 3e copie non mémoïsée du chargement JSON (§1.3) |
| 12 | ~~Rendre accessible le slide du carrousel hero~~ | UI/UX | **fait le 16/08** — paire slide + icône traitée ensemble (`accessibility-audit.md` §3bis) |
| 13 | ~~Ignorer les artefacts générés par les gates~~ | Propreté | **fait le 16/08** — `mobile-readiness-report.json` et pages SEO générées ; l'arbre reste propre après régénération complète |

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

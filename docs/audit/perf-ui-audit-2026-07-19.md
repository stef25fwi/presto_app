# Audit performance, graphique et fluidité UI — 19 juillet 2026

Périmètre : application web Flutter déployée (`ilipresto.web.app`), mesures
issues du run de déploiement `1876` (commit `94917655`) et analyse statique du
code sur `main` au même commit. Cible de référence :
`quality/quality-gates.json` → affichage initial ≤ 2,5 s, interaction locale
≤ 200 ms, crash-free ≥ 99,5 %.

## 1. Poids réseau et bundle (mesures réelles CI, run 1876)

| Poste | Taille | Budget | Lecture |
|---|---:|---:|---|
| `main.dart.js` | 6,06 MiB | 12 MiB | monolithique, un seul `deferred as` dans tout `lib/` |
| `assets/` | 23,90 MiB | 35 MiB | dont ~13 MiB de JSON de données |
| `build/web` total | 67,17 MiB | 75 MiB | **90 % du budget consommé** |

Détails notables :

- **CanvasKit multi-variantes ≈ 28 MiB** : `canvaskit.wasm` (6,89),
  `chromium/canvaskit.wasm` (5,49), `skwasm_heavy` (4,93),
  `experimental_webparagraph` (3,95), `skwasm` (3,42), `wimp` (3,35). Un seul
  variant est téléchargé par navigateur, mais tous sont déployés et comptent
  dans le budget total.
- **≈ 8 MiB de fichiers `.js.symbols`** (symboles de debug CanvasKit) sont
  publiés en production. Ils ne sont jamais téléchargés par les utilisateurs
  mais gonflent le budget et l'artefact.
- **JSON de données embarqués ≈ 13 MiB** : `cities_compact.json` (2,21 MiB) et
  7 fichiers `parcours_fiches_*.json` (0,70 à 1,91 MiB chacun).
- **Images non optimisées** : `ilipresto_splash_logo.png` (0,75 MiB) et
  `logo_ilipresto.png` (0,63 MiB) — un logo devrait peser < 50 KiB en WebP.
- `assets/NOTICES` (1,44 MiB) publié tel quel.
- Polices : Inter ExtraBold + Medium (0,80 MiB), Font Awesome Solid complet
  (0,40 MiB), Rubik variable ×2 (0,68 MiB).

Côté cache (firebase.json) : `main.dart.js`, `*.part.js`, bootstrap et service
worker sont en `no-cache, must-revalidate` (revalidation à chaque visite,
correct pour un fichier non fingerprinté), assets et CanvasKit en
`immutable` 1 an — configuration saine.

## 2. Démarrage (time-to-first-frame)

`lib/main.dart` exécute **avant `runApp()`** une chaîne séquentielle
d'initialisations réseau :

1. `ensureFirebaseInitialized` ;
2. `bootstrapAppCheck` (reCAPTCHA) ;
3. `bootstrapFirestore` puis `enableNetwork` ;
4. `PrestoRemoteConfig.init` ;
5. `setPersistence(Persistence.LOCAL)` ;
6. `getRedirectResult()` (retour OAuth fédéré).

Chaque étape ajoute un ou plusieurs allers-retours réseau **en série** avant le
premier rendu. Sur une connexion mobile ultramarine (latence 100–300 ms), ce
seul enchaînement peut consommer le budget de 2,5 s avant même le
téléchargement des 6 MiB de `main.dart.js` + variant CanvasKit (~6–7 MiB).
Le commentaire ligne 786 (« arrière-plan après runApp pour afficher un shell
interactif immédiat ») montre que la démarche est engagée pour une partie des
services, mais le cœur Firebase/AppCheck/RemoteConfig reste bloquant.

## 3. Fluidité (jank main-thread)

Compteurs mesurés sur `lib/` (315 fichiers, 119 325 lignes) :

| Signal | Occurrences | Risque |
|---|---:|---|
| `setState(` | 658 | rebuilds larges dans des pages de 4–7 k lignes |
| `StreamBuilder` | 57 | re-render par événement Firestore |
| `.snapshots()` | 33 | flux temps réel non mutualisés |
| `FirebaseFirestore.instance` direct | 114 | requêtes non centralisées/cachées |
| `ListView(` non virtualisé | 39 (vs 14 `.builder`) | listes entières construites d'un bloc |
| `shrinkWrap: true` | 17 | mesure complète de la liste, coût quadratique possible |
| `print`/`debugPrint` | 322 | actifs en release, bruit + coût |
| `Timer.periodic` | 8 | réveils périodiques à auditer |

Points chauds identifiés :

- **Décodage JSON sur le main thread** : `cities_compact.json` (2,21 MiB) est
  chargé via `rootBundle.loadString` + `jsonDecode` dans au moins trois
  chemins (`city_search.dart`, `city_repo_compact.dart`,
  `city_postal_autocomplete_field.dart:64` — déclenché depuis un widget).
  Sur le web (pas d'isolates), décoder 2 MiB gèle l'UI plusieurs centaines de
  ms — typiquement au premier focus du champ ville du formulaire de
  publication. Les `parcours_fiches_*.json` (jusqu'à 1,9 MiB) posent le même
  problème dans le parcours entrepreneur.
- **Stream recréé à chaque build** : `mes_projets_fiche_page.dart:85`
  (`stream: col.snapshots()` inline) — nouvelle souscription Firestore à
  chaque rebuild du widget.
- **4 `FutureBuilder` avec future inline** (relancent la requête à chaque
  rebuild).
- **Pages monolithiques** : `toolbox_je_me_lance_page.dart` (7 217 lignes),
  `admin_space_page.dart` (5 777), `conversation_thread_page.dart` (5 182),
  `publish_offer_page.dart` (5 131)… Un `setState` dans ces pages reconstruit
  des arbres de widgets énormes ; c'est le premier facteur de jank perçu, et
  il converge avec le chantier « Phase 1 architecture » (guardrail de taille).

## 4. Volet graphique

- Rendu CanvasKit (par défaut Flutter web) : rendu fidèle, mais ~6–7 MiB de
  wasm au premier chargement ; le service worker le met ensuite en cache.
- 21 `AnimationController` — volume raisonnable.
- Logos PNG surdimensionnés (cf. §1) ; le carrousel d'accueil est déjà en
  WebP (bonne pratique à généraliser).
- `Image.network` (10) vs `CachedNetworkImage` (9) : sur le web le cache HTTP
  du navigateur s'applique déjà ; veiller surtout à fournir `cacheWidth`/
  dimensionnement pour éviter de décoder des images pleine résolution dans des
  vignettes.

## 5. Recommandations priorisées

1. **P0 — décharger le décodage JSON** : réduire `cities_compact.json`
   (format binaire compact, découpage par département, ou index précalculé) et
   différer/mémoïser son chargement unique ; ne jamais le décoder depuis un
   widget. Idem pour les fiches parcours (chargement par fiche plutôt que par
   famille complète).
2. **P0 — paralléliser le bootstrap** : ne garder bloquant avant `runApp` que
   Firebase core ; lancer App Check, Remote Config, persistence et
   `getRedirectResult` en parallèle après le premier frame, derrière le shell.
3. **P1 — corriger les rebuilds coûteux** : stream inline de
   `mes_projets_fiche_page.dart:85` et les 4 `FutureBuilder` inline ;
   convertir les `ListView(` de listes longues en `.builder`.
4. **P1 — poursuivre la décomposition des pages géantes** (déjà cadrée par le
   guardrail Phase 1) : c'est l'action qui réduit le plus le jank perçu et le
   coût des `setState`.
5. **P2 — régime du bundle** : exclure les `.js.symbols` et `NOTICES` du
   déploiement, convertir les logos en WebP, sous-ensembles de Font Awesome,
   envisager le code-splitting (`deferred as`) pour l'espace admin et la
   toolbox (probablement ~2 MiB de `main.dart.js` à eux seuls).
6. **P2 — mesurer en continu** : ajouter un budget « poids première visite »
   (HTML + bootstrap + main.dart.js + variant CanvasKit + assets critiques)
   distinct du budget disque total, et instrumenter LCP/INP réels via
   `web-vitals` ou le monitoring maison (`app_monitoring_service.dart`).

## Limites de l'audit

Le conteneur d'audit n'a pas accès réseau au domaine de production (politique
proxy) : les métriques runtime (LCP, CLS, long tasks) n'ont pas pu être
mesurées sur site réel. Les chiffres bundle proviennent du contrôle de budget
du déploiement 1876 ; les constats fluidité sont issus de l'analyse statique.
Une passe Lighthouse/DevTools depuis un poste ayant accès à
`https://ilipresto.web.app` complèterait utilement ce rapport.

## Contrôle du 20 juillet 2026

Re-vérification demandée après 8 commits supplémentaires sur `main`
(`94917655` → `e0c5236f`, run de déploiement `29759879206`, tous verts).

- **Bundle inchangé au byte près** : `main.dart.js` 6,06 MiB, `assets/`
  23,90 MiB, total 67,17 MiB, même classement des 30 plus gros fichiers
  (CanvasKit, JSON de données, symboles de debug, logos). Le budget de 75 MiB
  reste consommé à 90 %.
- **Tous les compteurs d'anti-patterns strictement identiques** au 19
  juillet : 658 `setState`, 57 `StreamBuilder`, 33 `.snapshots()`, 114
  `FirebaseFirestore.instance` direct, 322 `print`/`debugPrint`, 39 `ListView(`
  non virtualisées vs 14 `.builder`, 17 `shrinkWrap: true`, 1 seul
  `deferred as` dans tout `lib/`. Le stream inline de
  `mes_projets_fiche_page.dart:85` est toujours présent tel quel.
- **Classement des 14 plus gros fichiers inchangé** (`toolbox_je_me_lance_page.dart`
  toujours en tête à 7 217 lignes). `lib/` est passé de 119 325 à 119 526
  lignes (+201, négligeable).
- **Seul mouvement notable** : `lib/pages/offers/widgets/payment_info_popup.dart`
  a été décomposé (−418 lignes, extraction de
  `payment_info_popup_header.dart` et `payment_info_popup_rules.dart`) — dans
  l'esprit de la recommandation P1, même si ce fichier n'était pas parmi les
  plus gros audités. Aucun des autres fichiers cités dans ce rapport n'a été
  touché ; les 8 commits recensés sont uniquement des vagues de couverture de
  tests.
- **Bonus sécurité observé en passant** : les dumps `env:` du run
  `29759879206` ne contiennent plus de `GOOGLE_CREDENTIALS_JSON` — seuls
  `GOOGLE_APPLICATION_CREDENTIALS` et `CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE`
  pointent vers le fichier de credentials éphémère généré par Workload
  Identity Federation. Confirme, sur un run réel, que la migration WIF ne
  réintroduit aucune fuite de clé dans les logs.

**Conclusion : aucun des constats ni des recommandations de ce rapport n'est
caduc.** Les priorités P0/P1/P2 restent valables telles quelles.

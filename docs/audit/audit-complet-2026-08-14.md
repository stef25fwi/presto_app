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
| 1 | `ai-production-smoke.yml` n'a **jamais** été vert : 89 exécutions depuis le 05/08, 0 succès. Trois causes de plomberie empilées (IAM `signBlob`, jeton App Check non transmis, TTL invalide), corrigées ici | P0 |
| 1 bis | **Une fois la plomberie réparée, le test révèle un défaut de production réel** : V1 envoie tout audio non-WAV à Google STT en `LINEAR16`, reçoit zéro résultat sans erreur, et renvoie ce transcript vide en HTTP 200. Le mobile enregistrant en AAC/m4a, la dictée vocale est concernée dès que le rollout V2 ne couvre pas l'utilisateur — à confirmer en Remote Config | **P0 — le plus important de cet audit** |
| 2 | La checklist Play Store affirme au point 1.1 qu'« aucun AAB release n'a jamais été produit » — **faux** : un run réussi existe (`release_android.yml`, run du 2026-07-30, AAB construit et signé, upload Play Console volontairement `skipped`) | P1 — doc à corriger |
| 3 | 7 des 9 contrôles de sécurité Phase 8 restent `pending` — mais l'enforcement App Check Firestore/Storage est en réalité **déjà actif** en console : déficit de preuve, pas de blocage technique | P1 (requalifié) |
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

### 1.b Second blocage, masqué par le premier (corrigé dans ce commit)

Le rôle IAM a été accordé le 2026-08-14 à
`github-firebase-deploy@presto-app-74abe.iam.gserviceaccount.com` et la
signature de jetons fonctionne désormais. Le workflow relancé échoue alors une
étape plus loin, sur une cause **différente** que le blocage IAM masquait :

```
Error: Unable to exchange custom token:
{"error":{"code":401,"message":"Firebase App Check token is invalid.",
"status":"UNAUTHENTICATED"}}
```

`functions/scripts/microia_production_smoke_test.mjs` créait le jeton App
Check **après** l'appel `signInWithCustomToken` à Identity Toolkit, et ne le
joignait pas à la requête. Or l'enforcement App Check est actif sur l'API
Authentication (§3), qui rejette donc l'échange. Corrigé ici : le jeton App
Check est créé avant l'échange et transmis dans l'en-tête
`X-Firebase-AppCheck`.

### 1.c Troisième cause, également masquée (corrigée dans ce commit)

Le run suivant échoue encore, une ligne plus haut :

```
Error: ttlMillis must be a duration in milliseconds between 30 minutes
and 7 days (inclusive).
```

Le script demandait un TTL de 10 minutes à `getAppCheck().createToken()`,
alors que l'API impose un minimum de 30 minutes. Ce paramètre n'a donc
**jamais** pu produire un jeton : l'appel était simplement inatteignable
jusqu'ici. Porté à 30 minutes.

### 1.d Ce workflow n'a jamais été vert

Vérification de l'historique complet accessible via l'API Actions : **89
exécutions recensées entre le 2026-08-05 et le 2026-08-14, dont 82 en échec
et 7 `skipped` — aucun succès**. Aucune des trois causes ci-dessus n'est donc
une régression récente : ce sont trois défauts empilés, dont deux dans le code
du script, qui n'ont jamais permis à ce smoke test de s'exécuter en entier.

La conséquence dépasse la CI : **la vérification de bout en bout du pipeline
micro-IA en production (Functions, Auth, App Check, fallback, logs) n'a jamais
produit de preuve valide**. Les artefacts `ai-production-smoke-*` archivés
depuis le 5 août ne contiennent que des traces d'échec (496 à 734 octets). Les
contrôles de la Phase 8 qui s'appuieraient sur ces preuves doivent être
considérés comme non démontrés, indépendamment de leur statut déclaré.

Cet enchaînement illustre un point de méthode : une CI rouge en continu est
souvent lue comme *un* problème, alors qu'elle peut en masquer plusieurs
empilés, chacun invisible tant que le précédent bloque. Le compteur « 30/30
derniers runs en échec » ne disait rien du nombre de causes.

### 1.e Ce que les trois correctifs ont révélé : le fallback V1 est cassé en production (P0)

Une fois la plomberie réparée, le script s'exécute réellement (11 s contre 1 s
auparavant) : authentification, jeton App Check, appels aux Cloud Functions de
production. Il échoue alors sur une **assertion fonctionnelle**, pas technique :

```
Error: V1 did not recover after the forced V2 unavailable scenario
    at forceV2UnavailableThenRecoverWithV1 (…:140)
```

La séquence du test est discriminante :

1. ligne 275 — `microIaProcessAudioV2` est appelée avec l'audio de synthèse ;
2. ligne 280 — le test **exige** un transcript non vide de V2, sinon il s'arrête ;
3. ligne 283 — le scénario de fallback n'est atteint **que si l'étape 2 a réussi** ;
4. ligne 134 — `microIaProcessAudio` (V1) est appelée avec **le même
   `commonData`**, donc les mêmes octets audio ;
5. ligne 139 — V1 répond **HTTP 200 sans erreur**, mais sans texte exploitable.

`callCallable` lève une exception sur toute réponse non-OK : le fait
d'atteindre la ligne 139 prouve que V1 a répondu avec succès, simplement avec
un transcript vide. Et la revue de `functions/index.js` confirme que V1
retourne bien un champ `text` (l. 2231/2245/2337) : le contrat attendu par le
test est correct, ce n'est pas un décalage de forme.

**Conclusion : sur une entrée identique, V2 transcrit correctement et V1
renvoie du vide.** L'hypothèse d'un audio de synthèse inexploitable par la
reconnaissance vocale est écartée par l'étape 2. Le défaut est localisé dans
le chemin V1.

L'enjeu n'est pas cosmétique : V1 est le **filet de sécurité** du pipeline
micro-IA. Si V2 devient indisponible, l'application bascule sur un chemin qui,
en l'état, retourne des transcriptions vides. Le mécanisme de résilience que ce
smoke test a précisément pour rôle de vérifier ne fonctionne pas.

**Ce constat est resté invisible au moins 10 jours** : il ne pouvait pas être
détecté tant que le script échouait avant d'atteindre cette étape.

### 1.f Cause racine du fallback V1 (analyse de code)

La chaîne est entièrement reconstituable dans `functions/index.js`.

**Configuration par défaut** (l. 849 et 868) : `mode = "GOOGLE_ONLY"` et
`ultraFastEnabled = false`. Donc `buildTryOrder("GOOGLE_ONLY")` (l. 1592)
retourne **une seule tentative** : `["GOOGLE_ONLY"]`. Le `fallbackEnabled`
n'a alors aucun effet — il n'y a pas de second provider à essayer.

**Routage audio** (l. 1503) : `canUseGoogleStt()` retourne `true` dès que
l'audio n'est pas du WAV — commentaire à l'appui : *« may be raw PCM or other;
let Google try »*. Un conteneur m4a/AAC est donc transmis à Google STT
configuré en dur en `encoding: "LINEAR16"` (l. 1532). Google ne décode rien,
ne lève pas d'erreur, et renvoie simplement zéro résultat : `text = ""`
(l. 1546-1548).

**Absorption silencieuse de l'échec** (l. 2243-2270) : `best` est affecté à
chaque tentative *techniquement* réussie, y compris avec `out.text` vide. Le
seul garde-fou est `if (!best) throw` — il ne se déclenche que si **toutes**
les tentatives ont levé une exception. Un provider qui répond « sans erreur
mais sans texte » remplit `best`, neutralise le chemin d'erreur, et la
fonction retourne HTTP 200 avec `text: ""`. Aucune vérification que
`best.text` est non vide n'existe avant le `return best` (l. 2337).

**Pourquoi V2 réussit sur le même audio** : `micro_ia_callable.ts` mappe
explicitement les types MIME vers les encodages Google (l. 35-46) et
`googleEligible()` retourne `false` pour `audio/mp4`, qui n'est dans aucune
branche du mapping. V2 route donc vers OpenAI Whisper, qui gère nativement le
m4a. V2 a le contrôle d'éligibilité que V1 n'a pas.

### 1.g Portée réelle : le mobile est concerné, pas seulement le fallback

Le point suivant dépasse le cadre du smoke test.

- Le client Flutter enregistre en **AAC/m4a** sur mobile
  (`lib/pages/publish_offer_page.dart` l. 3200-3204 : `AudioEncoder.aacLc`,
  extension `m4a` ; trace utilisateur l. 3266 : « Enregistrement mobile lancé
  en AAC/m4a ») et envoie `audioContentType: 'audio/mp4'` (l. 3490).
- Le choix V1/V2 est piloté par Remote Config
  (`micro_ia_remote_config.dart`) : `shouldUseV2()` retourne `false` si le flag
  est absent ou le rollout à 0. **Les valeurs par défaut du dépôt sont
  `micro_ia_v2_enabled = false` et `rollout = 0`** (l. 45-46).

Autrement dit, avec la configuration par défaut, un enregistrement vocal
mobile emprunte V1 et retombe exactement sur la chaîne décrite en §1.f :
transcription vide renvoyée en HTTP 200, sans erreur remontée à
l'utilisateur. V1 ne fonctionne de façon fiable que pour du WAV PCM 16 bits.

**À vérifier en console** (non lisible depuis le dépôt) : les valeurs réelles
de `micro_ia_v2_enabled` et `micro_ia_v2_rollout_percent` dans Remote Config.
Elles déterminent la part d'utilisateurs actuellement exposée. Deux cas :

- rollout à 100 % → les utilisateurs passent par V2 et sont épargnés, mais le
  filet de sécurité V1 reste inopérant en cas de bascule ;
- rollout à 0 % ou flag absent → **la dictée vocale mobile renvoie des
  transcriptions vides pour tout le monde**.

Ce point est directement lié à l'objet de cette branche : publier l'AAB
Android sans avoir tranché la configuration V1/V2 revient à livrer la dictée
vocale dans un état potentiellement non fonctionnel.

### 1.h Deux défauts secondaires relevés au passage

- `providerWhisper` (l. 1555) nomme systématiquement le fichier `audio.wav`
  quel que soit le format réel. L'API OpenAI déduit le format de l'extension :
  un vrai m4a serait donc mal étiqueté. Sans effet dans le mode `GOOGLE_ONLY`
  par défaut, mais actif dès que `WHISPER_ONLY` ou `HYBRID` est retenu.
- Le commentaire l. 2192 annonce un fallback « si le score est extrêmement bas
  (ex : texte vide) ». L'intention est correcte, mais elle n'est pas réalisée :
  le fallback n'existe que s'il reste une tentative dans `tryOrder`, ce qui
  n'est jamais le cas dans le mode par défaut.

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

## 3. Sécurité — contrôles Phase 8 (P0, à requalifier)

```
node tools/quality/check_security_controls.mjs
→ {"ready":true,"total":9,"verified":2,"pending":7}
```

Toujours seulement 2 contrôles `verified` dans le dépôt (blocage previews
Firebase → prod, CodeQL actif) ; les 7 mêmes contrôles restent `pending` sans
preuve dans `docs/evidence/security/` (le dossier n'a que `ai/`, `go-live/`,
`messaging/`, `ux/`).

**Écart important entre le dépôt et la réalité (constaté en console Firebase
le 2026-08-14)** : l'enforcement App Check est en fait **déjà actif** sur
plusieurs API, alors que `quality/security-controls.json` les déclare
`pending` :

| Contrôle | État déclaré (dépôt) | État réel (console App Check) |
|---|---|---|
| `app-check-firestore-enforced` | `pending` | **Appliqué** — 100 % de requêtes validées |
| `app-check-storage-enforced` | `pending` | **Appliqué** |
| `app-check-functions-enforced` | `pending` | **non appliqué** (console propose encore de l'activer) |

Sont également appliqués mais hors périmètre des 9 contrôles : Realtime
Database, Firebase AI Logic (mode basique), Authentication (99 % validées) et
Places API.

Deux contrôles sur trois sont donc **satisfaits dans les faits mais non
documentés** : le blocage n'est pas technique, c'est un déficit de preuve. Il
suffit de déposer les captures/exports correspondants dans
`docs/evidence/security/` et de passer les statuts à `verified`. Seul
`app-check-functions-enforced` demande une action réelle.

À noter : c'est précisément cet enforcement sur Authentication qui provoque le
second échec de la CI décrit au §1.

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
  détectée dans ce périmètre. Les deux causes racines sont identifiées et
  traitées (IAM en console, jeton App Check dans le script) ; un run vert reste
  à obtenir pour clore le point.

## Recommandations priorisées

- **P0 — immédiat, sans code** : relever `micro_ia_v2_enabled` et
  `micro_ia_v2_rollout_percent` dans Remote Config (§1.g). Cette seule lecture
  dit si la dictée vocale mobile est actuellement dégradée pour les
  utilisateurs ou seulement en cas de bascule. Rien d'autre ne peut être
  priorisé correctement avant.
- **P0 — corriger V1** (§1.f), trois défauts distincts et indépendants :
  1. ne plus renvoyer un transcript vide en succès (ajouter un contrôle sur
     `best.text` avant le `return`, ou ne pas affecter `best` sur un résultat
     vide) — c'est le défaut qui transforme une panne en silence ;
  2. donner à V1 un contrôle d'éligibilité par type MIME comme celui de V2,
     pour ne pas envoyer de m4a à un décodeur `LINEAR16` ;
  3. nommer correctement le fichier transmis à Whisper (§1.h).
- **P1** — Reconsidérer le mode par défaut `GOOGLE_ONLY` : il réduit
  `tryOrder` à une seule tentative et rend le mot « fallback » trompeur dans
  tout le code environnant.
- **P0 — fait le 14/08** : rôle IAM `serviceAccountTokenCreator` accordé au
  compte de service CI (§1) ; les correctifs du jeton App Check (§1.b) et du
  TTL (§1.c) sont inclus dans ce commit. La CI ne redeviendra verte qu'une fois
  le §1.e traité — l'échec restant est désormais un signal juste.
- **P1** — Déposer les preuves App Check Firestore et Storage dans
  `docs/evidence/security/` et passer ces deux contrôles à `verified` : ils
  sont **déjà appliqués en production** (§3). Seul
  `app-check-functions-enforced` demande une action technique réelle.
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

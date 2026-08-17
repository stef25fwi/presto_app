# Revue OWASP Top 10 (2021) — iliprestō

Contrôle : `owasp-review-complete` (`quality/security-controls.json`).

## Nature de la preuve et ses limites

Revue de code, pas un test d'intrusion. Périmètre couvert : callables Cloud
Functions (`functions/src/`), règles Firestore (`firestore.rules`), règles
Storage (`storage.rules`), en-têtes HTTP (`firebase.json`), et une recherche
ciblée de secrets — soit le périmètre minimal exigé par le contrôle
(« callables Cloud Functions, règles Firestore et Storage, webhooks Stripe
et Brevo, pages publiques »). **Non couvert** : les webhooks au-delà de la
vérification de signature, un balayage exhaustif de tous les appels
`fetch`/`spawn` du dépôt, et tout ce qui exige un accès runtime (logs de
production, comportement réel sous charge). Chaque catégorie ci-dessous
porte un constat et une décision assumée — traité, accepté avec
justification, ou reporté avec échéance — conformément à
`quality/security-controls.json`.

## A01 — Contrôle d'accès défaillant

**Traité.** Vérifié à la lecture (`firestore.rules` et `storage.rules`) :

- `users/{userId}` : `create`/`update` bloquent explicitement l'écriture des
  champs de rôle (`protectedUserFields()`, l. 228-260) — `roles`, `role`,
  `admin`, `superadmin`, `isAdmin`, `superAdmin`, etc. La liste couvre
  exactement les champs lus par `hasUserDocAdminRole()` (l. 102-122) : un
  utilisateur ne peut pas s'auto-élever en écrivant sur son propre document.
  `storage.rules` (`hasUserDocRole()`, l. 18-29) lit les mêmes champs via
  `firestore.get()` sans les réécrire : le point de verrouillage reste unique
  côté Firestore, Storage ne fait que le consulter.
- `admins/{uid}` et `adminUsers/{adminId}` : écriture réservée à
  `isAdminClaim()` (l. 391-394), résolu depuis un custom claim posé
  côté serveur — jamais depuis un champ Firestore modifiable par le client.
- `storage.rules` scope chaque chemin d'upload par `uid` (`listingDrafts/{uid}/...`,
  `profilePhotos/{uid}/...`, `stt/{file}` avec regex `^{uid}_...`) et interdit
  purement et simplement l'écriture (`allow write: if false`) sur les
  collections de traitement serveur (`moderation_review`, `rejected_ad_images`,
  `listings`, `offers*` legacy) — le commentaire du code est explicite :
  « Client apps must never write here ».
- Traversée de chemin sur les uploads audio (`functions/index.js`,
  `prepareUploadedAudioForOpenAi`, l. 1663-1677) : rejet explicite de `..`,
  `/` en tête et `\`, plus vérification d'appartenance du chemin à l'`uid`
  authentifié (`stt/${uid}_...`) avant toute lecture Storage.

## A02 — Défaillances cryptographiques

**Traité.** `Strict-Transport-Security` avec `preload` sur toutes les routes
(§3.3 de l'audit général), aucune clé privée ni secret en dur détecté par
recherche de motif (`sk_live_`, `sk_test_`, `BEGIN PRIVATE KEY`, `AKIA...`) —
seules occurrences dans `stripe_mode.ts`, qui valide des préfixes, pas des
clés réelles. Secrets applicatifs (Stripe, Brevo) gérés via
`firebase functions:secrets:set`, pas via variables d'environnement en clair
dans le dépôt.

**Reporté.** Aucun inventaire des algorithmes/rotations n'a été produit ici —
recoupe `secrets-inventory-current`, toujours `pending`.

## A03 — Injection

**Traité.** Aucun `eval(`, `exec(`/`execSync(` avec entrée non filtrée trouvé
dans `functions/src`. L'unique exécution de processus externe
(`functions/index.js`, `runFfmpegToWav16kMono`, l. 1629-1655) utilise
`spawn(ffmpegPath, args, ...)` avec `args` en tableau — pas de shell
intermédiaire, donc pas d'injection de métacaractères possible même si un
nom de fichier était hostile. Firestore est un magasin NoSQL sans
concaténation de requête textuelle : la classe d'injection SQL classique ne
s'applique pas au chemin de données principal.

**Traité également** : `storage.rules` interdit l'upload de SVG sur les
photos de profil publiques (`isSafeImageContentType()`, appliqué à
`profilePhotos/{uid}/{fileName}`, commentaire explicite « pas de SVG (XSS)
sur photo publique ») — un SVG peut embarquer du script exécutable, et cette
collection est servie en lecture publique sans authentification.

**Non couvert.** Pas de recherche exhaustive de `dangerouslySetInnerHTML`
équivalent côté web (rendu HTML dynamique dans `web/*.html` généré par les
scripts SEO) — à vérifier séparément si du contenu utilisateur y transite un
jour.

## A04 — Conception non sécurisée

**Accepté avec justification.** Le flux de modération (`moderateNewOffer`,
`moderation.ts`) route les photos vers Vision API avant publication ; le
callable `logAdminAction` trace les décisions administratives. La conception
n'a pas fait l'objet d'un modelage de menace formel dans cette session — ce
qui est cohérent avec le périmètre d'un audit de code, pas d'une revue de
conception produit.

## A05 — Mauvaise configuration de sécurité

**Traité, avec une réserve documentée.** En-têtes de sécurité complets
(CSP, `X-Frame-Options`, `X-Content-Type-Options`, `Referrer-Policy`,
`Permissions-Policy`) sur toutes les routes. App Check appliqué et
fail-closed en production (`app_check_policy.ts`).

**Réserve assumée** : `script-src` de la CSP inclut `'unsafe-inline'` (en
plus de `'wasm-unsafe-eval'`, nécessaire à CanvasKit). C'est un compromis
courant pour Flutter web + reCAPTCHA, qui affaiblit la protection XSS que la
CSP est censée apporter. Décision : **accepté**, tant qu'aucune alternative
(nonces, hash CSP) n'est mise en œuvre pour le JS inline nécessaire au
bootstrap Flutter — reporté sans échéance faute d'un porteur identifié.

**Réserve additionnelle, déjà connue** : `users/{userId}` (Firestore) et
`stt/{file}` (Storage) n'exigent pas `hasAppCheck()` en écriture — les deux
portent le même commentaire explicite dans le code : le SDK Flutter web
n'attache pas le jeton App Check aux requêtes Firestore/Storage, seulement
aux Cloud Callables. Compensé par `isSignedIn()` + égalité d'`uid` + (côté
Firestore) champs protégés non modifiables, (côté Storage) nommage de
fichier lié à l'`uid` + whitelist de type de contenu + taille max.
**Accepté avec justification déjà présente dans le code, cohérente entre les
deux fichiers de règles.**

## A06 — Composants vulnérables ou obsolètes

**Traité, vérifié dans cette session.** `npm audit` : 0 vulnérabilité sur les
deux périmètres du dépôt (racine et `functions/`) depuis le 16/08, preuve
dans `docs/evidence/security/dependency-audit.md`. CodeQL actif sur chaque
PR et sur `main` (`codeql-enabled`, déjà `verified`).

## A07 — Défaillances d'identification et d'authentification

**Traité.** Authentification déléguée à Firebase Auth (pas de gestion de mot
de passe maison). App Check comme second facteur applicatif sur les
callables sensibles. `firestore.rules` distingue systématiquement
`isSignedIn()` de `isAdmin()` — aucune route de contournement identifiée à la
lecture.

**Non couvert.** Le flux OTP téléphone (`phone_verification.ts`,
`reservePhoneVerificationAttempt`) n'a pas été audité pour un risque de
brute-force applicatif (limite de tentatives, fenêtre de temps) dans cette
session.

## A08 — Défaillances d'intégrité des logiciels et des données

**Traité.** Vérification de signature webhook Stripe par HMAC avec
comparaison en temps constant (`stripe_webhook.ts`, `safeHexEqual`,
l. 85-93 — `crypto.timingSafeEqual`, pas de comparaison de chaîne naïve).
Webhook Brevo : rejet explicite non authentifié
(`email_webhook_auth_rejected` → HTTP 401, `handler.ts` l. 55-56). CodeQL et
`npm audit` couvrent la chaîne de dépendances (A06). Déploiements de preview
Firebase structurellement bloqués sur le projet de production
(`firebase-preview-production-blocked`, déjà `verified`).

## A09 — Défaillances de journalisation et de surveillance de sécurité

**Accepté avec justification, partiellement couvert.** `logAdminAction`
existe comme callable dédié à la traçabilité des actions administratives.
Crashlytics capture les erreurs non gérées côté client
(`lib/bootstrap/crash_reporting.dart`). Aucun tableau de bord de
surveillance de sécurité (tentatives d'accès refusées, pics d'échec
d'authentification) n'a été vérifié comme actif en production dans cette
session — recoupe `monitoring-dashboards-live`, hors du périmètre code.

## A10 — Falsification de requête côté serveur (SSRF)

**Traité, sur le périmètre vérifié.** Les deux fonctions génériques d'appel
sortant identifiées (`fetchGoogleApiJson` dans `google_api.ts`, et l'appel
Stripe dans `billing/callables.ts`) construisent leur URL sur un hôte en dur
(`vision.googleapis.com`, `api.stripe.com`) — jamais depuis une valeur
fournie par le client. Aucune trace d'un endpoint qui accepterait une URL
arbitraire fournie par l'utilisateur pour un `fetch` serveur.

**Non exhaustif** : recherche ciblée sur les deux clients HTTP génériques du
dépôt, pas un balayage de tous les appels réseau sortants.

## Synthèse

| Résultat | Nombre |
|---|---:|
| Traité | 6 (A01, A03, A06, A07, A08, A10) |
| Accepté avec justification | 3 (A04, A05, A09) |
| Reporté sans échéance | 1 volet (`unsafe-inline` CSP, dans A05) |

Aucune catégorie n'est laissée sans constat ni décision. Les réserves
explicites (brute-force OTP non vérifié, dashboards de surveillance non
confirmés en production, CSP `unsafe-inline`) sont des dettes documentées,
pas des angles morts silencieux.

**Sur le statut du contrôle** : `firestore.rules` et `storage.rules` ont
désormais reçu la même rigueur, ce qui referme le principal angle mort
identifié lors d'une première passe de cette revue. Il reste néanmoins un
écart littéral avec l'énoncé du contrôle (« reporté **avec échéance** ») :
le volet CSP `unsafe-inline` est reporté sans échéance, faute d'un porteur
identifié pour trancher entre l'accepter durablement ou financer une
migration vers des nonces/hash CSP. Assigner cette échéance est le seul
point qui sépare ce document d'une clôture complète — décision humaine, pas
une lecture de code supplémentaire.

## Comment rejouer

Cette revue est une lecture de code : rejouer signifie relire
`firestore.rules`, `functions/src/modules/billing/stripe_webhook.ts`,
`functions/src/modules/email/webhooks/handler.ts`,
`functions/src/modules/marketplace/services/{google_api,moderation,recaptcha}.ts`
et `functions/index.js` (`prepareUploadedAudioForOpenAi`,
`runFfmpegToWav16kMono`) aux mêmes lignes, et confirmer qu'aucune régression
n'a été introduite depuis.

Vérifié le 2026-08-16.

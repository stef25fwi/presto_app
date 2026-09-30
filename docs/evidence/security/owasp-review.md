# Revue OWASP Top 10:2021 — 30 septembre 2026

Auteur : Codex. Dépôt `stef25fwi/presto_app`, PR #1464.
Base examinée : contenu publié `4d19bd2f76f9fc5182499f789a820f6f1bcf6b28`,
avec les nouveaux correctifs Resend et VEO ajoutés dans cette même PR.
Référentiel : OWASP Top 10:2021, celui de la matrice existante.
https://owasp.org/Top10/2021/

**Contrôle `owasp-review-complete` : verified — revue effectuée.**
Cette preuve atteste une revue et ses décisions, pas un test d'intrusion,
l'état des consoles ou une absence universelle de faille. Les contrôles
indépendants clés/secrets restent bloquants. Les échéances ci-dessous sont
des cibles de remédiation proposées, pas une attestation d'exécution future.

## Périmètre et méthode

Lecture des callables Auth/billing/marketplace/admin, des politiques App
Check et rôles ; règles Firestore et Storage ; webhooks Stripe et Brevo,
providers Brevo/Resend et handler e-mail ; clients HTTP sortants identifiés
par recherche dans `functions/src` et `functions/index.js` ; subprocess
ffmpeg, VEO ; Hosting et pages publiques/SEO ; logs et contrôles CI.
La recherche source et les tests ne remplacent pas les essais connectés.

## A01 — Contrôle d'accès

**Traité sur le périmètre testé.** `protectedUserFields` empêche la
modification cliente des rôles/champs privilégiés. Les registres admins
requièrent des claims serveur. La messagerie cliente n'a plus d'accès direct
en écriture ; les callables contrôlent les participants. Les médias sont
liés à l'uid avec tailles/types limités ; les collections de traitement
serveur interdisent les écritures clientes. Trois suites de règles Firestore
en émulateur ont été validées dans le lot d'intégration. Cela n'atteste pas
les rôles déployés et IAM réels.

## A02 — Cryptographie

**Traité dans le code ; production reportée au 07/10/2026.** TLS/HSTS est
configuré au Hosting. Stripe vérifie HMAC SHA-256, comparaison en temps
constant et tolérance de cinq minutes. Brevo compare ses credentials en
temps constant. Resend est corrigé : timestamp ancien/futur rejeté et
comparaison en temps constant. Les secrets ne sont pas exportés. Les
rotations fournisseurs/restrictions réelles restent pending séparément.

## A03 — Injection

**Traité sur les usages identifiés.** ffmpeg utilise `spawn` avec arguments
en tableau, sans shell ; chemin audio contrôlé et lié à l'uid. Pas d'eval ou
exec avec entrée cliente identifié dans Functions. Les médias publics
acceptent des types raster et excluent SVG. `public-route-seo.js` utilise
des constantes de routes légales pour son innerHTML. La génération SEO
locale échappe textes et JSON. Pas de test XSS exhaustif de tous les écrans.

## A04 — Conception

**Reporté au 07/10/2026.** Quotas, transactions, rôles et modération sont
présents. Le modèle de menace formel et les essais d'abus multicomptes
restent à compléter avant ouverture. Cette revue ne vaut pas acceptation
métier de ces risques.

## A05 — Configuration

**Traité dans le code ; réserves reportées au 07/10/2026.** App Check est
fail-closed pour les callables en production ; en-têtes de sécurité présents.
La CSP garde `unsafe-inline` pour le bootstrap actuel : étudier nonces/hash
avec essais Flutter/reCAPTCHA. Certaines règles source n'exigent pas de
jeton App Check ; cela ne démontre pas l'enforcement Firebase côté API.
Aucune attestation live nouvelle n'est produite ici. Les restrictions des
clés restent bloquantes dans leur propre contrôle.

## A06 — Dépendances

**Traité pour les dépendances Node auditées.** brace-expansion, nodemailer
et qs corrigés ; audits de production racine et Functions du 30/09 à zéro
vulnérabilité. Gate Dependency security du SHA publié vert, run 36714410536 ;
CodeQL vert, run 36714410634. Ne couvre pas tous les composants natifs Dart
ou binaires du système.

## A07 — Authentification

**Traité dans le code ; abus SMS reporté au 07/10/2026.** Firebase Auth
reste l'autorité ; `confirmPhoneVerified` relit Admin Auth. Quota gratuit
transactionnel sur 24 h, libération liée à l'id de réservation. Toutefois,
la libération est demandée par le client et ne prouve pas l'absence d'envoi
SMS. Les plans payants/admins sont exemptés du quota applicatif. Tester
protections provider, multicomptes et boucles reserve/release avant ouverture.
App Check n'est pas un second facteur d'authentification d'une personne.

## A08 — Intégrité

**Traité ; essais live reportés au 07/10/2026.** Stripe vérifie corps brut,
timestamp et mode test/live, puis lease transactionnel d'événement pour
les doublons/concurrence. Brevo est authentifié avant écriture Firestore,
avec limite de payload et ids stables. Son secret Bearer/custom header ne
prouve pas la fraîcheur d'un événement. Resend vérifie désormais version
v1, timestamp et HMAC ; modifier le corps signé est rejeté par les tests.
Rejouer paiements, délivrabilité et retries en environnement de test.

## A09 — Journaux et surveillance

**Traité dans le code ; supervision live reportée au 07/10/2026.** Logger
avec caviardage récursif et chaînes limitées ; rejet webhook journalisé avant
mutation ; surface de traçabilité des actions admin. Dashboards/alertes IAM
et Auth, accès Cloud Logging et rétention des payloads e-mail restent à
vérifier en production.

## A10 — SSRF

**Traité sur les appels repérés ; essai VEO live reporté au 07/10/2026.**
Stripe, Brevo, Resend, Places, Google API et SIRET ciblent des hôtes définis
par le serveur. VEO téléchargeait une URL de réponse provider en suivant
automatiquement les redirections avec un header API privé. Le nouveau
`veo_download.ts` exige HTTPS Gemini au départ, valide chaque hop et limite
les redirections à Gemini et Google Cloud Storage. La clé n'est pas envoyée
aux hôtes Storage. IP privées, userinfo, ports non standard et hôtes trompeurs
sont rejetés. Les mocks le vérifient ; une génération réelle reste requise
pour confirmer la compatibilité des destinations utilisées par Google.

## Validation

- Compilation TypeScript réussie.
- Suite Functions : **363 réussis, 2 ignorés, zéro échec**.
- Tests ciblés Stripe/Brevo/Resend/VEO : **26 réussis**, sept nouveaux tests
  sur rejeu, intégrité, URLs et non-transmission de clé.
- Collecteur metadata : quatre tests réussis (exclusion des valeurs,
  absence de fausse attestation de rotation et collecte vide/échouée).
- Recherche ciblée de secrets : voir `secrets-inventory.md`.

Les dix catégories ont constat et décision explicites ; les points reportés
ne sont pas déclarés corrigés. Aucun déploiement, modification de restriction
ou changement de secret de production effectué pour cette revue. Examiner
les réserves et les preuves réelles GCP avant décision d'ouverture publique.

Références techniques :
- https://docs.svix.com/receiving/verifying-payloads/how
- https://docs.svix.com/receiving/verifying-payloads/how-manual
- https://ai.google.dev/gemini-api/docs/veo

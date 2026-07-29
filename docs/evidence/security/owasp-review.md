# Preuve — revue OWASP Top 10

**Contrôle** : `owasp-review-complete`
**Périmètre** : commit `252f190`, revue réalisée le 2026-07-29.
**Méthode** : revue de code statique du client Flutter (`lib/`), des Cloud
Functions (`functions/src/`) et des règles de sécurité (`firestore.rules`,
`storage.rules`), complétée par l'exécution des barrières automatisées du dépôt.

**Provenance** : revue conduite par un agent d'audit automatisé. Elle vaut
analyse de code, pas test d'intrusion : aucun DAST, aucune exploitation active,
aucune vérification des consoles Firebase et Google Cloud (voir *Limites*).
Elle doit être contresignée par un responsable sécurité avant go-live.

## A01 — Contrôle d'accès défaillant

`firestore.rules` (885 lignes) résiste à l'élévation de privilèges :

- `protectedUserFields()` interdit à un utilisateur de modifier lui-même
  `roles`, `admin`, `superadmin`, `accountStatus`, `subscriptionStatus`,
  `stripeCustomerId` et 40 autres champs sensibles, en création comme en mise à
  jour. Un client ne peut donc ni s'auto-promouvoir admin, ni se fabriquer un
  abonnement ;
- `pro_profiles/{uid}` verrouille les champs d'identité d'entreprise (`siret`,
  `siretVerified`, `proStatus`…) : ils ne peuvent être écrits que par l'Admin
  SDK ;
- les collections de gouvernance (`admins`, `_rate_limits`) et les jetons push
  (`users/{uid}/push_tokens`) sont en `allow read, write: if false` — accès
  serveur exclusif ;
- la suppression de compte est fermée côté règles (`allow delete: if false`) et
  passe obligatoirement par la callable `requestAccountDeletion`.

Côté Functions, 79 callables sur 79 déclarent une option App Check, et
l'autorisation applicative repose sur des custom claims plus une résolution de
rôle documentée.

**Verdict : conforme.**

## A02 — Défaillances cryptographiques

Aucun secret n'est présent dans le dépôt (recherche `sk_live_`, `sk_test_`,
`-----BEGIN PRIVATE KEY-----`, `AKIA…` : aucun résultat dans le code source).
Les 10 secrets sont dans Google Secret Manager via `defineSecret()` et
inventoriés dans `quality/secrets-inventory.json`, désormais vérifié
automatiquement.

La comparaison de signature des webhooks Stripe utilise `timingSafeEqual` sur
des buffers de longueur contrôlée — pas de comparaison de chaînes vulnérable au
timing.

Les clés `AIzaSy…` versionnées sont des identifiants publics de projet Firebase
(voir `api-key-restrictions.md`) : leur protection est la restriction, pas le
secret. **Ce point reste ouvert** — contrôle `api-keys-restricted` en attente.

**Verdict : conforme, sous réserve du contrôle `api-keys-restricted`.**

## A03 — Injection

Pas de base SQL : l'accès aux données passe par le SDK Firestore, qui lie ses
paramètres. Aucun `eval(` ni `new Function(` dans `functions/src`.

Une classe d'injection subsistait cependant côté URL — traitée en A10.

**Verdict : conforme après correctifs.**

## A04 — Conception non sécurisée

Défenses en place : limitation de débit serveur (`_rate_limits`, collection
inaccessible au client), scoring reCAPTCHA Enterprise avec seuil configurable
(`MARKETPLACE_RECAPTCHA_MIN_SCORE`), modération d'images SafeSearch, seuil de
signalements avant revue, et compteurs de sanctions (`moderationStrikeCount`,
`spamScore`) protégés en écriture cliente.

**Verdict : conforme.**

## A05 — Mauvaise configuration de sécurité

L'application d'App Check est centralisée dans `app_check_policy.ts` avec un
défaut sûr en production (appliqué sauf désactivation explicite) et un signal
`CRITICAL_APP_CHECK_DISABLED` si la production démarre sans.

**Trois réglages de console restent non vérifiés** : App Check sur Firestore,
App Check sur Storage, et les restrictions de clés API. Ils ne sont pas
vérifiables depuis le dépôt et constituent le principal reliquat avant go-live.

**Verdict : partiellement conforme — 3 contrôles ouverts.**

## A06 — Composants vulnérables ou obsolètes

13 vulnérabilités (6 hautes, 7 modérées) au départ → **0** après correctifs, sur
les deux espaces npm. Le détail est dans `dependency-audit.md`. La barrière
`dependency-audit-report.yml` s'exécute désormais sur `main`, sur chaque PR et
chaque lundi, et échoue sur toute vulnérabilité haute ou critique.

Non couvert : les dépendances Dart (`pubspec.lock`) et les paquets système de
l'image de déploiement.

**Verdict : conforme pour npm.**

## A07 — Défaillances d'identification et d'authentification

Authentification déléguée à Firebase Auth (email, Apple, réseaux sociaux). Les
rôles admin proviennent de custom claims signés, avec repli sur des documents
de gouvernance en écriture serveur uniquement, et les documents `admins` /
`adminUsers` portent une expiration (`expiresAt`) évaluée dans les règles.

**Verdict : conforme.**

## A08 — Défaut d'intégrité des données et du logiciel

Les webhooks Stripe sont vérifiés en HMAC-SHA256 sur le corps brut, avec
fenêtre anti-rejeu (`SIGNATURE_TOLERANCE_SECONDS`) et comparaison à temps
constant ; les événements sont idempotents via `lastStripeEventId`. Les
webhooks du fournisseur email disposent de leur propre secret de signature.

**Verdict : conforme.**

## A09 — Carence des journaux et de la supervision

Journalisation structurée avec identifiants de corrélation validés (couverte par
les tests Functions), et barrière `observability-slo-readiness.yml`.

Point d'attention : la baseline relève **383 appels `debugPrint`/`print`** côté
Flutter. `debugPrint` est neutralisé par Flutter en release, mais ce volume
mérite une revue ciblée des chemins qui pourraient journaliser des données
personnelles.

**Verdict : conforme, avec réserve sur le volume de journalisation client.**

## A10 — Falsification de requête côté serveur (SSRF)

Deux faiblesses réelles trouvées et **corrigées dans cette revue** :

1. **`fetchGoogleApiJson` acceptait une URL arbitraire** tout en y attachant un
   jeton OAuth de portée `cloud-platform`. Les deux appelants actuels
   n'utilisent que des hôtes littéraux, mais la signature ouvrait la voie à
   l'exfiltration d'un jeton très privilégié vers un hôte tiers. Une liste
   blanche d'hôtes (`assertAllowedGoogleApiUrl`) rejette désormais tout autre
   hôte, tout schéma non `https:`, et les tentatives d'échappement par
   identifiants d'URL (`https://hôte-autorisé@attaquant/`).
2. **`storagePath` était transmis tel quel à l'API Vision** lorsqu'il commençait
   par `gs://`. Ce champ vient du client et n'est que normalisé à la
   publication : un client pouvait donc faire lire la modération dans un bucket
   arbitraire avec les identifiants du projet.
   `resolveModerationImageUri` n'accepte plus qu'un chemin relatif au bucket du
   projet, ou un `gs://` désignant explicitement ce même bucket, et rejette les
   chemins absolus et les remontées `..`.

Les deux correctifs sont couverts par des tests (11 cas ajoutés).

**Verdict : conforme après correctifs.**

## Synthèse

| Catégorie | État |
|---|---|
| A01 Contrôle d'accès | Conforme |
| A02 Cryptographie | Conforme, sous réserve de `api-keys-restricted` |
| A03 Injection | Conforme |
| A04 Conception | Conforme |
| A05 Configuration | **3 contrôles console ouverts** |
| A06 Composants | Conforme (npm) |
| A07 Authentification | Conforme |
| A08 Intégrité | Conforme |
| A09 Journalisation | Conforme, réserve sur le volume client |
| A10 SSRF | Conforme après correctifs |

## Limites

Revue statique uniquement. Ne sont couverts ni les tests d'intrusion, ni la
configuration effective des consoles Firebase et Google Cloud, ni les règles
Firestore exécutées contre l'émulateur (scripts `npm run test:firestore`,
qui exigent l'émulateur Firebase), ni les dépendances Dart et système.

À rejouer à chaque évolution majeure du modèle d'autorisation, du parcours de
paiement ou des intégrations externes.

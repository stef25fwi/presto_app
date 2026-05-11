# 🛡️ AUDIT PRODUCTION COMPLET — Prest'o app

**Date** : 2026-05-08
**Branche** : `claude/production-audit-1R1BB`
**Projet Firebase** : `presto-app-74abe`
**Score actuel estimé** : **6.5 / 10** → Cible **10 / 10**

---

## 1. RÉSUMÉ EXÉCUTIF

L'application est globalement bien architecturée (sécurité Firestore solide, Cloud Functions avec App Check, messagerie server-only, résolution admin multi-source robuste). **Mais plusieurs éléments bloquent un déploiement prod 10/10**, notamment :

| # | Bloqueur | Sévérité | Plateforme |
|---|----------|----------|------------|
| 1 | `APPCHECK_SAFE_MODE=true` en prod | **CRITIQUE** | Backend |
| 2 | `firebase_options.dart` : Android/iOS utilisent `_webAppId` | **CRITIQUE** | Mobile |
| 3 | Aucun `google-services.json` ni `GoogleService-Info.plist` | **CRITIQUE** | Mobile |
| 4 | AdMob `ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy` (placeholder) | **CRITIQUE** | Mobile |
| 5 | CI déploie GitHub Pages mais pas Firebase Hosting / Functions / Rules | **HAUT** | DevOps |
| 6 | `_contactUser()` cassé dans `consult_offers_page.dart:3216` | **HAUT** | UI |
| 7 | `MARKETPLACE_RECAPTCHA_*_SITE_KEY` absentes du build CI | **HAUT** | Sécurité |
| 8 | Action `chatFirstMessage` manquante dans l'enum reCAPTCHA | **MOYEN** | Sécurité |
| 9 | Bundle iOS `presto_app` ≠ Android `fr.ilipresto.app` | **MOYEN** | Mobile |
| 10 | Aucun test CI (`flutter test`, `npm test`) | **MOYEN** | Qualité |

---

## 2. RECAPTCHA — CÂBLAGE & CLÉS

### 2.1 Trois systèmes de clés distincts (intentionnel)

| Usage | Variable `--dart-define` / env | Fichier |
|-------|--------------------------------|---------|
| **App Check Web** | `APPCHECK_RECAPTCHA_SITE_KEY` | `lib/config/app_check_state.dart:9` |
| **Marketplace Android** | `MARKETPLACE_RECAPTCHA_ANDROID_SITE_KEY` | `lib/services/marketplace_human_verification.dart:21` |
| **Marketplace iOS** | `MARKETPLACE_RECAPTCHA_IOS_SITE_KEY` | `lib/services/marketplace_human_verification.dart:25` |
| **Marketplace Web** | `APPCHECK_RECAPTCHA_SITE_KEY` | `lib/services/marketplace_human_verification.dart:29` |
| **Backend (vérif assessment)** | `RECAPTCHA_ENTERPRISE_SITE_KEY` | `functions/src/config/env.ts:22` |

✅ **Pas de clé hardcodée** dans le code.
✅ **Loader JS** : `web/index.html:74-128` (lazy-load Enterprise script).
✅ **Vérification serveur** : `functions/src/modules/marketplace/services/recaptcha.ts` — score min 0.5.

### 2.2 Failles à corriger

| # | Problème | Fichier | Action |
|---|----------|---------|--------|
| RC-1 | ✅ Résolu : clé Web unique | `.github/workflows/deploy.yml` | Utiliser uniquement `APPCHECK_RECAPTCHA_SITE_KEY` côté Web |
| RC-2 | Action `chatFirstMessage` absente de l'enum | `lib/services/marketplace_human_verification.dart:5-16` | Ajouter `chatFirstMessage` + câbler `chat_repository.dart` |
| RC-3 | Bypass silencieux si site key vide | `lib/main.dart:704-705` | Logger en `error` (Crashlytics) en prod, pas seulement `kDebugMode` |
| RC-4 | Backend bypass si `RECAPTCHA_ENTERPRISE_SITE_KEY` vide | `functions/src/modules/marketplace/services/recaptcha.ts:30` | Définir le secret en prod & vérifier `gcloud secrets list` |

---

## 3. APP CHECK

### 3.1 État actuel

- ✅ `lib/main.dart:710-723` : `webProvider: ReCaptchaEnterpriseProvider`, `androidProvider: PlayIntegrity`, `appleProvider: AppAttest`.
- ✅ `lib/config/app_check_state.dart` : drapeaux d'état partagés (`appCheckActivationSucceeded`, etc.).
- ✅ Retry App Check avant publication dans `lib/pages/publish_offer_page.dart:158-237`.
- ✅ Tous les callables Cloud Functions : `enforceAppCheck: ENFORCE_APP_CHECK`.

### 3.2 ❌ BLOQUEUR PROD — `APPCHECK_SAFE_MODE=true`

```
functions/.env.presto-app-74abe
ENFORCE_APP_CHECK=true
APPCHECK_SAFE_MODE=true     ← ANNULE l'enforcement
```

**Logique** (`functions/src/config/env.ts:14-19`) :
```ts
const appCheckRequested = process.env.ENFORCE_APP_CHECK === "true";
const appCheckSafeMode  = process.env.APPCHECK_SAFE_MODE !== "false";  // default true!
export const ENFORCE_APP_CHECK = appCheckRequested && !appCheckSafeMode;  // → FALSE
```

**Conséquence** : Aucun callable n'enforce App Check actuellement → tout client (script, curl) peut appeler les fonctions sans App Check token.

**Action** :
```bash
echo 'APPCHECK_SAFE_MODE=false' >> functions/.env.presto-app-74abe
firebase deploy --only functions
```

### 3.3 Autres failles App Check

| # | Problème | Fichier | Action |
|---|----------|---------|--------|
| AC-1 | Firestore rules : pas de `request.app != null` sur collections sensibles | `firestore.rules` | Ajouter sur `users`, `conversations`, `profiles`, `listings/write` |
| AC-2 | Storage rules : pas de check App Check | `storage.rules` | Ajouter `request.auth != null && request.app != null` sur uploads |
| AC-3 | Pas de debug token guard | `lib/main.dart:717-722` | OK : `kDebugMode ? debug : Real` mais vérifier qu'aucun debug token n'est commité dans Firebase Console |

---

## 4. CONFIG NATIVE FIREBASE — CRITIQUE

### 4.1 ❌ `lib/firebase_options.dart` cassé pour mobile

Lignes `54-72` : Android et iOS réutilisent `_webAppId = '1:151421230024:web:8b83d1d11084c5a02b3efd'`.
- **Conséquence Android** : `appId` web injecté → `Firebase.initializeApp` peut planter ou mélanger les apps Console.
- **Conséquence iOS** : même problème + Apple Push (APNs) non câblé sans GoogleService-Info.plist.

### 4.2 ❌ Fichiers natifs absents

- `android/app/google-services.json` → **MANQUANT**
- `ios/Runner/GoogleService-Info.plist` → **MANQUANT**

Pourtant `android/app/build.gradle.kts:7` applique `com.google.gms.google-services` qui nécessite ce fichier.

**Action** :
```bash
flutterfire configure --project=presto-app-74abe --platforms=android,ios,web
```

### 4.3 ❌ AdMob placeholders

- `android/app/src/main/AndroidManifest.xml:15-17` : `ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy`
- `ios/Runner/Info.plist:52-53` : idem

→ **AdMob ne marchera pas en prod**. Remplacer par les vrais App IDs depuis AdMob Console.

### 4.4 ⚠️ Cohérence bundle

- `android/app/build.gradle.kts:13` namespace : `fr.ilipresto.app` ✅
- `android/app/build.gradle.kts:28` applicationId : `fr.ilipresto.app` ✅
- `ios/Runner/Info.plist:16` `CFBundleName` : `presto_app` ⚠️ (devrait être `iliprestō` ou `Presto App`)
- `ios/Runner.xcodeproj/project.pbxproj` PRODUCT_BUNDLE_IDENTIFIER : à vérifier qu'il est bien `fr.ilipresto.app`

### 4.5 ⚠️ Signing release

`android/app/build.gradle.kts:55-65` : si `key.properties` absent → fallback vers debug keys avec un simple warning.
**Action** : la CI ne doit JAMAIS publier sans `key.properties` réel — ajouter un `error()` plutôt qu'un `warn()` quand `BUILD_VARIANT=release`.

---

## 5. PIPELINE CI/CD

### 5.1 Manques critiques (`.github/workflows/deploy.yml`)

| # | Manque | Sévérité |
|---|--------|----------|
| CI-1 | Aucun déploiement Firebase Hosting (la prod réelle) | **CRITIQUE** |
| CI-2 | Aucun déploiement Cloud Functions | **CRITIQUE** |
| CI-3 | Aucun déploiement `firestore.rules` ni `storage.rules` ni `firestore.indexes.json` | **CRITIQUE** |
| CI-4 | Aucun `flutter analyze` ni `flutter test` | **HAUT** |
| CI-5 | Aucun `npm test` côté functions | **HAUT** |
| CI-6 | Pas de build Android (`flutter build appbundle`) | **HAUT** |
| CI-7 | Pas de build iOS | **HAUT** |
| CI-8 | Secrets reCAPTCHA marketplace non passés au build web | **HAUT** |

### 5.2 Workflow CI/CD recommandé

```yaml
jobs:
  validate:
    - flutter pub get
    - flutter analyze --fatal-infos
    - flutter test
    - cd functions && npm ci && npm run build && npm test

  deploy-web:
    needs: validate
    - flutter build web --release \
        --dart-define=APPCHECK_RECAPTCHA_SITE_KEY=$APPCHECK_RECAPTCHA_SITE_KEY
    - firebase deploy --only hosting --project presto-app-74abe

  deploy-rules:
    needs: validate
    - firebase deploy --only firestore:rules,firestore:indexes,storage --project presto-app-74abe

  deploy-functions:
    needs: validate
    - firebase deploy --only functions --project presto-app-74abe
```

---

## 6. PAGE ADMINISTRATEUR

### 6.1 Chargement — ✅ ROBUSTE

`lib/pages/admin_space_page.dart:1885-2000` + `lib/services/admin_access_resolver.dart` (879 lignes) :

- **3 sources de vérité** : custom claims (`<1h`), document `users/{uid}`, callable serveur `getMyAdminAccessStatus`.
- **Mitigation stale-claims** (`admin_access_resolver.dart:192-256`) : refresh token forcé et message « Reconnecte-toi ».
- **Fallback HTTP direct** (`admin_access_resolver.dart:481-599`) : contourne les bugs SDK callable v2 sur Flutter Web.
- **Gestion timeouts** : 2s auth restore, 5s server doc, 15s callable.

### 6.2 Failles mineures

| # | Problème | Fichier | Action |
|---|----------|---------|--------|
| AD-1 | `_AdminChip` AppBar : `onTap: null` | `lib/pages/admin_space_page.dart:2601` | Soit retirer le chip soit ajouter une action |
| AD-2 | Diagnostics Firebase Deploy purement informatifs | `lib/pages/admin_space_page.dart:55-149` | OK pour debug, mais retirer en prod release? |
| AD-3 | Dashboard : metrics affichés mais pas alimentés | `lib/pages/admin_space_page.dart:151-236` | Câbler les vraies stats Analytics ou supprimer |

### 6.3 Câblage callables

- ✅ `getMyAdminAccessStatus` exporté `functions/src/index.ts:19`
- ✅ `adminGetMicroIaConfig` / `adminSetMicroIaConfig` exportés `functions/src/index.ts:25-26`
- ✅ `adminGetUserStats` exporté

---

## 7. MESSAGERIE

### 7.1 Architecture — ✅ EXCELLENTE

- **Server-only writes** : `firestore.rules:415-456` interdit toute écriture client sur `conversations` et sub-collection `messages`.
- **Callables** : `ensureOfferConversation`, `sendConversationMessage`, `markConversationRead`, `archiveConversation`, `blockConversation`, `deleteMessage` (`functions/src/modules/messaging/callables.ts`).
- **Trigger** : `onConversationSubMessageCreated` → notifications in-app + push FCM + email cooldown 15 min (`functions/src/modules/messaging/triggers.ts:72-171`).
- **Rate limit** : 6 messages / 10s (`callables.ts:23-25`), dedup 15s.
- **Pagination** : 50 messages, anchor doc anti-gap (`conversation_thread_page.dart:385-450`).
- **Cleanup** : `dispose()` annule tous les listeners (`conversation_thread_page.dart:106-108`).

### 7.2 Boutons & câblage

| Bouton | Statut | Référence |
|--------|--------|-----------|
| Envoyer message | ✅ | `conversation_thread_page.dart:453-508` |
| Long press → supprimer | ✅ | `:921-979` |
| Archive / Désarchive | ✅ | `:514-524` |
| Block / Unblock | ✅ | `:527-537` |
| Supprimer conversation | ✅ | `:566-571` (avec confirm) |
| Mark as read | ✅ auto à l'ouverture | `:327` |

### 7.3 Manques fonctionnels

| # | Manque | Sévérité | Action |
|---|--------|----------|--------|
| MSG-1 | Pas d'indicateur de saisie (typing) | MOYEN | Optionnel mais attendu |
| MSG-2 | Pas de signalement message | **MOYEN** | Légal/modération |
| MSG-3 | Pas d'avatars dans le thread | BAS | Polish UX |
| MSG-4 | `messages_page_v2.dart` : wrapper de 22 lignes | TRIVIAL | Fusionner ou retirer |

### 7.4 FCM

- ✅ Background handler avec `@pragma('vm:entry-point')` (`notification_service.dart:14-20`)
- ✅ Foreground handler + token register sur `authStateChanges` (`:130-138`)
- ✅ `onMessageOpenedApp` route vers `/messages/{conversationId}`
- ✅ `firebase-messaging-sw.js` présent dans `web/`
- ⚠️ Vérifier que la VAPID key web est bien configurée dans Firebase Console

---

## 8. PAGES & BOUTONS

### 8.1 Bug critique confirmé

**`lib/pages/consult_offers_page.dart:3216-3230`** — `_contactUser` :
```dart
Future<void> _contactUser(BuildContext context) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountPage()));
    return;
  }
  if (!context.mounted) return;
  // ❌ AUCUN code après — la fonction ne fait rien quand l'utilisateur est connecté
}
```

**Action** : Câbler `ensureOfferConversation` callable + ouvrir `MessagesPageV2(initialConversationId: ...)`.

### 8.2 Inventaire pages

17 pages dans `lib/pages/` — toutes routables, aucune orpheline.

### 8.3 Routes nommées (manque de couverture)

`lib/main.dart:937-941` :
```dart
routes: {
  '/publish': PublishOfferPage,
  '/messages': MessagesPageV2,
  '/messages-2': MessagesPageV2,
  '/account': AccountPage,
  '/page-catalog': PageCaptureCatalogPage,
}
```

❌ **Routes manquantes** : `/admin`, `/offer/:id`, `/offers/consult`, `/profile/:uid`, `/toolbox/*`. Le deep linking via `_onGenerateRoute` (`:879-921`) couvre offers et messages mais pas admin.

### 8.4 Accessibilité

- ⚠️ ~70 `IconButton` sans `tooltip` ni `Semantics`
- 1 seul `Tooltip` dans tout le code (`publish_offer_page.dart:4038`)
- Action : audit a11y systémique avant store submission

---

## 9. FIRESTORE & STORAGE RULES

### 9.1 ✅ Points forts

- Catch-all deny `firestore.rules:488-490`
- `isAdmin()` multi-couches avec TTL claims `firestore.rules:14-24`
- `admins/{uid}`, `_rate_limits/{}`, `push_tokens/{}`, `email_events/{}` : `if false` (server-only)
- Storage : pas de wildcard ouvert, taille max enforced

### 9.2 ⚠️ Failles à corriger

| # | Règle | Fichier:Ligne | Action |
|---|-------|---------------|--------|
| FR-1 | `categories` et `cities` : `read: if true` | `firestore.rules:256, 260` | OK pour reference data, documenter |
| FR-2 | Pas de `request.app != null` global | `firestore.rules` | Ajouter helper `function isAppCheckOk() { return request.app != null; }` puis utiliser sur collections sensibles |
| FR-3 | Storage : pas de check App Check sur uploads | `storage.rules:73-116` | Ajouter `request.app != null` |

### 9.3 Indexes (`firestore.indexes.json`)

✅ 27+ indexes listings, conversations, notifications, email_jobs, offers + TTL `_rate_limits.expiresAt`. Couvre toutes les requêtes connues.

---

## 10. CLOUD FUNCTIONS

### 10.1 ✅ Points forts

- Tous les callables : `region: PROJECT_REGION`, `enforceAppCheck: ENFORCE_APP_CHECK`
- Helpers `requireAuthUid()`, `requireAnyRole()`
- Validation entrées : `asNonEmptyString`, `normalizeString`, limites taille
- Rate limiting : `canProceedRateLimited`, `rateLimitOrThrow`
- Secrets : `defineSecret(EMAIL_PROVIDER_API_KEY, BREVO_API_KEY, OPENAI_API_KEY, GOOGLE_PLACES_API_KEY)`

### 10.2 ⚠️ À corriger

| # | Problème | Fichier | Action |
|---|----------|---------|--------|
| CF-1 | `APPCHECK_SAFE_MODE=true` désactive enforcement (cf §3.2) | `functions/.env.presto-app-74abe` | Passer à `false` |
| CF-2 | `EMAIL_FROM` hardcodé à un Gmail perso | `functions/src/config/env.ts:11` | Migrer vers `noreply@ilipresto.fr` ou domaine validé Brevo |
| CF-3 | `index.js` legacy mélangé à `src/` TypeScript | `functions/index.js` (1327+ lignes) | Migrer entièrement vers TypeScript ou documenter le partage |
| CF-4 | `console.log` non structurés dans `index.js:97` | `functions/index.js` | Utiliser `logger.info` (déjà dispo) |

---

## 11. WEB / HOSTING

### 11.1 ✅ Headers sécurité (`firebase.json`)

```
X-Robots-Tag, X-Content-Type-Options, X-Frame-Options, Referrer-Policy,
Permissions-Policy: camera=(), microphone=(self), geolocation=()
Cache-Control immutable sur assets, no-cache sur index.html
```

✅ Bon niveau de hardening.

### 11.2 ⚠️ Manques

| # | Manque | Action |
|---|--------|--------|
| W-1 | Pas de **Content-Security-Policy** | Ajouter CSP stricte (Firebase + reCAPTCHA + Google APIs) |
| W-2 | Pas de **Strict-Transport-Security** | Ajouter `max-age=63072000; includeSubDomains; preload` |
| W-3 | `X-Robots-Tag: noindex` ⚠️ | Si la prod doit être indexée, retirer en prod (commenter pour preview seulement) |
| W-4 | Redirect `ilipresto.fr` au build mais déploiement CI sur GitHub Pages | Trancher : Firebase Hosting OU GitHub Pages, pas les deux |

---

## 12. CHECKLIST FINALE — ROADMAP 10/10

### 🔴 Critique (à faire avant prod)

- [ ] **Backend** : `APPCHECK_SAFE_MODE=false` + redéployer `firebase deploy --only functions`
- [ ] **Mobile** : `flutterfire configure --project=presto-app-74abe --platforms=android,ios,web`
- [ ] **Mobile** : commit `google-services.json` + `GoogleService-Info.plist` (ou inject via CI)
- [ ] **Mobile** : remplacer AdMob `ca-app-pub-xxx~yyy` par les vrais IDs (Android+iOS)
- [ ] **CI** : ajouter steps `firebase deploy --only hosting,functions,firestore,storage`
- [ ] **CI** : ajouter `flutter analyze`, `flutter test`, `npm test` avant deploy
- [ ] **UI** : compléter `_contactUser` dans `consult_offers_page.dart:3216` → ouvrir conversation

### 🟠 Haut (avant scaling)

- [ ] CI : passer `MARKETPLACE_RECAPTCHA_*_SITE_KEY` dans le build web
- [ ] Ajouter action `chatFirstMessage` à `MarketplaceHumanVerificationAction`
- [ ] `firestore.rules` : ajouter `request.app != null` sur collections sensibles
- [ ] `storage.rules` : ajouter App Check enforcement
- [ ] Ajouter CSP + HSTS dans `firebase.json` headers
- [ ] `EMAIL_FROM` : remplacer Gmail perso par domaine validé
- [ ] `key.properties` absent → `error()` au lieu de `warn()` en release

### 🟡 Moyen (qualité)

- [ ] Page admin : retirer `onTap: null` (`admin_space_page.dart:2601`)
- [ ] Messagerie : ajouter signalement de message
- [ ] Ajouter routes nommées pour `/admin`, `/offers/:id`, `/profile/:uid`
- [ ] Audit a11y systémique : tooltips et `Semantics` sur IconButtons
- [ ] Migrer `functions/index.js` legacy vers TypeScript
- [ ] Décider : Firebase Hosting OU GitHub Pages, pas les deux

### 🟢 Bas (polish)

- [ ] Messagerie : avatars participants dans le thread
- [ ] Messagerie : indicateur de saisie (typing)
- [ ] Retirer wrappers triviaux : `messages_page_v2.dart`, `entrepreneur_toolbox_page.dart`
- [ ] Documenter intentionnalité du `read: if true` sur `categories`/`cities`
- [ ] Migrer `console.log` legacy vers logger structuré
- [ ] Nettoyage : nombreux fichiers `.md` redondants à la racine (PREMIUM_AI_BUTTON*, NOTIFICATIONS_*, GOOGLE_SIGNIN_*)

---

## 13. SCORING DÉTAILLÉ

| Domaine | Note | Justification |
|---------|------|--------------|
| Architecture | 9/10 | Séparation claire, server-only writes, multi-source admin |
| Sécurité Firestore | 8/10 | Solide, manque App Check au niveau rules |
| Sécurité Functions | 6/10 | Solide *en théorie* mais `APPCHECK_SAFE_MODE` annule tout |
| Sécurité reCAPTCHA | 7/10 | 3 systèmes cohérents, mais CI incomplète |
| Config Firebase Mobile | 3/10 | Fichiers natifs absents, fallback web utilisé |
| Config Firebase Web | 9/10 | Robuste, App Check correct, headers OK |
| Messagerie | 9/10 | Production-grade, manque signalement |
| Admin | 9/10 | Excellent câblage, mitigation stale-claims |
| Pages & boutons | 7/10 | Globalement bien câblé, 1 bug critique `_contactUser` |
| CI/CD | 3/10 | Ne déploie que GitHub Pages, pas Firebase |
| Accessibilité | 4/10 | Manque labels et tooltips |
| Tests | 2/10 | Aucune exécution dans CI |
| **GLOBAL** | **6.5/10** | Cible **10/10** atteignable en ~2-3 jours de travail |

---

## 14. COMMANDES PRÊTES À EXÉCUTER

```bash
# 1) Régénérer config Firebase native
flutterfire configure --project=presto-app-74abe --platforms=android,ios,web

# 2) Désactiver le safe-mode App Check
sed -i 's/APPCHECK_SAFE_MODE=true/APPCHECK_SAFE_MODE=false/' functions/.env.presto-app-74abe

# 3) Vérifier les secrets Cloud Functions
gcloud secrets list --project=presto-app-74abe
firebase functions:secrets:access RECAPTCHA_ENTERPRISE_SITE_KEY --project=presto-app-74abe

# 4) Build & deploy complet
cd functions && npm ci && npm run build && cd ..
firebase deploy --project=presto-app-74abe \
  --only firestore:rules,firestore:indexes,storage,functions,hosting

# 5) Build Android release
flutter build appbundle --release \
  --dart-define=APPCHECK_RECAPTCHA_SITE_KEY=$APPCHECK_KEY \
  --dart-define=MARKETPLACE_RECAPTCHA_ANDROID_SITE_KEY=$MKTP_ANDROID

# 6) Build iOS release
flutter build ipa --release \
  --dart-define=APPCHECK_RECAPTCHA_SITE_KEY=$APPCHECK_KEY \
  --dart-define=MARKETPLACE_RECAPTCHA_IOS_SITE_KEY=$MKTP_IOS
```

---

**Auditeur** : Claude Code
**Référence agents** : 6 sous-agents parallèles (reCAPTCHA, AppCheck, Admin, Messaging, Pages/Buttons, Rules/Functions)

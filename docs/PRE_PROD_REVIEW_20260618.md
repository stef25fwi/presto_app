# Revue pré-production APK — Presto (Flutter + Firebase)

Date : 2026-06-18 · Branche : `claude/apk-pre-prod-review-1j53i0`

Verdict : **base de code mûre et bien tenue**. Aucune faille de sécurité
critique exploitable, hygiène mémoire/stabilité au-dessus de la moyenne,
Crashlytics correctement câblé. Quelques bloquants à lever côté
configuration Cloud + un bug fonctionnel (corrigé ici).

---

## ✅ Correctifs appliqués sur cette branche

| Axe | Correctif | Fichier |
|-----|-----------|---------|
| Fonctionnel/Perf | Recherche de villes : chargement dynamique des **106** fichiers `cities_*.json` (au lieu de 15 codés en dur) via `AssetManifest` | `lib/services/city_search.dart` |
| Sécurité | `print()` non gardé dans `build()` (fuite d'URL photo user à chaque frame) supprimé | `lib/pages/account_page.dart` |
| Sécurité | `android:allowBackup="false"` + `fullBackupContent="false"` | `android/app/src/main/AndroidManifest.xml` |
| Perf/Taille | Suppression de 3 PNG inutilisés (~5,7 Mo morts) : `chrono_1min.png`, `info.png`, `cadre.png` | `assets/images/` |
| Perf/Mémoire | `cacheWidth` sur les vignettes réseau de liste (décodage borné) | `offer_network_image*.dart`, `consult_offers_page.dart`, `user_offers_section.dart` |

## ⏸️ Volontairement NON appliqués (risque de régression — à décider)

- **Auth sur `preVerifySiret`** : `ProSiretSignupSection` est affiché aux
  utilisateurs **déconnectés** (`signed_out_account_fallback.dart:377`).
  Exiger `request.auth` casserait la pré-inscription pro. Protégé par
  App Check + rate-limit. → garder tel quel, ou re-désigner le flux.
- **Canonicaliser `isPublicOffer()`** (`firestore.rules:276`) : la collection
  `offers` est `LEGACY READ-ONLY` ; durcir le critère de visibilité risque
  de masquer des annonces existantes en prod. → nécessite un audit des
  données avant de restreindre.
- **Limiter les conversations utilisateur** (`conversations_list_page.dart`) :
  la requête `where(participantIds arrayContains uid)` n'a **pas** d'`orderBy` ;
  ajouter `.limit()` sans `orderBy('updatedAt', desc)` renverrait un sous-ensemble
  arbitraire, et l'`orderBy` exige un **index composite** à déployer. → à faire
  avec pagination + index, hors de cette passe.

## 🚦 Bloquants AVANT publication (hors code — à faire par toi)

1. **`flutter analyze`** : non lançable dans l'environnement de revue
   (flutter/dart absents). À exécuter en CI/local et corriger les erreurs.
2. **Restreindre les clés API** côté Google Cloud Console : clé Android Firebase
   par package `fr.ilipresto.app` + SHA-1 de la clé de signature release ;
   clé reCAPTCHA Enterprise par domaine ; limiter les APIs autorisées.
3. **App Check en mode "Enforce"** (pas "Monitor") pour Firestore, Storage et
   Functions ; providers Play Integrity / App Attest / reCAPTCHA enregistrés
   avec les bons fingerprints.
4. **Symbolication Android** : confirmer l'upload des mappings ProGuard / symboles
   NDK au build release (plugin Crashlytics Gradle déjà appliqué) sinon les
   stack traces de crash seront illisibles.

## 📌 Recommandations post-prod (non bloquantes)

- Dédupliquer les datasets villes (`cities/` 3,3 Mo + `cities_compact.json`
  3,7 Mo) → ~7 Mo économisés dans l'APK.
- Publier en **App Bundle (.aab)** (split ABI auto) plutôt qu'APK universel.
- N+1 favoris (`user_offers_section.dart:162`) → batch `whereIn`/`Future.wait`.
- Sortir le `FutureBuilder` notifications du `build()` (`home_page.dart:1135`).
- Durcir les casts `as` directs sur données Firestore dans `_importData`
  (`toolbox_je_me_lance_page.dart:368`).
- Extraire les `build()` monolithiques (579 / 972 lignes) en sous-widgets.
- Migrer les 226 `withOpacity()` dépréciés vers `.withValues()`.

## 👍 Points solides constatés

- Règles Firestore/Storage restrictives, `deny-all` final, anti-escalade de
  privilèges vérifié, upload validé (type+taille, SVG bloqué).
- Aucun vrai secret hardcodé/versionné ; secrets serveur via Secret Manager.
- Signature release qui refuse les clés debug ; R8/minify/shrink activés.
- Crashlytics complet (`runZonedGuarded` + `FlutterError.onError` +
  `PlatformDispatcher.onError`, désactivé en debug).
- `dispose`/`cancel` complets, gardes `mounted` systématiques après `await`.
</content>
</invoke>

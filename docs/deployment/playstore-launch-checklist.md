# Checklist de soumission Play Store — `fr.ilipresto.app`

État constaté le 1er août 2026 sur `main` (commit `e5ddc88`).
Complète `docs/deployment/mobile-release.md` (mécanique de build) et
`docs/deployment/release-checklist.md` (qualité de release) : ce document ne
liste que ce qui reste **à finir avant de pouvoir proposer l'application au
Play Store**.

Légende : 🔴 bloquant · 🟠 à faire avant publication en production · 🟢 fait.

---

## 1. Chaîne de build et signature

| # | Point | État |
|---|---|---|
| 1.1 | 🟠 **Un premier AAB release a été produit avec succès** (`release_android.yml`, run du 2026-07-30, commit `33b6cc2`, `upload` décoché comme prévu). Le build release active `isMinifyEnabled` + `isShrinkResources` (`android/app/build.gradle.kts:69`) avec un `proguard-rules.pro` minimal : les régressions R8 (réflexion Firebase/UMP/reCAPTCHA) ne se voient qu'en release — reste à tester cet AAB sur appareil réel (1.6) avant tout second passage. | fait (à valider sur appareil) |
| 1.2 | 🔴 **Secret `PLAY_SERVICE_ACCOUNT_JSON` absent** de l'environnement `recaptcha` (documenté « à créer »). Le workflow le contrôle désormais avant l'envoi (étape *Check Play Console credentials*) et échoue avec un message explicite plutôt qu'au fond de l'action d'upload — mais **le secret reste à créer**. | à faire |
| 1.3 | 🔴 **Premier dépôt manuel obligatoire** : l'API Play refuse tout envoi tant qu'aucune version n'existe pour le package. Récupérer l'artefact `.aab` et le déposer à la main sur la piste interne. | à faire |
| 1.4 | 🟠 Créer la fiche Play Console avec le package `fr.ilipresto.app` — **irréversible**, il doit correspondre exactement à `applicationId`. | à faire |
| 1.5 | 🟢 Keystore d'upload et secrets `KEYSTORE_B64` / `KEYSTORE_PASSWORD` / `KEY_PASSWORD` / `KEY_ALIAS` déjà configurés. | fait |
| 1.6 | 🟠 Tester l'AAB via un lien de partage interne / `bundletool` sur un appareil réel avant l'envoi — c'est le seul moyen de valider le build minifié. | à faire |

## 2. Empreintes de signature et services Google (risque de casse en production)

| # | Point | État |
|---|---|---|
| 2.1 | 🔴 **`google-services.json` ne contient qu'un seul SHA-1 pour `fr.ilipresto.app` et aucun SHA-256.** Avec Play App Signing, Google re-signe l'AAB avec une clé différente de la clé d'upload. Tant que les SHA-1 **et** SHA-256 de la *clé de signature de l'application* (Play Console → *Intégrité de l'application*) ne sont pas ajoutés dans Firebase, **Google Sign-In et App Check échoueront pour tous les utilisateurs du Play Store** alors qu'ils fonctionnent en local. Régénérer et recommiter `google-services.json` après l'ajout. | à faire |
| 2.2 | 🔴 **App Check / Play Integrity** : en release le code force `AndroidProvider.playIntegrity` (`lib/services/app_check_bootstrap.dart:169`). Lier l'API Play Integrity au projet Firebase et à l'application Play Console, sinon aucun jeton App Check n'est délivré. | à faire |
| 2.3 | 🟠 Enforcement App Check Firestore / Storage / Functions : les trois contrôles sont `pending` dans `quality/security-controls.json`. Décider de l'ordre (release mobile d'abord, enforcement ensuite) pour ne pas verrouiller les clients déjà installés. | à décider |
| 2.4 | 🟠 Restriction des clés API Android (`api-keys-restricted` `pending`) : restreindre la clé Android au package + empreinte de la clé Play. | à faire |

## 3. Contenu de l'application (points de rejet fréquents)

| # | Point | État |
|---|---|---|
| 3.1 | 🟢 **IDs AdMob corrigés.** Les quatre constantes portant des blocs de démonstration Google (`androidNativeId`, `androidInterstitialId`, `iosNativeId`, `iosInterstitialId`) n'étaient référencées nulle part : supprimées. Le défaut symétrique a été corrigé au passage — les blocs bannière réels étaient chargés y compris en debug, ce qui produit du trafic invalide sur le compte AdMob. `AdConfig.bannerIdFor` sert désormais les blocs de démonstration hors release et les blocs réels en release, sous test (`test/widgets/ad_config_test.dart`). | fait |
| 3.2 | 🟠 **Routes publiques ajoutées** : `/confidentialite`, `/cgu` et `/mentions-legales` sont enregistrées, atteignables par URL directe (`_onGenerateInitialRoutes`) et exclues de la page de préouverture (`PublicLandingConfigService.bypassPaths`). **Reste à vérifier en production après déploiement web.** | code fait |
| 3.3 | 🟠 **Page publique `/suppression-compte` ajoutée** (`lib/pages/legal/account_deletion_info_page.dart`) : procédure in-app, demande par e-mail hors application, données supprimées et durées de conservation. **Reste à vérifier en production après déploiement web.** | code fait |
| 3.4 | 🟠 **Compte de démonstration pour la revue.** L'application est intégralement derrière authentification : fournir identifiants de test + instructions dans *Accès à l'application*, sinon rejet quasi certain. | à faire |
| 3.5 | 🟢 Le mode pré-lancement ne concerne **pas** le mobile : le rendu de `PublicPrelaunchPage` est conditionné par `kIsWeb` (`lib/app/presto_app_chrome.dart:46`). Le reviewer voit bien l'application complète. À revérifier si ce garde-fou change. | vérifié |
| 3.6 | 🟢 Contenu généré par les utilisateurs : signalement d'annonce et de conversation, blocage d'utilisateur et outils de modération admin présents. | fait |
| 3.7 | 🟠 Documenter la boucle de modération (délai de traitement, contact) : Play demande un dispositif *effectif*, pas seulement un bouton. | à faire |

## 4. Déclarations Play Console

Réponses préparées à partir de l'inventaire du code dans
`docs/deployment/playstore-declarations.md` — à valider et saisir dans la
console, la déclaration restant un acte de l'éditeur.

| # | Point | État |
|---|---|---|
| 4.1 | 🟠 **Formulaire Sécurité des données** — tableau de réponses prêt dans `playstore-declarations.md`, à saisir. À déclarer d'après le code : identité et coordonnées (compte, téléphone), messages, photos et vidéos (`image_picker`), enregistrements audio (`record`), localisation approximative (ville / code postal saisis), **identifiant publicitaire** (`google_mobile_ads` fusionne la permission `AD_ID`), diagnostics et performances (Crashlytics, Performance), analytics (Firebase Analytics), contenus IA (`firebase_ai`). | à faire |
| 4.2 | 🟠 **Questionnaire de classification du contenu** (IARC) — réponses préparées dans `playstore-declarations.md`, public cible et âge à trancher. | à faire |
| 4.3 | 🟠 **Déclaration « Contient des annonces » = oui** (AdMob actif, App ID déclaré au manifeste). | à faire |
| 4.4 | 🟠 **Justification des permissions sensibles** (rédigée dans `playstore-declarations.md`) : `RECORD_AUDIO` et `CAMERA` (`android/app/src/main/AndroidManifest.xml`) exigent une divulgation proéminente dans l'app et une explication dans la fiche. `POST_NOTIFICATIONS` est bien demandé au runtime (`lib/services/notification_service.dart:297`). | à faire |
| 4.5 | 🟠 **Test fermé préalable** : un compte développeur personnel créé après novembre 2023 doit réunir 12 testeurs pendant 14 jours continus avant d'accéder à la production. À lancer très tôt — c'est le délai le plus long de la liste. | à planifier |
| 4.6 | 🟠 Fiche « Application et services financiers », déclaration santé, publicité ciblée : à répondre même si non applicable. | à faire |

## 5. Ressources graphiques et fiche

| # | Point | État |
|---|---|---|
| 5.1 | 🟠 **Icône 512×512 générée** (`marketing/play-store/graphics/icon-512.png`, via `tools/android/generate_adaptive_icon.py`). Restent à produire : image de mise en avant 1024×500, au moins 4 captures téléphone (min. 320 px de côté), captures tablette 7"/10" si la tablette est déclarée, vidéo optionnelle. Les captures doivent venir d'un build réel. | partiel |
| 5.2 | 🟠 **Textes rédigés** dans `marketing/play-store/listing-fr.md`, alignés sur le positionnement de `web/index.html`. Les limites de caractères sont vérifiées par `node tools/quality/check_play_listing.mjs`. **À relire avant saisie.** | brouillon prêt |
| 5.3 | 🟢 **Icône adaptative ajoutée** : `mipmap-anydpi-v26/ic_launcher.xml` avec calques `foreground`, `background` (blanc) et `monochrome` pour les icônes thématiques Android 13+, générés aux cinq densités par `tools/android/generate_adaptive_icon.py`. | fait |
| 5.4 | 🟠 Traductions de la fiche si d'autres marchés que la France sont visés. | à décider |

## 6. Qualité et validations techniques restantes

| # | Point | État |
|---|---|---|
| 6.1 | 🔴 **CI rouge sur `main`, toujours active au 14/08** : le workflow *AI production smoke* échoue en continu (30/30 dernières exécutions depuis le 10/08, dernier run `31820005895`, commit `09bae36`) à l'étape « Verify production Functions, Auth, App Check, fallback and logs ». Cause identifiée : `Permission 'iam.serviceAccounts.signBlob' denied` — il manque le rôle IAM `roles/iam.serviceAccountTokenCreator` sur le compte de service CI dans le projet `presto-app-74abe`. Voir `docs/audit/audit-complet-2026-08-14.md` §1. À corriger avant de figer une release candidate — c'est exactement le périmètre Auth/App Check qui conditionne le point 2.1. | à corriger (cause identifiée) |
| 6.2 | 🔴 `quality/mobile_readiness.json` : 7 contrôles sur 8 en `pending` — build Android, build iOS, permissions, notifications push sur appareil réel, deep links, métadonnées store, signature. Chacun demande une preuve versionnée. | à faire |
| 6.3 | 🟠 **Deep links non validés** : aucun `assetlinks.json` dans le dépôt, aucun `intent-filter` de liens web au manifeste. Si les notifications ou les partages doivent ouvrir l'application, ajouter les App Links et publier `/.well-known/assetlinks.json` avec l'empreinte SHA-256 de la clé Play. | à faire |
| 6.4 | 🟠 **Notifications push à valider sur appareil réel** (canal `ilipresto_messages`, icône `ic_notification`, réception en arrière-plan et application tuée). | à faire |
| 6.5 | 🟠 **Pas d'environnement Firebase de staging** : une piste interne Play écrit dans les données de production (`presto-app-74abe`). Encadrer les jeux d'essai ou prévoir un nettoyage. | à arbitrer |
| 6.6 | 🟠 `quality/accessibility_ux_readiness.json` : 8 contrôles `pending` (contraste, focus, lecteur d'écran, cibles tactiles, mise à l'échelle du texte). Pas bloquant pour Play, mais visible dans le pre-launch report Play Console. | à faire |
| 6.7 | 🟠 Lire le **pre-launch report** Play Console après le premier dépôt (crashs, ANR, accessibilité, sécurité) et traiter les alertes avant la promotion en production. | à faire |
| 6.8 | 🟢 `versionCode` monotone assuré par `github.run_number`, `versionName` lu depuis `pubspec.yaml` (`1.0.1`). | fait |
| 6.9 | 🟢 Reste de la CI verte sur `main` (analyze, tests, couverture, CodeQL, garde-fous production). | fait |

## 7. Points à surveiller après le lancement

- **Play Billing.** L'application est en mode *free beta* et le checkout Stripe est
  neutralisé hors mode commercial (`lib/features/subscriptions/subscription_action_placeholders.dart:78`).
  Le jour où le mode commercial est activé, un abonnement souscrit **depuis
  l'application Android** via Stripe enfreint la règle Play Billing dès qu'il
  donne accès à des fonctionnalités numériques. Prévoir soit Play Billing, soit
  un parcours d'abonnement strictement web, gardé par `kIsWeb`.
- **Cible d'API.** `targetSdk` suit `flutter.targetSdkVersion` : revérifier à
  chaque montée de niveau exigée par Play (échéance annuelle).
- **Rotation** du compte de service Play (clé JSON, non fédérée).
- Commentaire obsolète : `android/app/build.gradle.kts:29` annonce « minSdk 23 »
  alors que la valeur utilisée est `flutter.minSdkVersion`. Cosmétique.

---

## Ordre d'exécution conseillé

1. Corriger la CI rouge (6.1).
2. Déployer le web pour que les pages légales et la page de suppression de
   compte répondent réellement en production, puis vérifier les quatre URL
   (3.2, 3.3) — les routes existent, la vérification reste à faire.
3. Créer la fiche Play Console (1.4), récupérer les empreintes de la clé de
   signature Play et mettre à jour Firebase (2.1, 2.2).
4. Produire un premier AAB sans upload, le tester sur appareil (1.1, 1.6).
5. Dépôt manuel sur la piste interne, lecture du pre-launch report (1.3, 6.7).
6. Remplir Sécurité des données, classification, annonces, permissions
   (4.1 → 4.4) et monter les visuels et textes (5.x).
7. Lancer le test fermé 12 testeurs / 14 jours (4.5) — à démarrer dès que la
   piste interne est saine.
8. Promotion en production une fois `quality/mobile_readiness.json` et
   `quality/production_go_live_readiness.json` documentés.

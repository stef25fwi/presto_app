# Audit qualité de code — préparation Play Store — 2026-08-15

Portée : la qualité du code au regard d'une publication Android. Complète
l'[audit complet du 14/08](audit-complet-2026-08-14.md), centré sur la CI et le
backend, et la [checklist Play Store](../deployment/playstore-launch-checklist.md),
centrée sur le processus de soumission. Ce document ne traite que ce qui relève
du code et de la configuration de build.

## Résumé exécutif

| # | Constat | Sévérité |
|---|---|---|
| 1 | **306 appels `print`/`debugPrint`** dans `lib/`, dont 17 fichiers seulement gardés par `kDebugMode`. Les plus fournis manipulent des données personnelles : notifications (29), compte (21), authentification sociale (18) | **P0 — fuite de données en journal** |
| 2 | `use_build_context_synchronously` est **ignoré globalement** dans `analysis_options.yaml`. C'est une classe de bugs de plantage, pas une préférence de style | **P1** |
| 3 | ProGuard : 29 lignes, 10 règles `-keep`. Les classes du SDK Firebase Android ne sont pas explicitement préservées, alors que R8 est actif en release | **P1 — risque de régression en release seulement** |
| 4 | Aucun `assetlinks.json`, aucun `intent-filter` de lien web : les App Links ne fonctionneront pas | P2 |
| 5 | Configuration de build Android : minification, réduction de ressources, signature et versionnage corrects | ✅ sain |
| 6 | Permissions Android minimales et justifiées : 5 permissions, toutes rattachées à une fonctionnalité réelle | ✅ sain |
| 7 | 471 fichiers de test Flutter, 308/308 tests Functions, 0 vulnérabilité haute | ✅ sain |

## 1. Journalisation en production (P0)

`lib/` contient **306 appels** à `print` ou `debugPrint`. Seuls 17 fichiers
utilisent une garde `if (kDebugMode)`. Or `analysis_options.yaml` désactive
explicitement la règle qui les détecterait :

```yaml
linter:
  rules:
    avoid_print: false
```

En build release Android, `print` et `debugPrint` écrivent dans logcat. Tout
autre application disposant de la permission de lecture des journaux, et toute
personne branchant l'appareil, peut les lire.

Les fichiers les plus concernés sont précisément ceux qui manipulent des
données personnelles :

| Fichier | Occurrences |
|---|---:|
| `lib/services/notification_service.dart` | 29 |
| `lib/pages/account_page.dart` | 21 |
| `lib/services/account_social_auth_actions.dart` | 18 |
| `lib/pages/publish_offer_page.dart` | 17 |
| `lib/services/google_auth_service.dart` | 16 |
| `lib/pages/messages/conversation_thread_page.dart` | 15 |

Le risque n'est pas théorique pour une soumission Play : la politique sur les
données utilisateur interdit la divulgation de données personnelles à des tiers
non autorisés, et un journal lisible en est un vecteur. Le backend applique
d'ailleurs déjà cette discipline — le smoke test de production vérifie qu'aucune
clé sensible n'apparaît dans les journaux Functions
(`forbiddenLogKeys`, `microia_production_smoke_test.mjs`). Le client n'a pas
d'équivalent.

**Correctif recommandé** : router toute la journalisation client par un
utilitaire unique qui n'émet rien hors `kDebugMode`, puis réactiver
`avoid_print` pour empêcher la réintroduction. Le volume rend la reprise
mécanique mais elle n'est pas risquée.

## 2. Diagnostics ignorés globalement (P1)

```yaml
analyzer:
  errors:
    deprecated_member_use: ignore
    use_build_context_synchronously: ignore
    strict_top_level_inference: ignore
```

Les trois ne se valent pas.

`use_build_context_synchronously` signale l'usage d'un `BuildContext` après un
`await`, alors que le widget peut avoir été démonté entre-temps. C'est une
cause classique de plantage à l'exécution, pas une question de style — et les
plantages remontent directement dans le pre-launch report de la Play Console,
puis dans la note de l'application.

L'ignorer globalement supprime le seul garde-fou automatique contre cette
famille de bugs, dans une application où les parcours asynchrones sont
nombreux : publication d'annonce, messagerie, authentification.

`deprecated_member_use` est défendable pendant une migration de SDK, à
condition d'être borné dans le temps. `strict_top_level_inference` est une
règle récente et son coût de mise en conformité peut légitimement être différé.

**Correctif recommandé** : réactiver `use_build_context_synchronously` et
traiter les occurrences. Si le volume l'impose, le faire fichier par fichier
avec des `// ignore:` locaux plutôt qu'une désactivation globale — un masque
local est visible et se compte, un masque global s'oublie.

Un critère a été ajouté le 15/08 au contrôle `flutter-analysis` de
`quality/architecture-readiness.json` : ajouter une règle à cette liste ne vaut
pas satisfaction du contrôle.

## 3. ProGuard et R8 (P1)

`android/app/proguard-rules.pro` fait 29 lignes et 10 règles `-keep`. Elles
couvrent Flutter (`io.flutter.**`), UMP et reCAPTCHA — ce qui est bien vu, ces
bibliothèques utilisant la réflexion.

En revanche, aucune règle ne préserve explicitement les classes du SDK Firebase
Android, alors que le build release active `isMinifyEnabled` **et**
`isShrinkResources`. Les plugins Flutter sont couverts par
`-keep class io.flutter.plugins.** { *; }`, mais les classes natives du SDK
Firebase auxquelles ils délèguent ne le sont pas.

Le point délicat est que ces régressions **ne se voient qu'en release** : le
build debug ne passe pas par R8. Un AAB peut donc être produit sans erreur,
puis échouer à l'exécution sur un parcours d'authentification ou de
notification.

Un AAB release a été produit avec succès le 30/07 (`release_android.yml`), mais
la checklist indique qu'il n'a jamais été testé sur appareil réel. **Rien ne
prouve donc à ce jour que le build minifié fonctionne.** C'est le point 1.6 de
la checklist, et il conditionne tout le reste.

**Correctif recommandé** : tester l'AAB existant sur appareil via `bundletool`
ou un partage interne, en exerçant authentification Google, notifications et
micro-IA. Ajouter les règles `-keep` Firebase seulement si une régression est
constatée — ajouter des règles à l'aveugle réduit le bénéfice de R8 sans
justification.

## 4. App Links (P2)

Aucun `assetlinks.json` dans le dépôt, et le manifeste ne contient aucun
`intent-filter` de lien web. Les notifications et les partages n'ouvriront donc
pas l'application sur le contenu visé.

Non bloquant pour la soumission, mais visible à l'usage. Le contrôle
`deep_links_campaigns` de `quality/seo_acquisition_readiness.json` porte
désormais cette réserve explicitement.

## 5. Ce qui est sain

**Configuration de build Android.** `isMinifyEnabled` et `isShrinkResources`
actifs en release, `proguard-android-optimize.txt` en base, configuration de
signature présente, `versionCode` et `versionName` dérivés de Flutter. Le
commentaire sur `minSdk 23` est obsolète — la valeur réelle vient de
`flutter.minSdkVersion` — mais c'est cosmétique et déjà noté dans la checklist.

**Permissions.** Cinq permissions seulement : `INTERNET`, `CAMERA`,
`RECORD_AUDIO`, `POST_NOTIFICATIONS`, `WAKE_LOCK`. Toutes rattachées à une
fonctionnalité réelle, aucune permission dormante. `POST_NOTIFICATIONS` est
bien demandée au moment opportun. `CAMERA` et `RECORD_AUDIO` exigeront une
divulgation proéminente dans la fiche, ce que la checklist prévoit au point 4.4.

**Tests.** 471 fichiers de test Flutter et 308 tests Functions, tous verts. La
suite de validation complète — analyse, tests avec couverture, portes qualité,
build et tests Functions, règles Firestore sur émulateur, build web et budgets
de bundle — s'exécute en 13 minutes et a été verte sur `main` le 15/08.

**Dépendances.** 0 vulnérabilité critique ou haute après correction de
`brace-expansion` le 15/08. 7 modérées subsistent, toutes transitives via les
SDK Google Cloud et documentées.

## 6. Dette structurelle, rappel

Inchangée depuis l'audit du 14/08 et sans effet direct sur l'acceptation Play,
mais elle pèse sur la capacité à corriger vite après publication :

- 18 fichiers dépassent 1 200 lignes, le plus gros à 5 766 ;
- `check_flutter_architecture_size.py` rapporte de nombreux dépassements des
  budgets par type, 500 lignes pour un écran et 250 pour un widget.

Le découpage progresse réellement — le plus gros fichier est passé de 7 218 à
3 901 lignes entre le 29/07 et le 14/08.

## Ordre d'exécution recommandé

1. **Tester l'AAB du 30/07 sur appareil réel** (§3). C'est la seule action qui
   peut révéler un défaut bloquant invisible autrement, et elle ne demande
   aucun développement.
2. **Neutraliser la journalisation en release** (§1), puis réactiver
   `avoid_print`. Reprise mécanique, risque faible, enjeu de conformité réel.
3. **Réactiver `use_build_context_synchronously`** et traiter les occurrences
   (§2). À faire avant la montée en charge du parc, les plantages pesant sur la
   note de l'application.
4. Ajouter les App Links si les notifications doivent ouvrir un contenu précis
   (§4).

## Limites

Le SDK Flutter n'est pas installé dans cet environnement : `flutter analyze` et
`flutter test` n'ont pas été exécutés ici, et le nombre d'occurrences réelles
de `use_build_context_synchronously` n'a donc pas pu être mesuré — seul le fait
que la règle soit désactivée est établi. Ces vérifications restent couvertes
par la CI. L'AAB n'a pas été construit ni analysé depuis cette session : les
conclusions sur R8 portent sur la configuration, pas sur un artefact.

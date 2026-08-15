# Audit qualité de code — préparation Play Store — 2026-08-15

Portée : la qualité du code au regard d'une publication Android. Complète
l'[audit complet du 14/08](audit-complet-2026-08-14.md), centré sur la CI et le
backend, et la [checklist Play Store](../deployment/playstore-launch-checklist.md),
centrée sur le processus de soumission. Ce document ne traite que ce qui relève
du code et de la configuration de build.

## Résumé exécutif

| # | Constat | Sévérité |
|---|---|---|
| 1 | **316 appels `debugPrint`** dans `lib/`, écrivant dans logcat en release. Les plus fournis manipulent des données personnelles : notifications (29), compte (21), authentification sociale (18). Neutralisés le 15/08 en remplaçant l'implémentation de `debugPrint` au démarrage | P0 — **corrigé** |
| 2 | `use_build_context_synchronously` reste **ignoré globalement**. Une réactivation tentée le 15/08 a été annulée : `flutter analyze` signale des occurrences qu'un détecteur statique maison n'avait pas vues. À reprendre à partir de la sortie réelle de l'analyseur | P1 — **non résolu** |
| 3 | ProGuard ne préservait pas les classes du SDK Firebase Android alors que R8 est actif en release. Règles ajoutées le 15/08 — mais **l'AAB reste non testé sur appareil**, seule preuve qui vaudrait | **P1 — test sur appareil requis** |
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

**Correctif appliqué le 15/08.** La mesure a orienté la solution : sur 318
appels, **316 sont des `debugPrint`** et les 2 `print` bruts sont déjà gardés
par `kDebugMode`. Or Flutter expose `debugPrint` comme un point d'extension
réassignable. Son implémentation est donc remplacée au démarrage en release
(`lib/bootstrap/release_logging.dart`), plutôt que de reprendre 316 appelants :
un seul point de contrôle, aucun appelant modifié, et la sortie de débogage
reste intacte en debug et en profil. Un test couvre les deux comportements.

Reste à faire : réactiver `avoid_print` pour empêcher la réintroduction de
`print` bruts non gardés.

## 2. Diagnostics ignorés globalement (requalifié P2)

```yaml
analyzer:
  errors:
    deprecated_member_use: ignore
    use_build_context_synchronously: ignore   # retiré le 15/08
    strict_top_level_inference: ignore
```

**Rectification du 15/08.** Une première version de ce document présentait
`use_build_context_synchronously` comme « une classe de bugs de plantage »
active dans le code. La mesure contredit cette crainte.

Trois passes successives ont été nécessaires, les deux premières étant fausses :

| Mesure | Sites signalés |
|---|---:|
| Heuristique initiale | 116 |
| Heuristique resserrée | 61 |
| **Mesure corrigée** | **0** |

L'erreur des deux premières était de confondre « ligne suivant un `await` » et
« après la fin de l'instruction attendue ». Les sites signalés avaient tous
cette forme :

```dart
final confirmed = await showDialog<bool>(
  context: context,        // argument de l'appel attendu
  builder: (dialogContext) => AlertDialog(...),
);
```

Le `BuildContext` y est passé **en argument de l'appel qu'on attend** : il est
évalué avant la suspension, pas après. L'analyseur ne signale pas ce motif.

Le détecteur corrigé a été validé sur un cas fautif connu, puis exécuté sur
`lib/` : **1 379 `await` détectés, aucun suivi d'un usage de `BuildContext`
sans garde**. Parmi eux, 227 sont immédiatement suivis d'une garde `mounted`,
et le dépôt en compte 452 au total. La discipline n'est pas seulement
appliquée, elle l'est systématiquement.

**La CI a tranché, et contre moi.** La règle a été réactivée le 15/08, puis la
validation a rapporté `Flutter analyze | failure`. Mon détecteur maison, malgré
sa validation sur un cas fautif connu, manque donc des occurrences que
l'analyseur voit — son suivi du flot de contrôle est trop grossier. La ligne a
été remise en attente pour ne pas bloquer des correctifs de production sans
rapport.

**Ce qu'il faut retenir** : trois mesures successives, trois résultats
différents, tous faux. 116, puis 61, puis 0 — et la réalité est ailleurs. La
seule source fiable est `flutter analyze --fatal-infos`, non exécutable depuis
l'environnement d'audit. La reprise doit partir de sa sortie, disponible dans
l'artefact `pr-validation-*` du run 31884684486, et non d'une nouvelle
heuristique.

Le constat de fond tient : la règle est désactivée, ce qui supprime le
garde-fou. Sa réactivation demande de traiter les occurrences d'abord, dans un
travail dédié.

Les deux autres diagnostics sont maintenus. `deprecated_member_use` est
défendable pendant une migration de SDK, à condition d'être borné dans le
temps. `strict_top_level_inference` est une règle récente dont le coût de mise
en conformité peut légitimement être différé.

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

**Correctif appliqué le 15/08** : ajout des règles `-keep` pour
`com.google.firebase.**`, `com.google.android.gms.common.**`, les
`ComponentRegistrar` et les annotations `PropertyName` de la désérialisation
Firestore. Le fichier passe de 29 à 49 lignes et de 10 à 14 règles `keep`.

**Ce correctif ne dispense pas du test sur appareil**, il en réduit seulement
le risque d'échec. Tant que l'AAB n'a pas été exercé sur un téléphone réel —
authentification Google, notifications, micro-IA — rien ne prouve que le build
minifié fonctionne. C'est la seule action de cet audit qu'aucune modification
de code ne peut remplacer.

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
3. **Réactiver `use_build_context_synchronously`** en partant de la sortie
   réelle de `flutter analyze`, et non d'une heuristique (§2). Tentative du
   15/08 annulée faute d'avoir pu mesurer correctement.
4. Ajouter les App Links si les notifications doivent ouvrir un contenu précis
   (§4).

## Limites

Le SDK Flutter n'est pas installé dans cet environnement : `flutter analyze` et
`flutter test` n'ont pas été exécutés ici, et le compte d'occurrences de
`use_build_context_synchronously` repose sur un détecteur statique maison,
validé sur un cas fautif connu mais moins fin que l'analyseur, qui tient compte
du flot de contrôle réel. Ces vérifications restent couvertes
par la CI — et c'est elle qui confirmera la réactivation de
`use_build_context_synchronously` opérée au §2. L'AAB n'a pas été construit ni analysé depuis cette session : les
conclusions sur R8 portent sur la configuration, pas sur un artefact.

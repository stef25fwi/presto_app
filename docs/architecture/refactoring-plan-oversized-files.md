# Plan de refactoring des fichiers surdimensionnés

**Objectif** : ramener les 17 fichiers Dart de plus de 1200 lignes sous les
budgets du dépôt (500 lignes pour un écran, 250 pour un widget) sans aucune
régression fonctionnelle.

**Principe directeur** : ne jamais faire reposer la sûreté sur la relecture
humaine. Chaque étape doit être soit **prouvée mécaniquement**, soit **couverte
par des tests écrits avant** de toucher au code.

---

## 1. Ce que disent les mesures

### Couverture réelle des fichiers concernés

| Fichier | Lignes | Couverture |
|---|---:|---:|
| `lib/pages/messages/conversation_thread_page.dart` | 5181 | 49,4 % |
| `lib/pages/publish_offer_page.dart` | 5116 | 46,8 % |
| `lib/pages/toolbox_je_me_lance_page.dart` | 7218 | 35,7 % |
| `lib/pages/account_page.dart` | 4277 | 21,3 % |
| `lib/main.dart` | 1372 | **1,8 %** |
| `lib/pages/home_page.dart` | 2792 | **0,6 %** |
| `lib/pages/admin_space_page.dart` | 5777 | **0,4 %** |
| `lib/pages/consult_offers_page.dart` | 4115 | **0,2 %** |
| `lib/pages/offers/offer_details_page.dart` | 4518 | **0,1 %** |

C'est la donnée qui structure tout le plan : **cinq de ces fichiers sont à
moins de 2 % de couverture**. Aucune relecture ne rattrapera une régression
dans `offer_details_page.dart` (2 lignes couvertes sur 1784). Sur ces
fichiers, seules des transformations prouvées sont acceptables.

### Forme réelle des fichiers

Deux familles, qui n'appellent pas le même traitement :

| Fichier | Total | Classe `State` | Widgets privés | Famille |
|---|---:|---:|---:|---|
| `ad_placeholder_images_admin_page.dart` | 1590 | 34 | 1542 | widgets |
| `admin_messaging_center_page.dart` | 1765 | 253 | 1288 | widgets |
| `trust_score_widgets.dart` | 1290 | 165 | 824 | widgets |
| `admin_space_page.dart` | 5777 | 1060 | 3658 | widgets |
| `offer_details_page.dart` | 4518 | 1424 | 2519 | widgets |
| `main.dart` | 1372 | 258 | 805 | widgets |
| `toolbox_je_me_lance_page.dart` | 7218 | 3683 | 2718 | mixte |
| `pricing_calculator_page.dart` | 1507 | 743 | 634 | mixte |
| `home_page.dart` | 2792 | 1912 | 716 | mixte |
| `admin_hero_slides_page.dart` | 2368 | 1491 | 716 | mixte |
| `consult_offers_page.dart` | 4115 | 2998 | 694 | état |
| `conversations_list_page.dart` | 2787 | 2411 | 319 | état |
| `user_offers_section.dart` | 3443 | 2671 | 76 | état |
| `conversation_thread_page.dart` | 5181 | 4149 | 590 | état |
| `publish_offer_page.dart` | 5116 | 4846 | 154 | état |
| `account_page.dart` | 4277 | 4061 | 51 | état |
| `fiche_pro_page.dart` | 1237 | 1204 | 9 | état |

Sur les fichiers de la famille « état », extraire les widgets ne gagne
quasiment rien : `publish_offer_page.dart` est à 95 % une seule classe `State`.
Un plan qui ne parlerait que d'« extraire les widgets » échouerait sur la
moitié du périmètre.

Total : **56 353 lignes**, dont **17 313 déplaçables sans aucun risque** (31 %).

---

## 2. La méthode de vérification (et celle qu'il ne faut pas utiliser)

### Le mécanisme sûr : `part` / `part of`

En Dart, découper une bibliothèque en fichiers `part` est la **seule**
décomposition qui préserve le comportement *par construction* : toutes les
parties partagent une unique portée de bibliothèque. Les identifiants privés
`_` restent accessibles, les imports sont inchangés, la résolution des noms est
identique. Aucune ligne de code n'a besoin d'être éditée.

Ce n'est pas une nouveauté dans ce dépôt : **16 fichiers l'utilisent déjà**,
dont le découpage réussi de `lib/pages/pricing_calculator/` en 10 parts. Le plan
généralise un motif éprouvé ici, il n'en introduit pas un nouveau.

### Ce qui ne marche pas : comparer les hash de compilation

L'idée intuitive — « si le `main.dart.js` compilé est identique, le refactoring
est prouvé sûr » — a été **testée et invalidée** :

| Expérience | `main.dart.js` |
|---|---|
| Compilation de référence | `749df471…` — 7 000 549 o |
| Après découpage `part` de `toolbox_je_me_lance_page.dart` | `2a3f5bff…` — 7 000 549 o |
| Même source, recompilée (contrôle de déterminisme) | `2a3f5bff…` — identique |
| Source restaurée, recompilée | `749df471…` — identique à la référence |

La chaîne de compilation est parfaitement **déterministe** : deux compilations
de la même source donnent le même octet. Mais un déplacement `part` pur change
le hash tout en conservant **exactement la même taille**. L'analyse de la
différence montre pourquoi : dart2js émet les déclarations dans l'ordre des
sources et attribue les noms minifiés dans cet ordre. Déplacer une classe
permute les noms — 0,85 % des octets diffèrent, sans un seul changement
sémantique.

**Conséquence** : la comparaison de hash produit de faux positifs et doit être
écartée. L'égalité de **taille** reste un signal secondaire utile et gratuit
(tout ajout ou retrait de logique la ferait varier), mais ce n'est pas une
preuve.

### La bonne méthode : preuve de déplacement pur

`tools/quality/verify_part_extraction.py` compare le multi-ensemble des lignes
significatives avant et après découpage, en ignorant les seules directives
`part` / `part of`. Le déplacement est autorisé ; toute ligne ajoutée,
supprimée ou éditée est signalée.

C'est exact, instantané, et ne demande aucune compilation :

```bash
python3 tools/quality/verify_part_extraction.py \
    --base-ref origin/main lib/pages/toolbox_je_me_lance_page.dart
```

Validé sur le cas réel :

```
# déplacement pur de 3291 lignes
lib/pages/toolbox_je_me_lance_page.dart : OK — déplacement pur,
6847 lignes significatives réparties sur 2 fichier(s).

# une seule ligne altérée parmi 6847
lib/pages/toolbox_je_me_lance_page.dart : ÉCHEC — l'extraction a modifié du code.
  - perdue x1 : final bool outlined;
  + ajoutée x1 : final bool outlined; // typo introduite
```

Le vérificateur est couvert par 10 tests unitaires.

---

## 3. Le garde-fou empêche déjà de déplacer le problème

`check_flutter_architecture_size.py` classe les fichiers ainsi :

- chemin contenant `/widgets/` **ou** nom finissant par `_widgets.dart` → **250 lignes** ;
- chemin contenant `/pages/` ou nom finissant par `_page.dart` → **500 lignes**.

La CI l'exécute en `--changed-only --enforce` : la dette existante est
tolérée, mais **tout fichier nouveau ou en croissance est bloqué**.

Vérifié en pratique : le découpage expérimental produisant un seul fichier
`toolbox_je_me_lance_widgets.dart` de 3291 lignes **échoue** la barrière
(`3291 lines > 250`). Il est donc impossible de « réussir » ce refactoring en
déplaçant un bloc monolithique — chaque `part` doit tenir dans son budget.

Deux conséquences pratiques :

1. Chaque fichier surdimensionné devient **plusieurs** parts cohérentes, pas
   une. `toolbox_je_me_lance_page.dart` en demande une douzaine.
2. Le suffixe du nom change le budget. Ne pas nommer un fichier de 400 lignes
   `..._section.dart` au lieu de `..._widgets.dart` pour échapper au seuil de
   250 : le budget doit refléter la nature du contenu.

**Dette d'outillage à traiter en vague 0** : `quality/flutter_architecture_size_budget.json`
ne déclare que 9 exceptions alors que le dépôt en compte 19. Exécuté sur tout le
dépôt, le garde-fou est en échec et qualifie des fichiers anciens de
« new oversized Flutter file ». La liste doit être réalignée pour que chaque
fichier terminé puisse en être retiré — c'est le compteur d'avancement du plan.

---

## 4. Les quatre niveaux de sûreté

| Niveau | Transformation | Preuve | Couverture requise |
|---|---|---|---|
| **T1** | Déclarations top-level → fichiers `part` | Déplacement pur prouvé + analyzer | **aucune** |
| **T2** | `part` → bibliothèque autonome avec imports | Analyzer + tests | moyenne |
| **T3** | Méthodes de `State` → `extension` en `part` | Analyzer (statique) + tests | moyenne |
| **T4** | Décomposition de l'état (contrôleur, modèles) | Tests de caractérisation | **élevée, écrite avant** |

### T1 — sûr par construction

Déplacement verbatim de classes, mixins, enums et fonctions top-level vers des
`part`. Rien n'est édité. Prouvé par `verify_part_extraction.py`. Applicable
**même à 0,1 % de couverture**, c'est ce qui rend les fichiers non testés
traitables dès maintenant.

### T2 — promotion en vraie bibliothèque

Passer d'un `part` à un fichier importé exige de rendre publics les
identifiants partagés et de passer explicitement les dépendances. Ce n'est plus
un déplacement pur : l'analyzer attrape les erreurs de résolution, mais pas les
erreurs de logique. À réserver aux widgets purement présentationnels sans
dépendance privée.

### T3 — méthodes vers extensions

Une `extension _Build on _MaPageState { … }` placée dans un `part` peut accéder
aux membres privés de la classe : les helpers `Widget _buildX()` se déplacent
sans être réécrits. C'est le seul levier efficace sur la famille « état »
(78 à 119 méthodes par fichier, 4000 à 6300 lignes de corps de méthodes).

Limites à connaître : une extension ne peut pas déclarer de champs (l'état
reste dans la classe), et sa résolution est statique — donc inapplicable à une
méthode surchargée ou appelée dynamiquement. Ces deux cas sont **détectés à la
compilation**, pas à l'exécution : le mode d'échec est un build rouge, pas un
bug en production. `verify_part_extraction.py` ne couvre pas T3 : le
déplacement ajoute l'enveloppe `extension … {` et sa fermeture, donc la preuve
de déplacement pur ne s'applique plus. Ici, ce sont les tests qui font foi.

### T4 — décomposition de l'état

Extraction d'un contrôleur, de modèles, d'un service. Aucune preuve mécanique
possible. **Interdit tant que le fichier n'a pas de tests de caractérisation.**

---

## 5. Séquencement

### Vague 0 — outillage (prérequis, aucun code applicatif touché)

1. Verser `verify_part_extraction.py` et ses tests.
2. Brancher le vérificateur sur `flutter-architecture-size.yml`, exécuté sur
   les fichiers modifiés de la PR.
3. Réaligner `flutter_architecture_size_budget.json` sur les 19 violations
   réelles, avec pour chacune la cible et le découpage prévu.

### Vague 1 — T1 sur la famille « widgets » (gain maximal, risque nul)

Ordre par rapport gain/effort, indépendant de la couverture puisque T1 est
prouvé :

| Fichier | Avant | Après T1 (principal) |
|---|---:|---:|
| `ad_placeholder_images_admin_page.dart` | 1590 | ~50 |
| `admin_messaging_center_page.dart` | 1765 | ~480 |
| `trust_score_widgets.dart` | 1290 | ~470 |
| `main.dart` | 1372 | ~570 |
| `offer_details_page.dart` | 4518 | ~2000 |
| `admin_space_page.dart` | 5777 | ~2120 |
| `toolbox_je_me_lance_page.dart` | 7218 | ~4500 |

Quatre fichiers passent sous budget ou à portée immédiate dès cette vague.
`offer_details_page.dart` et `admin_space_page.dart` — les deux moins couverts —
perdent plus de la moitié de leur volume **sans qu'aucune ligne ne soit
éditée**. C'est précisément l'intérêt de commencer par là.

### Vague 2 — tests de caractérisation (achat de sûreté)

Avant tout T3/T4 sur les fichiers peu couverts. Cibler d'abord le comportement
observable : rendu des états principaux, navigation, effets de bord Firestore
simulés. Objectif : amener `admin_space_page`, `offer_details_page`,
`consult_offers_page`, `home_page` et `main.dart` à un plancher utile.

C'est la vague la plus longue et la moins spectaculaire. C'est aussi celle sans
laquelle le reste n'est pas faisable sans risque.

### Vague 3 — T3 sur la famille « état »

`publish_offer_page`, `account_page`, `conversation_thread_page`,
`conversations_list_page`, `user_offers_section`, `fiche_pro_page`,
`consult_offers_page`. Déplacement des helpers `_build*` et des méthodes
utilitaires vers des extensions en `part`, par lots de 10 à 15 méthodes.

### Vague 4 — T4, décomposition de l'état

Seulement sur les fichiers ayant passé la vague 2. À traiter un fichier par PR,
sans exception.

---

## 6. Discipline de PR

Une PR = un fichier d'origine. Elle doit afficher :

```bash
python3 tools/quality/verify_part_extraction.py --base-ref origin/main <fichier>   # T1 uniquement
flutter analyze --fatal-infos
flutter test
python3 tools/quality/check_flutter_architecture_size.py --changed-only --base-ref main --enforce
```

Pour les vagues T1, joindre en plus la taille de `build/web/main.dart.js` avant
et après : elle doit être **identique à l'octet près**. Ce n'est pas une preuve,
mais un déplacement pur ne la fait jamais varier, et toute variation est un
signal à instruire.

Interdits explicites, quel que soit le niveau :

- mélanger un déplacement et une correction dans la même PR — c'est ce qui rend
  un refactoring irrelisable et non réversible ;
- renommer en même temps qu'on déplace ;
- « profiter » du passage pour améliorer du code.

Chaque fichier terminé sort de `flutter_architecture_size_budget.json`.

---

## 7. Réponse honnête à « 100 % safe »

**Ce qui est réellement sûr à 100 %** : le niveau T1. Le déplacement est prouvé
verbatim par un outil, la portée de bibliothèque est inchangée par construction,
et l'analyzer valide le résultat. Le risque résiduel est celui de la chaîne
Dart elle-même. Cela représente **17 313 lignes, soit 31 % de la dette**, et
c'est applicable dès aujourd'hui, y compris sur les fichiers à 0,1 % de
couverture.

**Ce qui ne peut pas l'être** : les 69 % restants, majoritairement des classes
`State` de 2400 à 4800 lignes. Aucune technique ne rend sûre la décomposition
d'une machine à états de 4846 lignes couverte à 0,4 %. La sûreté s'y achète en
tests, elle ne se décrète pas. Prétendre le contraire serait le vrai risque de
ce plan.

La bonne lecture : T1 livre un tiers de la dette sans risque et immédiatement,
ce qui rend le reste plus petit, plus lisible, et donc plus facile à couvrir de
tests. La vague 2 n'est pas un préalable bureaucratique — c'est ce qui finance
les vagues 3 et 4.

---

## 8. Ce qui a été vérifié pour établir ce plan

- Flutter 3.44.6 (version CI) — `flutter analyze --fatal-infos` : aucun problème ;
- couverture mesurée par `flutter test --coverage` sur 1986 tests ;
- 4 compilations web release complètes pour établir le déterminisme de la
  chaîne, mesurer l'effet d'un découpage `part` et caractériser la différence ;
- découpage `part` réel de `toolbox_je_me_lance_page.dart` (7218 → 3930 + 3291),
  analyzer vert, puis état restauré ;
- comportement du garde-fou de taille vérifié sur le fichier `part` produit ;
- `verify_part_extraction.py` validé sur un déplacement pur et sur un
  déplacement volontairement altéré.

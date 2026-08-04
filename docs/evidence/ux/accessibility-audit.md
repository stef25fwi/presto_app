# Audit accessibilité et UX iliprestō

## Statut

- Date de baseline : 2026-08-02
- Point actif du programme 18/18 : **2 — UX/UI et design system**
- Référentiel interne : WCAG 2.2 niveau AA, principes Material et exigences du registre `quality/accessibility_ux_readiness.json`
- Statut global : **en cours — non certifié**

Ce document distingue les fondations techniques déjà démontrées des validations de parcours encore nécessaires. Aucun contrôle ne doit être déclaré terminé sur la seule présence d’un composant ou d’un thème.

## Résumé

| Contrôle | Niveau constaté | Preuves actuelles | Décision proposée |
|---|---|---|---|
| Design system centralisé | Fondation complète | Tokens, thème, documentation, tests | Vérifiable après CI |
| Contrastes WCAG AA | Couples officiels testés | Calcul automatisé et couples documentés | Vérifiable après CI |
| Navigation clavier et focus | Fondation partielle | Traversée Tab sur composants standards | Reste ouvert |
| Lecteur d’écran et sémantique | Présence ponctuelle | Plusieurs widgets utilisent `Semantics` | Reste ouvert |
| Cibles tactiles | Fondation globale 48 px | Thèmes boutons, icônes et listes + tests | Vérifiable après CI |
| Responsive et texte agrandi | Fondation partielle | Breakpoints + test générique 320 px / 200 % | Reste ouvert |
| États loading, empty et error | Présence hétérogène | Comportements locaux non inventoriés complètement | Reste ouvert |
| Audit des parcours principaux | Non terminé | Cette baseline et les tests existants | Reste ouvert |

## 1. Design system centralisé

### Constat

Le dépôt possédait déjà un thème global, une extension pour les overlays et une charte typographique partielle. Les couleurs, espacements, rayons, breakpoints, exigences de contraste et tailles minimales n’étaient cependant pas rassemblés dans une source de vérité unique.

### Correction mise en place

- création de `lib/app/presto_design_tokens.dart` ;
- intégration des tokens dans `lib/app/theme.dart` ;
- documentation dans `docs/design/design-system.md` ;
- tests dans `test/app/presto_design_system_accessibility_test.dart` ;
- conservation de `lib/constants.dart` comme source actuelle des styles typographiques de base.

### Critère de fermeture

Le contrôle peut devenir `verified` lorsque la CI confirme :

- l’analyse Flutter ;
- les tests du design system ;
- l’absence de régression sur la suite complète.

## 2. Contrastes WCAG AA

### Couples contrôlés automatiquement

- blanc sur bleu de marque `#1A73E8` ;
- texte principal `#0F172A` sur orange `#FF6600` ;
- texte principal sur blanc ;
- texte secondaire `#475569` sur blanc.

Le test interdit explicitement le blanc sur l’orange de marque pour du texte normal, car ce couple ne respecte pas le ratio 4,5:1.

### Limite actuelle

Cette validation couvre les couples officiels du thème. Elle ne constitue pas encore un scan exhaustif de toutes les couleurs locales présentes dans les écrans historiques. Les nouveaux développements doivent utiliser les tokens ; les couleurs locales seront progressivement inventoriées pendant l’audit des parcours.

### Décision

Le contrôle global des **couples approuvés du design system** peut devenir `verified` après CI. Toute anomalie locale découverte ensuite reste une dette de parcours à corriger avant la clôture de l’audit final.

## 3. Navigation clavier et focus visible

### Preuve disponible

Un test vérifie que Tab traverse successivement un `TextButton` et un `FilledButton` utilisant le thème iliprestō.

### Manques

Il reste à vérifier au clavier :

- navigation principale Web ;
- formulaires d’inscription et de publication ;
- recherche et résultats ;
- menus, dialogues et bottom sheets ;
- messagerie ;
- espace compte ;
- abonnements ;
- parcours Je me lance ;
- espace administrateur.

Les composants personnalisés utilisant `GestureDetector` ou `InkWell` doivent être examinés pour garantir une action clavier et un focus visible équivalents.

### Décision

Contrôle maintenu `pending`.

## 4. Lecteur d’écran et sémantique

### Constat

Le code contient plusieurs utilisations de `Semantics`, notamment sur des boutons IA, le Hero, des tuiles administratives, le splash et certaines surfaces de détail. Cette présence démontre une prise en compte partielle, pas une chaîne complète.

### Manques

- ordre de lecture des pages principales ;
- libellés des icônes sans texte ;
- annonce des erreurs et chargements ;
- état sélectionné des filtres et favoris ;
- libellé et progression des étapes ;
- exclusion des images purement décoratives ;
- validation VoiceOver iOS et TalkBack Android ;
- validation du Web avec un lecteur d’écran de référence.

### Décision

Contrôle maintenu `pending`.

## 5. Cibles tactiles accessibles

### Correction mise en place

Le thème impose une taille minimale de 48 × 48 px pour :

- `TextButton` ;
- `ElevatedButton` ;
- `FilledButton` ;
- `OutlinedButton` ;
- `IconButton` ;
- `ListTile`.

Un test vérifie les tailles résolues des styles.

### Limite

Les zones interactives totalement personnalisées doivent encore être auditées. Le thème couvre les composants standards mais ne peut pas corriger automatiquement tous les `GestureDetector` historiques.

### Décision

Le contrôle de la fondation tactile globale peut devenir `verified` après CI. Les exceptions locales restent suivies dans l’audit final.

## 6. Responsive et texte agrandi

### Preuves disponibles

- breakpoints centralisés : compact `< 600`, medium `600–1023`, expanded `≥ 1024` ;
- tailles cibles documentées de 320 à 1440 px ;
- test générique d’une action essentielle à 320 px avec texte à 200 % ;
- plusieurs tests existants utilisent `setSurfaceSize` dans les modules messagerie, boîte à outils et administration.

### Manques

La matrice complète des parcours reste à exécuter pour :

- 320, 360, 390 et 430 px ;
- 600 et 768 px ;
- 1024, 1280 et 1440 px ;
- texte à 200 % ;
- ouverture du clavier virtuel ;
- dialogues, listes longues et navigation latérale.

### Décision

Contrôle maintenu `pending` jusqu’à fermeture de la matrice `docs/evidence/ux/responsive-matrix.md`.

## 7. Cohérence des états loading, empty et error

### Constat

Les écrans disposent de nombreux états spécifiques mais il n’existe pas encore d’inventaire démontrant leur cohérence terminologique, visuelle et comportementale.

### Travaux requis

- inventorier les états des neuf parcours principaux ;
- vérifier présence d’un message compréhensible ;
- vérifier action de reprise lorsque pertinente ;
- supprimer les détails techniques exposés à l’utilisateur ;
- harmoniser les libellés « Réessayer », « Actualiser » et « Aucun résultat » ;
- couvrir les états avec des tests widgets déterministes.

### Décision

Contrôle maintenu `pending`.

## 8. Audit des parcours principaux

### Parcours obligatoires

1. découverte et recherche ;
2. authentification ;
3. publication d’annonce et IA ;
4. consultation, favoris et contact ;
5. messagerie ;
6. abonnements ;
7. compte et sécurité ;
8. Je me lance ;
9. administration critique.

Pour chaque parcours, la fermeture exige :

- clavier ;
- sémantique ;
- cible tactile ;
- contraste ;
- responsive ;
- texte à 200 % ;
- états asynchrones ;
- absence d’overflow et d’exception.

### Décision

Contrôle maintenu `pending`. Cette baseline n’est pas une certification finale.

## Plan d’exécution du point 2

### Lot 2A — Fondation

- [x] tokens centralisés ;
- [x] thème raccordé ;
- [x] documentation du design system ;
- [x] tests de contraste ;
- [x] minimum tactile 48 px ;
- [x] matrice responsive créée ;
- [ ] CI complète verte et fusion.

### Lot 2B — Clavier et sémantique

- [ ] harnais partagé ;
- [ ] navigation et formulaires ;
- [ ] composants personnalisés ;
- [ ] VoiceOver, TalkBack et Web documentés.

### Lot 2C — Responsive et états

- [ ] fermer toutes les cellules de la matrice ;
- [ ] certifier texte 200 % ;
- [ ] harmoniser loading, empty, error et success.

### Lot 2D — Audit final

- [ ] neuf parcours sans anomalie critique ;
- [ ] huit contrôles au statut `verified` ;
- [ ] analyse Flutter et suite complète vertes ;
- [ ] promotion séquentielle vers le point 3.

## Vague du 4 août 2026 — focus, sémantique et états

### Défaut corrigé : le focus clavier était invisible

Le thème exposait `focusColor: #E2E8F0`, soit **1,23:1** sur la surface
blanche et **1,13:1** sur le fond de l’application. WCAG 2.2 (SC 1.4.11)
exige 3:1 pour un indicateur non textuel. Autrement dit, la navigation au
clavier fonctionnait mais ne se voyait pas.

Un anneau de focus explicite a été introduit : `PrestoColors.focusRing`
(#175DB8), soit **6,37:1** sur la surface et **5,87:1** sur le fond, appliqué
aux cinq familles de boutons et au champ de saisie avec une épaisseur
minimale de 2 px. Le ton discret d’origine reste un fond, jamais un
indicateur — un test le verrouille explicitement pour empêcher la confusion
de revenir.

### Composants d’état partagés

`lib/app/presto_states.dart` fournit `PrestoLoadingState`,
`PrestoEmptyState`, `PrestoErrorState` et `PrestoSuccessState`. Chacun est
une région dynamique annoncée (`liveRegion`) portant un libellé : un lecteur
d’écran est désormais informé du passage de « chargement » à « aucun
résultat », ce qu’aucun écran ne faisait auparavant.

L’état d’erreur porte systématiquement une action de reprise.

### Contrôles automatisés

`test/app/presto_accessibility_guidelines_test.dart` applique les règles
intégrées de Flutter sur des arbres de widgets réellement construits :

| Règle | Portée |
|---|---|
| `textContrastGuideline` | états partagés + hub d’administration |
| `androidTapTargetGuideline` | états partagés + hub d’administration |
| `iOSTapTargetGuideline` | états partagés + hub d’administration |
| `labeledTapTargetGuideline` | états partagés + hub d’administration |

S’y ajoutent le contraste de l’anneau de focus sur les deux fonds, la
présence de l’anneau sur chaque famille de boutons et sur le champ de
saisie, et le parcours de tabulation dans l’ordre visuel.

**11 tests, tous verts.**

## Audit des parcours principaux

### Harnais de doublure Firebase

`test/support/firebase_test_harness.dart` fournit une initialisation
idempotente du cœur Firebase et une authentification déterministe. Chaque
fichier de test réimplémentait jusqu’ici sa propre doublure — une centaine de
lignes recopiées, avec des variantes d’initialisation contradictoires. Les
écrans de parcours se rendent désormais sans backend.

`test/support/accessibility_harness.dart` uniformise le rendu à une taille et
un facteur de texte donnés, et l’application des quatre règles intégrées.

### Parcours audités

`test/app/presto_journey_accessibility_test.dart` applique à chaque parcours
les règles de contraste, de cibles tactiles et de libellés, puis vérifie sa
tenue à 320 px avec un texte à 200 %.

| Parcours | Écran | Règles | 320 px / 200 % |
|---|---|:-:|:-:|
| Authentification | `LoginPage` | ✅ | ✅ |
| Compte déconnecté | `SignedOutAccountFallback` | ✅ | ✅ |
| Boîte à outils | `ToolboxHubPage` | ✅ | ✅ |
| Je me lance | `ToolboxPage` | ⛔ dette ouverte | ⛔ dette ouverte |
| Messagerie | `ConversationsListPage` | ✅ (libellés hors périmètre) | ✅ |
| Administration | `AdminSpaceHubPage` | ✅ | ✅ |

**12 tests verts, 2 ignorés avec motif écrit.**

### Défauts de contraste trouvés et corrigés

L’audit a révélé que la règle « jamais de blanc sur l’orange de marque », déjà
écrite dans le design system, était violée sur les parcours réels. L’orange
`#FF6600` plafonne à 2,94:1 avec du blanc — il échoue même au seuil du texte
large.

| Élément | Avant | Après |
|---|---|---|
| `AuthPrimaryButton`, action principale du parcours d’authentification | blanc, 2,94:1 | texte principal, 6,08:1 |
| Barre de titre « Mon compte » | blanc, 2,94:1 | texte principal, 6,08:1 |
| Barres de titre « Boîte à outils », deux écrans | blanc, 2,94:1 | texte principal, 6,08:1 |
| Bouton « Calculer mon prix » sur dégradé orange | blanc, 2,90:1 | texte principal |
| Bouton « Démarrer mon projet » sur dégradé bleu clair | blanc, 2,65:1 | dégradé assombri, 4,60:1 |
| Mot-clé « iliprestō » orange sur blanc | 2,94:1 | `brandOrangeText`, 5,01:1 |

Le jeton `PrestoColors.brandOrangeText` (#BF4A00) est né de cet audit :
l’orange de marque reste réservé aux aplats, cette variante assombrie au texte
sur fond clair.

### Défaut de mise en page trouvé et corrigé

Le bloc de marque de l’écran de compte déconnecté était un `Row` figé : il
débordait de 30 px au repos et de 464 px à 320 px avec un texte agrandi. Il
passe désormais à la ligne.

### Dette ouverte assumée

`ToolboxPage` répartit une hauteur figée entre deux cartes qui la distribuent
avec des `Expanded`. La page déborde de 191 px sur un écran plus haut que son
réglage, et de 1 276 px à 200 % de texte. La rendre intrinsèque suppose de
changer la distribution verticale de la carte — un changement de conception,
pas un ajustement.

Le parcours reste listé dans l’audit et son motif est imprimé par le lanceur :
un test refuse qu’un parcours soit écarté sans motif écrit. La correction est
rattachée au point 3.

### Ce qui reste ouvert

Trois parcours ne sont pas encore audités : publication, consultation et
abonnement. Leurs écrans exigent plus qu’une doublure d’authentification —
Firestore peuplé, Storage et Stripe.

Aucune vérification sur lecteur d’écran réel — VoiceOver, TalkBack, NVDA — n’a
été réalisée : elle exige des appareils, hors de portée d’une exécution
automatisée. Les contrôles `screen-reader` et `accessibility-audit` restent
donc `pending`.

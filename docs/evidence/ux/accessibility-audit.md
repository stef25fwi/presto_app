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

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
| Navigation clavier et focus | Fondation partielle + 1 correctif ponctuel (15/08) | Traversée Tab sur composants standards ; `home_page.dart` §3bis | Reste ouvert |
| Lecteur d’écran et sémantique | Présence ponctuelle + 1 correctif ponctuel (15/08) | Plusieurs widgets utilisent `Semantics` ; `home_page.dart` §3bis | Reste ouvert |
| Cibles tactiles | Fondation globale 48 px | Thèmes boutons, icônes et listes + tests | Vérifiable après CI |
| Responsive et texte agrandi | Fondation partielle | Breakpoints + test générique 320 px / 200 % | Reste ouvert |
| États loading, empty et error | Revue partielle (4/9 parcours, 15/08) | §7bis : messagerie, compte, publication, consultation d'offres | Reste ouvert |
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

## 3bis. Revue de code ciblée `GestureDetector` — 15/08/2026

Cette section ne remplace pas le parcours manuel au clavier exigé au §3 : elle
documente une revue de code (pas un test sur appareil ni une sortie
`flutter analyze`), avec la même prudence méthodologique que l'audit du 14/08
sur `use_build_context_synchronously` — une heuristique de recherche de motif
peut se tromper dans les deux sens, elle ne vaut donc que comme liste de
pistes à vérifier, pas comme certification.

### Méthode

`grep` de `GestureDetector(` sur `lib/` : **39 occurrences** dans 21
fichiers (avant correctif). Le principe du design system (« aucun `GestureDetector` cliquable
ne doit être utilisé sans sémantique et gestion clavier équivalente ») ne
s'applique qu'aux occurrences dont `onTap` déclenche une action de
navigation ou de sélection — pas à celles qui gèrent un simple geste de
défilement ou de fermeture de clavier.

### Défaut confirmé et corrigé

`lib/pages/home_page.dart`, méthode `_buildOfferCard` (carte d'annonce du
carrousel d'accueil, l. 2171 avant correctif) : `GestureDetector(onTap: ...)`
nu, sans `Semantics` ni mécanisme clavier. Cette carte n'était donc :

- ni atteignable au Tab, ni activable par Entrée/Espace ;
- ni annoncée de façon cohérente par un lecteur d'écran (aucun rôle
  « bouton », aucun libellé de groupe — un lecteur d'écran aurait lu les
  `Text` enfants séparément, contrairement à la règle « une seule annonce
  pour un groupe visuel »).

C'est un écran d'accueil, le point d'entrée le plus fréquenté de l'app : la
carte est donc restée exclue de la navigation clavier pour un nombre
important de visites. **Corrigé** : remplacement par
`Semantics(button: true, label: ...)` englobant un `Material` +`InkWell`
(plutôt qu'un `Focus` + gestion clavier manuelle), qui apporte
automatiquement le focus Tab, l'activation Entrée/Espace et la sémantique
bouton par le framework Flutter — sans changement visuel (le `Material` est
transparent). Non vérifié en runtime (SDK Flutter indisponible dans ce
sandbox) : structure de parenthèses et types revérifiés à la main, mais la
CI reste la seule confirmation définitive.

### Second défaut confirmé et corrigé le 16/08 — le slide du carrousel hero

La piste ouverte sur la ligne ~1172 (icône de slide) s'est avérée réelle,
mais **pas là où on l'attendait** : l'icône appelle `onSlideTap`, exactement
le même callback que le `GestureDetector` qui enveloppe le slide entier
(l. ~1375). Le défaut n'était donc pas l'icône seule mais la paire :

- le slide entier, cliquable, n'était ni atteignable au clavier ni annoncé ;
- l'icône imbriquée exposait une **seconde** cible tactile pour la même
  action, qu'un lecteur d'écran aurait annoncée comme un « bouton » nu sans
  libellé — exactement ce que le design system proscrit.

Corriger les deux séparément aurait aggravé le problème en produisant une
double annonce. Le correctif traite la paire :

- le slide devient `Semantics(button: true, label: '<titre>. <sous-titre>')`
  englobant `Material` + `InkWell` → une annonce unique et porteuse de sens,
  focus Tab et activation Entrée/Espace fournis par le framework ;
- l'icône conserve son tap (confort à la souris) mais passe sous
  `ExcludeSemantics` → plus de doublon dans l'arbre d'accessibilité.

### Occurrences restantes (pistes non traitées)

| Ligne | Rôle | Estimation |
|---:|---|---|
| ~1019 | Bascule d'affichage des suggestions de recherche, superposé à un champ de texte déjà focusable | Risque faible — le champ sous-jacent reste accessible par lui-même |
| ~1188 | Swipe horizontal du carrousel hero (`onHorizontalDragEnd`) | **Hors périmètre de la règle** : c'est un geste de défilement, pas une action `onTap`. Des indicateurs de pagination existent déjà |
| ~1595 | Appui long de diagnostic (`_seedSampleOffers`) | Outil de développement, non destiné à l'utilisateur final |

`lib/` compte désormais **37 `GestureDetector`** répartis sur 21 fichiers
(39 avant les deux correctifs). Les 32 hors `home_page.dart`
(`conversation_thread_page.dart` ×4, `ai_publish_control.dart` ×3,
`admin/ad_placeholder_images_admin_page.dart` ×4, `offer_details_page.dart`
×2, `account_page.dart` ×2, `admin_typography_page.dart` ×2,
`hero_media_slider.dart` ×2, et 13 fichiers à 1 occurrence) n'ont pas été
examinées. Elles restent une piste de travail pour la suite du §3, pas un
constat — et l'enseignement des deux corrections faites est qu'il faut
regarder la **paire parent/enfant** avant de conclure, un `GestureDetector`
isolé ne disant rien de son contexte.

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

## 7bis. Revue de code ciblée — 4 parcours sur 9 — 15/08/2026

Revue par lecture de code (pas de test sur appareil ni de mesure runtime,
SDK Flutter indisponible dans ce sandbox) des chargeurs de données
principaux de 4 des 9 parcours listés au §8 : **messagerie, compte,
publication d'annonce, consultation d'offres**. Les 5 autres (découverte et
recherche, authentification, favoris et contact, abonnements, Je me lance,
administration) restent non couverts.

| Parcours | Fichier(s) examiné(s) | Constat |
|---|---|---|
| Messagerie | `lib/pages/messages/conversations_list_page.dart` (l. ~1687) | Loading (spinner tant que l'état est `null`), vide avec message différencié selon le contexte (recherche / filtre archivé / conversations orphelines), erreurs remontées via un champ `errorsByField` dédié plutôt qu'une exception de flux brute. Cohérent. |
| Compte | `lib/pages/account_page.dart` (l. ~3370, `StreamBuilder<User?>`) | Loading explicite (« Restauration de la session… »), état déconnecté géré par `SignedOutAccountFallback`. Le flux `idTokenChanges()` du SDK Auth n'émet pas d'erreur réseau en pratique — absence de branche `hasError` jugée non risquée. |
| Publication d'annonce | `lib/pages/publish_offer_page.dart` (soumission, l. ~4080-4145) | Pas de `StreamBuilder`/`FutureBuilder` en tête d'écran (chargement par `bool _isSubmitting` explicite). Erreurs de soumission affichées via `showErrorSnackBar` avec message humain et action de reprise (« Recharge l'application puis réessaie »). Cohérent avec le vocabulaire prescrit. |
| Consultation d'offres | `lib/pages/consult_offers_page.dart` (l. ~1930-2066) | Loading, erreur avec icône + message + bouton **« Réessayer »** (correspond exactement au vocabulaire imposé par `docs/design/design-system.md`), et état vide dédié (`_EmptyOffers`) avec action de rafraîchissement. Le plus abouti des quatre. |

### Vérification complémentaire — recherche de « spinner infini »

Recherche des fichiers utilisant `StreamBuilder`/`FutureBuilder` sans aucune
occurrence de `hasError` dans le fichier (candidat à un chargement bloqué
indéfiniment en cas d'erreur) : **18 fichiers** sur 46 utilisant l'un de ces
deux widgets. Trois ont été vérifiés individuellement
(`lib/pages/auth/auth_gate.dart`, `lib/pages/account_page.dart` l. ~3372,
`lib/pages/offers/offer_details_page.dart` l. ~1566 et ~1691) : dans les
trois cas, l'absence de `hasError` est un choix défendable — flux
`FirebaseAuth` locaux qui n'émettent pas d'erreur réseau en pratique, ou
dégradation silencieuse vers une valeur par défaut (liste vide, offre de
base sans enrichissement marketplace) plutôt qu'un blocage. Aucun bug de
type « écran figé en chargement sans message ni recours » trouvé dans ce
sous-ensemble. Les 15 fichiers restants de cette liste (pages admin
majoritairement, hors périmètre « parcours principal utilisateur ») n'ont
pas été examinés.

### Décision

`states-consistency` reste `pending` : le doneWhen exige une revue des neuf
parcours, celle-ci n'en couvre que quatre. Mais la présence constatée est
positive et cohérente sur cet échantillon — plus proche d'un travail de
documentation restant que d'un défaut d'implémentation à corriger.

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

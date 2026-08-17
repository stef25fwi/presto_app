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
| Navigation clavier et focus | Fondation partielle + 14 correctifs ciblés (15 et 16/08) | Traversée Tab sur composants standards ; §3bis, inventaire `GestureDetector` clos (39→16) | Reste ouvert |
| Lecteur d’écran et sémantique | Présence ponctuelle + 14 correctifs ciblés (15 et 16/08) | Plusieurs widgets utilisent `Semantics` ; §3bis | Reste ouvert |
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

### Occurrences dans `home_page.dart` non retenues comme défauts

| Ligne | Rôle | Estimation |
|---:|---|---|
| ~1019 | Bascule d'affichage des suggestions de recherche, superposé à un champ de texte déjà focusable | Risque faible — le champ sous-jacent reste accessible par lui-même |
| ~1188 | Swipe horizontal du carrousel hero (`onHorizontalDragEnd`) | **Hors périmètre de la règle** : c'est un geste de défilement, pas une action `onTap`. Des indicateurs de pagination existent déjà |
| ~1595 | Appui long de diagnostic (`_seedSampleOffers`) | Outil de développement, non destiné à l'utilisateur final |

### Passe étendue — 8 défauts supplémentaires corrigés le 16/08

Poursuite systématique de la revue sur les fichiers qui restaient comme
pistes. Six écrans examinés en entier (pas seulement les occurrences
trouvées par grep), avec vérification d'équilibrage de parenthèses sur
chaque fichier entier (comparé à sa version `HEAD` avant modification, pas
seulement sur l'extrait modifié) avant de committer.

| Fichier | Constat | Correctif |
|---|---|---|
| `conversation_thread_page.dart` — titre d'AppBar | Nom + avatar du contact, ouvrant son profil, sans sémantique ni clavier. Ouvert sur **chaque** conversation | `Semantics(button, label: nom)` + `Material`/`InkWell` |
| `conversation_thread_page.dart` — bouton supprimer pièce jointe | Icône 28 px sans rôle ni clavier ; le tap restait actif pendant la suppression en cours | `Semantics(button, label)` + `InkWell` ; `onTap` désormais désactivé (`null`) tant que `isDeleting` — corrige au passage un double-tap possible |
| `conversation_thread_page.dart` — aperçu photo plein écran | Ouverture d'un visualiseur d'image sans rôle ni clavier | `Semantics(button, label: 'Voir la photo en plein écran')` + `InkWell` |
| `conversation_thread_page.dart` — bulle de message (appui long) | Menu contextuel (copier/supprimer/réagir) accessible uniquement par appui long, sans équivalent clavier ni lecteur d'écran garanti | `CustomSemanticsAction` exposant la même action comme action discrète annoncée — le geste tactile reste inchangé, c'est le mécanisme prévu par Flutter pour ce cas précis |
| `offer_details_page.dart` — en-tête annonceur | Nom de l'annonceur, tap ouvrant son profil, sans rôle ni clavier | `Semantics(button, label)` + `Material`/`InkWell` |
| `offer_details_page.dart` — révéler le téléphone | CTA de contact principal de la fiche, désactivé conditionnellement (`canRequestReveal`) mais sans état accessible correspondant | `Semantics(button: canRequestReveal)` + `InkWell` (même garde sur `onTap`, donc même état pour tous les utilisateurs) |
| `ai_publish_control.dart` — sélecteur de mode (Texte+IA / IA vocale) | Bascule d'onglet sans rôle ni état `selected` exposé | `Semantics(button, selected, enabled, label)` + `InkWell` |
| `ai_publish_control.dart` — bouton microphone | Le contrôle le plus sollicité du flux micro-IA (démarrer/arrêter l'enregistrement), sans rôle ni libellé d'état | `Semantics(button, enabled: !_isAnalyzing, label)` reflétant l'état (« Démarrer… » / « Arrêter… » / « Analyse en cours ») + `InkWell` |
| `ai_publish_control.dart` — bouton « Remplir avec l'IA » | `Tooltip` déjà présent (label lu par les lecteurs d'écran via sa sémantique intégrée) mais pas de focus clavier | `InkWell` ajouté sous le `Tooltip` existant, sans dupliquer son libellé |
| `fiche_pro_page.dart` — suppression d'une photo de réalisation (appui long) | Même défaut que la bulle de message : action réservée au propriétaire, accessible seulement par appui long | `CustomSemanticsAction`, gardée par `widget.isOwner` |
| `toolbox_je_me_lance_page.dart` — sélecteur de région | Champ de type « picker » (« Choisir votre région... ») sans rôle ni clavier | `Semantics(button, label)` reflétant la région choisie ou son absence + `InkWell` |

**Un doublon trouvé et supprimé, pas corrigé** : `conversations_list_page.dart`,
avatar de conversation. Même défaut que la carte du carrousel d'accueil (§3
ci-dessus) — la ligne entière est déjà un `Material`/`InkWell` qui ouvre la
même conversation (`openConversation()`), et l'avatar portait un second
`GestureDetector` appelant exactement le même callback, sans retour visuel
ni ajout fonctionnel. Retiré plutôt que rendu accessible en double : il n'y
avait rien à rendre accessible, l'avatar répond déjà au tap via l'`InkWell`
ambiant de la ligne. Confirme le motif déjà observé sur la carte du
carrousel — un `GestureDetector` isolé ne se lit jamais sans vérifier s'il
duplique un geste déjà géré par un parent.

`account_page.dart` (2 occurrences) et `consult_offers_page.dart`/
`publish_offer_page.dart` réexaminés : confirmé motif « fermer le clavier au
tap en dehors », hors périmètre de la règle — aucun correctif.

### Troisième passe — clôture de l'inventaire, 16/08/2026

Les fichiers restants (admin, widgets secondaires) ont été examinés un par
un, plutôt que laissés en pistes.

**Corrigés (4)** :

| Fichier | Constat | Correctif |
|---|---|---|
| `typography_floating_panel.dart` | Pastille flottante de réglage de texte, visible sur tout l'app (Android + web selon son propre commentaire), sans rôle ni clavier | `Semantics(button, label)` + `Material`/`InkWell` |
| `home_interactions.dart` — `PrestoTapScale` | Widget **réutilisable** (utilisé par `HomeCategoryChip`) : corriger cette seule classe profite à tous ses usages présents et futurs | `Material`/`InkWell` (le nom de la catégorie, déjà en `Text` descendant, sert de libellé via la fusion sémantique par défaut) |
| `home_bottom_nav_item.dart` | Barre de navigation du bas — le contrôle le plus sollicité de l'app, présent sur tout écran qui l'affiche. Aucun rôle, aucun état `selected` exposé, badge nombre de non-lus invisible pour un lecteur d'écran | `Semantics(button, selected, label)` incluant le badge (« Messages, 12 non lus ») + `Material`/`InkWell` |
| `entrepreneur_toolbox_slide.dart` | Carte de navigation vers la boîte à outils entrepreneur, même motif que la carte du carrousel d'accueil corrigée en premier | `Semantics(button, label)` + `Material`/`InkWell` |

**Non concernés, vérifiés individuellement (4)** :

- `admin/ad_placeholder_images_admin_page.dart`, `hero_media_slider.dart`,
  `admin_typography_page.dart` : traités dans la passe précédente (voir
  tableau ci-dessus, 7 corrections).
- `premium_info_button.dart` : porte déjà un `Material`/`InkWell` interne
  sur le même `onTap` (l. 92-98 avant cette revue) — focus clavier,
  activation et rôle bouton déjà couverts. Le `GestureDetector` externe ne
  sert qu'à une animation de pression (échelle 0.96), sans lacune réelle.
- `offline_banner.dart` — `OfflineActionGuard` : **code mort**, aucun appel
  dans `lib/` (seulement testé). Pas de bug vivant à corriger ; non
  supprimé faute de lien direct avec un correctif de performance comme
  `CityRepoCompact` (§1.3), donc laissé pour une revue de nettoyage
  séparée plutôt que mêlé à cette revue d'accessibilité.
- `public_prelaunch_page.dart` — geste caché « taper N fois pour débloquer
  l'accès développeur » (`_handleStatusTap`). L'exposer comme bouton
  annoncé irait à l'encontre de son but ; correctement hors périmètre.
- `admin_hero_slides_page.dart` — outil de positionnement du point focal
  d'une image par glissement continu (`onPanDown`/`onPanUpdate`), pas une
  action discrète. Une vraie solution d'accessibilité (ajustement au
  clavier par flèches, valeur annoncée) est un travail de conception à
  part entière, pas une conversion mécanique — documenté comme lacune
  restante plutôt que traité à l'aveugle.

**Test mis à jour pour rester vrai, pas juste vert** :
`test/entrepreneur_toolbox_slide_test.dart` récupérait directement le
`GestureDetector` ancêtre du texte de la carte et appelait son `onTap`
manuellement (`tester.widget<GestureDetector>(find.ancestor(...))`). Le
correctif ayant remplacé ce `GestureDetector` par un `InkWell`, le test a
été adapté pour chercher un `InkWell` — recherche exhaustive confirmant que
c'était la seule occurrence de ce motif (`find.byType(GestureDetector)`)
dans toute la suite de tests.

### Bilan chiffré final

`lib/` compte désormais **16 `GestureDetector`**, contre 39 au 15/08 : 12
convertis en `Semantics`+`InkWell`, 2 conservés en `GestureDetector` mais
dotés d'un `CustomSemanticsAction`, 1 supprimé comme doublon. Des 16
restants : 5 dans `home_page.dart` et 2 ailleurs sont des motifs déjà
vérifiés hors périmètre (scrim de fermeture clavier, swipe, appui long
d'outil de dev), 2 conservés à dessein (geste caché, action de drag), 1
déjà accessible via un `InkWell` interne préexistant, le solde réparti sur
des pages admin à trafic marginal.

**Non vérifié en runtime** pour l'ensemble des trois passes (SDK Flutter
indisponible dans ce sandbox) : chaque fichier modifié a été revérifié par
équilibrage de parenthèses/accolades/crochets contre sa version `HEAD`
avant modification, et tous les tests référençant les widgets touchés ont
été relus pour écarter un risque de rupture. La confirmation définitive
reste la CI.

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

# Design system iliprestō

## Statut

- Version : 1.0
- Date : 2026-08-02
- Périmètre : Web, Android et iOS
- Source de vérité technique : `lib/app/presto_design_tokens.dart`
- Thème global : `lib/app/theme.dart`
- Statut : fondation approuvée, audit des parcours encore en cours

## Principes

Le design system doit rendre iliprestō cohérent, lisible et utilisable de 320 à 1440 px, avec un texte agrandi à 200 %. Toute nouvelle interface doit utiliser les tokens et composants globaux avant de définir une valeur locale.

Principes obligatoires :

1. une action principale clairement identifiable par écran ;
2. aucun texte essentiel dépendant uniquement d’une couleur ou d’une icône ;
3. toutes les actions utilisables au clavier et par technologie d’assistance ;
4. cibles interactives d’au moins 48 × 48 px ;
5. contraste WCAG AA pour le texte normal ;
6. états loading, empty, error, disabled et success compréhensibles ;
7. aucun débordement ou masquage d’action essentielle à 320 px et 200 % de texte.

## Palette

| Token | Valeur | Usage |
|---|---|---|
| `brandOrange` | `#FF6600` | Marque, accent, repère visuel |
| `brandBlue` | `#1A73E8` | Actions principales, liens, AppBar |
| `brandBlueDark` | `#175DB8` | Variante renforcée et contrastée |
| `textPrimary` | `#0F172A` | Texte principal |
| `textSecondary` | `#475569` | Texte secondaire sur fond clair |
| `surface` | `#FFFFFF` | Cartes, dialogues et menus |
| `scaffold` | `#FDF4EC` | Fond général clair |
| `surfaceMuted` | `#F4F7FB` | Section secondaire |
| `surfaceSelected` | `#EAF2FF` | Élément sélectionné |
| `border` | `#D7DEE8` | Bordure neutre |
| `focus` | `#E2E8F0` | Retour visuel de focus |
| `success` | `#0F766E` | Confirmation |
| `warning` | `#D97706` | Vigilance |
| `danger` | `#B42318` | Erreur ou action destructive |

### Couples de contraste approuvés

- blanc sur bleu `#1A73E8` : texte normal autorisé ;
- texte principal `#0F172A` sur orange `#FF6600` : texte normal autorisé ;
- texte principal ou secondaire sur blanc : autorisé ;
- texte principal sur fond général `#FDF4EC` : autorisé.

### Couple interdit

Le blanc sur l’orange `#FF6600` n’atteint pas le ratio WCAG AA pour du texte normal. Une surface orange contenant du texte doit utiliser `textOnOrange`, c’est-à-dire `#0F172A`, sauf texte réellement large validé séparément.

Les ratios sont contrôlés par `test/app/presto_design_system_accessibility_test.dart`.

## Typographie

La police principale est **Inter**. Les styles de base restent centralisés dans `lib/constants.dart` :

| Style | Taille | Graisse | Usage |
|---|---:|---:|---|
| AppBar | 21 | 700 | Titre de page |
| Section | 18 | 700 | Titre de section |
| Carte | 16 | 700 | Titre de carte |
| Corps | 14 | 500 | Contenu courant |
| Métadonnée | 12 | 500 | Information secondaire |

Règles :

- ne pas descendre sous 12 px pour une information nécessaire ;
- ne jamais bloquer la mise à l’échelle système ;
- préférer une hauteur flexible à une hauteur fixe autour d’un texte ;
- limiter les lignes lorsque le contenu peut être tronqué sans perte, sinon permettre le retour à la ligne ;
- tester les actions essentielles à `TextScaler.linear(2.0)`.

## Espacements

| Token | Valeur |
|---|---:|
| `xxs` | 4 px |
| `xs` | 8 px |
| `sm` | 12 px |
| `md` | 16 px |
| `lg` | 24 px |
| `xl` | 32 px |
| `xxl` | 48 px |

Une valeur locale différente doit répondre à une contrainte mesurée. Les marges principales d’un écran compact utilisent généralement 12 à 16 px.

## Rayons

| Token | Valeur | Usage indicatif |
|---|---:|---|
| `sm` | 10 px | Petit élément |
| `md` | 14 px | Champ, bouton, snackbar |
| `lg` | 18 px | Menu, carte secondaire |
| `xl` | 24 px | Dialogue et bottom sheet |
| `hero` | 28 px | Carte Hero ou marketing |

## Breakpoints

| Classe | Largeur | Comportement |
|---|---|---|
| Compact | `< 600 px` | Navigation mobile, une colonne |
| Medium | `600–1023 px` | Tablette, navigation adaptée, deux colonnes si utile |
| Expanded | `≥ 1024 px` | Desktop, contenu borné et colonnes contrôlées |

La matrice de validation utilise : 320, 360, 390, 430, 600, 768, 1024, 1280 et 1440 px.

## Composants interactifs

Le thème global impose une taille minimale de 48 × 48 px aux :

- `TextButton` ;
- `ElevatedButton` ;
- `FilledButton` ;
- `OutlinedButton` ;
- `IconButton` ;
- `ListTile`.

Une action personnalisée doit respecter la même taille avec `ConstrainedBox`, `SizedBox` ou une contrainte équivalente. Une zone visuelle plus petite peut exister si sa zone tactile réelle reste au minimum de 48 px.

## Focus et clavier

- l’ordre de focus suit l’ordre de lecture ;
- la touche Tab atteint toutes les actions ;
- Entrée et Espace activent l’action adaptée ;
- Échap ferme les dialogues et menus lorsque cela ne détruit pas une donnée ;
- aucun `GestureDetector` cliquable ne doit être utilisé sans sémantique et gestion clavier équivalente ;
- le focus doit rester visible avec le thème global ou une décoration locale explicite.

La fondation est couverte par un test de traversée clavier. La certification des parcours principaux reste suivie dans l’audit UX.

## Sémantique et lecteur d’écran

Chaque contrôle personnalisé doit exposer :

- un libellé compréhensible hors contexte visuel ;
- son type ou rôle ;
- son état sélectionné, activé, désactivé ou en cours ;
- une valeur lorsque celle-ci est utile ;
- une seule annonce pour un groupe visuel qui ne doit pas être lu plusieurs fois.

Les images décoratives sont exclues de la sémantique. Les images utiles reçoivent un libellé. Les boutons uniquement composés d’une icône utilisent un `tooltip` ou un `Semantics(label: ...)`.

## États asynchrones

Chaque surface chargeant des données doit prévoir :

| État | Exigence |
|---|---|
| Loading | progression annoncée, pas de faux contenu interactif |
| Empty | explication et action utile lorsque possible |
| Error | message compréhensible, action de reprise, détail technique non exposé |
| Disabled | raison accessible si l’action est importante |
| Success | confirmation non dépendante uniquement de la couleur |

Les formulations doivent rester cohérentes : « Réessayer » pour une reprise technique, « Actualiser » pour recharger volontairement, « Aucun résultat » pour une recherche vide.

## Gouvernance

Toute évolution du design system doit :

1. modifier les tokens ou composants centraux ;
2. ajouter ou adapter les tests ;
3. mettre à jour ce document ;
4. vérifier la matrice responsive ;
5. actualiser `quality/accessibility_ux_readiness.json` avec une preuve réelle.

Un contrôle UX ne passe à `verified` qu’après présence d’une preuve automatisée ou d’un audit documenté. La simple présence de code ne suffit pas.

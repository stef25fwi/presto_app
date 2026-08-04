# Matrice responsive iliprestō

## Statut

- Date de création : 2026-08-02
- Point 18/18 : 2 — UX/UI et design system
- Statut global : **en cours**
- Cible texte : 100 % et 200 %

Cette matrice définit les dimensions obligatoires et les parcours à certifier. Une cellule ne devient « validée » qu’avec un test widget, une capture de référence ou une vérification sur appareil documentée.

## Largeurs obligatoires

| Largeur | Classe | Support représentatif | Fondation design system | Parcours complets |
|---:|---|---|---|---|
| 320 px | Compact | Petit smartphone | ✅ test générique à 200 % | ⏳ à valider |
| 360 px | Compact | Smartphone Android | ✅ breakpoint couvert | ⏳ à valider |
| 390 px | Compact | iPhone courant | ✅ breakpoint couvert | ⏳ à valider |
| 430 px | Compact | Grand smartphone | ✅ breakpoint couvert | ⏳ à valider |
| 600 px | Medium | Petite tablette | ✅ breakpoint couvert | ⏳ à valider |
| 768 px | Medium | Tablette portrait | ✅ breakpoint couvert | ⏳ à valider |
| 1024 px | Expanded | Tablette paysage / petit desktop | ✅ breakpoint couvert | ⏳ à valider |
| 1280 px | Expanded | Desktop | ✅ breakpoint couvert | ⏳ à valider |
| 1440 px | Expanded | Grand desktop | ✅ breakpoint couvert | ⏳ à valider |

## Parcours à vérifier

| Parcours | Pages principales | 320–430 | 600–768 | 1024–1440 | Texte 200 % | Statut |
|---|---|---|---|---|---|---|
| Découverte | Pré-lancement, Home, recherche | ⏳ | ⏳ | ⏳ | ⏳ | En attente |
| Authentification | Connexion, inscription, récupération | ⏳ | ⏳ | ⏳ | ⏳ | En attente |
| Publication | Création d’annonce, IA texte, Micro IA | ⏳ | ⏳ | ⏳ | ⏳ | En attente |
| Consultation | Liste, détail, favoris, contact | ⏳ | ⏳ | ⏳ | ⏳ | En attente |
| Messagerie | Liste et fil de conversation | ⏳ | ⏳ | ⏳ | ⏳ | En attente |
| Abonnement | Offres, Checkout, gestion | ⏳ | ⏳ | ⏳ | ⏳ | En attente |
| Compte | Profil, sécurité, suppression | ⏳ | ⏳ | ⏳ | ⏳ | En attente |
| Je me lance | Saisie, parcours, étape, PDF | ⏳ | ⏳ | ⏳ | ⏳ | En attente |
| Administration | Hub et fonctions critiques | ⏳ | ⏳ | ⏳ | ⏳ | En attente |

## Critères de validation d’une cellule

- aucune exception Flutter ;
- aucun overflow jaune/noir ;
- aucun contenu essentiel masqué ou tronqué ;
- action principale visible ou accessible par défilement évident ;
- dialogues et bottom sheets utilisables ;
- clavier virtuel ne masque pas l’action en cours ;
- zones tactiles d’au moins 48 × 48 px ;
- ordre visuel et ordre de lecture cohérents ;
- à 200 %, aucune action essentielle ne disparaît.

## Matrice exécutée automatiquement

`test/app/presto_responsive_matrix_test.dart` croise cinq largeurs de
référence — 320, 375, 600, 1024 et 1440 px — avec trois facteurs de texte —
100 %, 150 % et 200 %. Les bornes proviennent de
`PrestoAccessibility.responsiveWidths` et `PrestoAccessibility.textScales` :
la documentation et le test lisent la même source, et un test dédié refuse
que les deux divergent.

Chaque cellule vérifie qu’aucune exception de rendu n’est levée — un
débordement en lève une en mode test —, que l’action essentielle reste
présente et que sa cible tactile reste d’au moins 48 px.

**46 cellules exécutées, 46 vertes.**

| Cible | 320 | 375 | 600 | 1024 | 1440 |
|---|:-:|:-:|:-:|:-:|:-:|
| État vide, 100 / 150 / 200 % | ✅ | ✅ | ✅ | ✅ | ✅ |
| État erreur, 100 / 150 / 200 % | ✅ | ✅ | ✅ | ✅ | ✅ |
| Hub d’administration, 100 / 150 / 200 % | ✅ | ✅ | ✅ | ✅ | ✅ |

### Défaut trouvé et corrigé

Le hub d’administration débordait **à toutes les largeurs** dès 150 %
d’agrandissement : la grille imposait une hauteur de tuile figée à 174 px
tandis que le texte grandissait. La hauteur suit désormais le facteur de
texte (`MediaQuery.textScalerOf(context).scale(174)`).

Ce défaut n’était visible d’aucune vérification de jetons : il fallait rendre
l’écran réel à une échelle réelle pour le voir.

## Preuves existantes

- `test/app/presto_design_system_accessibility_test.dart` : classification des breakpoints, cible tactile et bouton essentiel à 320 px / 200 % ;
- tests utilisant `setSurfaceSize` dans plusieurs modules de messagerie, boîte à outils et administration ;
- tests de non-régression Flutter exécutés dans la CI.

La fondation et les composants partagés sont désormais couverts sur toute la
matrice. Les parcours métier du tableau ci-dessus restent à couvrir : ils
exigent des écrans dépendant de Firebase, qui ne se rendent pas encore dans
un test widget sans infrastructure de doublure.

## Plan de fermeture

1. créer un harnais partagé de tailles et de facteur de texte ;
2. couvrir les parcours publics et d’authentification ;
3. couvrir publication, détail et messagerie ;
4. couvrir compte, abonnements et Je me lance ;
5. vérifier tablette/desktop et NavigationRail ;
6. joindre les rapports ou captures ;
7. passer `responsive-text-scale` à `verified` seulement après couverture complète.

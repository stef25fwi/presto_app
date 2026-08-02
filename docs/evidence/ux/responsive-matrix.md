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

## Preuves existantes

- `test/app/presto_design_system_accessibility_test.dart` : classification des breakpoints, cible tactile et bouton essentiel à 320 px / 200 % ;
- tests utilisant `setSurfaceSize` dans plusieurs modules de messagerie, boîte à outils et administration ;
- tests de non-régression Flutter exécutés dans la CI.

Ces preuves valident la **fondation**, mais ne suffisent pas encore à déclarer le contrôle `responsive-text-scale` terminé. La clôture exige une couverture explicite des parcours du tableau ci-dessus.

## Plan de fermeture

1. créer un harnais partagé de tailles et de facteur de texte ;
2. couvrir les parcours publics et d’authentification ;
3. couvrir publication, détail et messagerie ;
4. couvrir compte, abonnements et Je me lance ;
5. vérifier tablette/desktop et NavigationRail ;
6. joindre les rapports ou captures ;
7. passer `responsive-text-scale` à `verified` seulement après couverture complète.

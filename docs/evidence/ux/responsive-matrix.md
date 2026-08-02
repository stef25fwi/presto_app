# Matrice responsive iliprestō

## Statut

- Date d’ouverture : 2026-08-02
- Point actif : 2 — UX/UI et design system
- État : matrice créée, exécution des tests en cours

## Largeurs obligatoires

| Largeur | Usage représentatif | Exigences principales |
|---:|---|---|
| 320 px | petit mobile | aucun débordement horizontal, actions principales visibles |
| 360 px | mobile Android courant | formulaires et cartes sans troncature |
| 390 px | iPhone courant | navigation, safe areas et clavier stables |
| 430 px | grand mobile | densité maîtrisée, aucune largeur fixe inutile |
| 600 px | petite tablette | adaptation navigation et grilles |
| 768 px | tablette portrait | deux colonnes uniquement lorsque pertinent |
| 1024 px | tablette paysage / petit desktop | contenu borné et hiérarchie conservée |
| 1280 px | desktop | largeur utile limitée, absence d’étirement excessif |
| 1440 px | grand desktop | marges cohérentes et lecture confortable |

## Facteurs de texte

Chaque largeur doit être contrôlée avec :

- facteur système standard ;
- texte agrandi à 150 % ;
- texte agrandi à 200 % ;
- libellés longs en français ;
- erreurs de formulaire et messages d’aide affichés.

## Parcours à tester

| Parcours | 320–430 | 600–768 | 1024–1440 | Texte 200 % | État |
|---|---|---|---|---|---|
| Pré-lancement | requis | requis | requis | requis | À tester |
| Connexion / inscription | requis | requis | requis | requis | À tester |
| Accueil / recherche | requis | requis | requis | requis | À tester |
| Détail d’annonce | requis | requis | requis | requis | À tester |
| Publication texte / voix | requis | requis | requis | requis | À tester |
| Conversation | requis | requis | requis | requis | À tester |
| Compte / abonnement | requis | requis | requis | requis | À tester |
| Je me lance | requis | requis | requis | requis | À tester |
| Administration | requis | requis | requis | requis | À tester |

## Critères d’échec

Un test est en échec si au moins un des cas suivants apparaît :

- overflow Flutter ou défilement horizontal non prévu ;
- texte coupé sans accès au contenu complet ;
- bouton ou champ inaccessible ;
- chevauchement avec clavier, safe area ou barre système ;
- grille avec cartes équivalentes de tailles incohérentes ;
- ordre visuel différent de l’ordre sémantique ;
- action principale déplacée hors de la zone visible ;
- dialogue impossible à fermer ou à faire défiler ;
- perte d’information à 200 % de taille de texte.

## Preuves attendues

Pour convertir le contrôle `responsive-text-scale` en `verified`, il faut :

1. des widget tests aux largeurs critiques ;
2. des tests de texte agrandi sur les parcours principaux ;
3. les captures ou rapports de tests manuels tablette/mobile ;
4. l’absence d’anomalie majeure ouverte ;
5. une CI Flutter verte après corrections.
#!/bin/bash
cd /workspaces/presto_app
git add lib/main.dart
git commit -m "feat: carrousel auto-animé des dernières offres (2 lignes, 8 annonces)

- Augmentation de 3 à 8 offres affichées dans Firestore query
- Carrousel horizontal auto-défilant avec animation droite vers gauche
- Séparation en 2 lignes d'offres (960px de largeur totale)
- Duplication des offres pour créer un effet de boucle infinie
- Pause du défilement au survol de la souris
- Ligne 1 : défilement continu via ScrollController
- Ligne 2 : affichage statique (alternance des offres)
- Cartes d'offres de 280px de largeur, espacement 8px
- Section 'Dernières offres' remplacée avant 'Catégories' (meilleure visibilité)
- Suppression de la méthode _labelWhenFromTitle inutilisée de _HomePageState"
git push origin main

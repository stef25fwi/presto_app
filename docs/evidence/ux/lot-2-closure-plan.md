# Lot 2 — Plan de fermeture UX/UI et accessibilité

## État réel au 4 août 2026

Trois contrôles sont `verified` : design system, contrastes approuvés et cibles tactiles. Cinq contrôles restent ouverts : clavier/focus, lecteur d’écran, responsive à 200 %, cohérence des états asynchrones et audit complet des neuf parcours.

## Ordre de correction

### 1. Clavier et focus

- navigation principale Web ;
- connexion, inscription et récupération ;
- publication et recherche ;
- dialogues, menus et bottom sheets ;
- remplacement ou encadrement des surfaces `GestureDetector` sans action clavier ;
- tests de traversée Tab, activation Entrée/Espace et restitution du focus après fermeture.

### 2. Sémantique et lecteurs d’écran

- libellés des icônes sans texte ;
- ordre de lecture ;
- états sélectionné, désactivé, chargé et en erreur ;
- exclusion des images décoratives ;
- preuves VoiceOver, TalkBack et lecteur Web.

### 3. Responsive et texte à 200 %

Exécuter les neuf parcours à 320, 360, 390, 430, 600, 768, 1024, 1280 et 1440 px. Les cellules ne passent au vert qu’en l’absence d’overflow, de contenu essentiel masqué et d’action inaccessible.

### 4. États loading, empty, error et success

- harmoniser les termes et actions de reprise ;
- supprimer les erreurs techniques visibles ;
- assurer une annonce sémantique des changements ;
- ajouter des tests widgets déterministes pour chaque parcours critique.

### 5. Certification finale

La fermeture exige les huit contrôles `verified`, `flutter analyze --fatal-infos`, la suite Flutter avec couverture, et des preuves réelles pour les lecteurs d’écran et appareils qui ne peuvent pas être simulés de manière fiable.

## Interdictions

- ne pas passer un contrôle à `verified` sur la seule présence de code ;
- ne pas réduire les largeurs, le facteur de texte ou la liste des parcours ;
- ne pas masquer un overflow ou ignorer une exception de rendu ;
- ne pas promouvoir le lot 3 avant la clôture officielle du lot 2.

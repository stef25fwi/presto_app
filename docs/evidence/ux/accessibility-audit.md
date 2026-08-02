# Audit accessibilité — point 2

## Statut

- Date d’ouverture : 2026-08-02
- Dernière mise à jour : 2026-08-02
- Portée : parcours publics, authentification, accueil, publication, recherche, conversation, compte, administration et « Je me lance »
- Référentiel : WCAG 2.2 niveau AA, usages clavier, lecteur d’écran et tailles de texte élevées
- État : audit en cours — aucun contrôle global n’est déclaré vérifié sans preuve complète

## Contrôles à certifier

| Contrôle | Méthode | Preuve attendue | État |
|---|---|---|---|
| Contrastes | Mesure texte, icônes et composants | rapport de ratios AA | En cours |
| Navigation clavier | Tabulation, activation, fermeture, focus | matrice par parcours | À tester |
| Focus visible | contrôle visuel de chaque action | captures/tests | Socle central corrigé, parcours à tester |
| Sémantique | inspection Flutter Semantics et lecteur d’écran | rapport VoiceOver/TalkBack | À tester |
| Cibles tactiles | mesure des zones interactives | audit composants | Boutons standards corrigés, widgets personnalisés à auditer |
| Texte agrandi | 200 % / facteur élevé | matrice responsive | À tester |
| États de données | loading, empty, error, success | inventaire par écran | À inventorier |
| Animations | réduction des animations | test réglage système | À tester |

## Corrections centrales appliquées

### Thème et surfaces

Le fichier `lib/app/theme.dart` constitue désormais le socle autoritaire du thème :

- police globale `Inter` ;
- bleu principal `#1A73E8` et orange de marque `#FF6600` ;
- suppression du fond beige `#FDF4EC` ;
- fond applicatif neutre `#F7F9FC` et surfaces de saisie blanches ;
- focus global bleu visible ;
- bordures d’erreur renforcées en rouge foncé ;
- SnackBar sombre avec texte blanc pour renforcer la lisibilité.

### Cibles tactiles

Le thème impose désormais une taille minimale de `48 × 48 px`, `MaterialTapTargetSize.padded` et `VisualDensity.standard` pour :

- `TextButton` ;
- `OutlinedButton` ;
- `ElevatedButton` ;
- `FilledButton` ;
- `IconButton`.

Cette correction couvre les composants Material standards. Les `GestureDetector`, `InkWell`, actions compactes et composants personnalisés restent à inventorier avant validation globale du contrôle.

### Tests automatisés

Le fichier `test/app/presto_theme_accessibility_test.dart` vérifie :

- la charte de couleurs et l’absence de l’ancien fond beige ;
- la présence d’un fond neutre et de champs blancs ;
- les tailles minimales de 48 px dans les styles du thème ;
- les dimensions réellement rendues des cinq familles de boutons ;
- la visibilité du focus et des bordures d’erreur.

## Parcours prioritaires

1. page de pré-lancement et accès interne ;
2. inscription, connexion email, Google et Apple ;
3. accueil, recherche et consultation d’annonce ;
4. publication texte et Micro IA ;
5. conversation texte, photo, fichier et audio ;
6. compte, abonnement et suppression de compte ;
7. parcours « Je me lance » et export PDF ;
8. espace administration et modération.

## Règles de preuve

Un contrôle ne passe à `verified` que lorsque :

- la correction est présente dans le code ;
- un test automatisé couvre les comportements vérifiables ;
- un test manuel sur appareil réel couvre clavier ou lecteur d’écran lorsque nécessaire ;
- les résultats sont consignés avec date, plateforme et version ;
- aucune anomalie bloquante ou majeure ne reste ouverte.

## Écarts restant ouverts

- mesurer les ratios de contraste des couleurs réellement utilisées hors thème central ;
- auditer les composants interactifs personnalisés ne bénéficiant pas des thèmes de boutons ;
- vérifier l’ordre de tabulation et le focus sur les parcours Web ;
- exécuter VoiceOver sur iOS et TalkBack sur Android ;
- tester toutes les largeurs de la matrice responsive avec texte jusqu’à 200 % ;
- inventorier les états loading, empty, error et success écran par écran ;
- vérifier la réduction des animations lorsque le système le demande.

## Prochaine passe

Inventorier les usages de `GestureDetector`, `InkWell`, `IconButton`, couleurs codées localement, contraintes fixes et textes non flexibles. Les exceptions seront corrigées par lot de parcours, puis couvertes par des widget tests responsive et sémantiques.

# Audit accessibilité — point 2

## Statut

- Date d’ouverture : 2026-08-02
- Portée : parcours publics, authentification, accueil, publication, recherche, conversation, compte, administration et « Je me lance »
- Référentiel : WCAG 2.2 niveau AA, usages clavier, lecteur d’écran et tailles de texte élevées
- État : audit ouvert — aucun contrôle n’est déclaré vérifié sans preuve d’exécution

## Contrôles à certifier

| Contrôle | Méthode | Preuve attendue | État initial |
|---|---|---|---|
| Contrastes | Mesure texte, icônes et composants | rapport de ratios AA | À mesurer |
| Navigation clavier | Tabulation, activation, fermeture, focus | matrice par parcours | À tester |
| Focus visible | contrôle visuel de chaque action | captures/tests | À tester |
| Sémantique | inspection Flutter Semantics et lecteur d’écran | rapport VoiceOver/TalkBack | À tester |
| Cibles tactiles | mesure des zones interactives | audit composants | À mesurer |
| Texte agrandi | 200 % / facteur élevé | matrice responsive | À tester |
| États de données | loading, empty, error, success | inventaire par écran | À inventorier |
| Animations | réduction des animations | test réglage système | À tester |

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

## Écarts déjà connus

- le registre `quality/accessibility_ux_readiness.json` comporte huit contrôles encore `pending` ;
- la centralisation complète du design system n’est pas encore prouvée ;
- les preuves de contraste AA, clavier, lecteur d’écran, cibles tactiles et texte à 200 % restent à produire ;
- la cohérence des états loading, empty et error doit être vérifiée écran par écran.

## Prochaine passe

La prochaine passe doit inventorier les composants centraux Flutter, relever les exceptions de tailles, couleurs et espacements, puis créer les tests et corrections par parcours. Ce document sera enrichi au fur et à mesure, sans convertir prématurément les contrôles en `verified`.
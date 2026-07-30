# Plan de correction prépublication iliprestō

Suivi principal : #1079

## Statut

- Démarré le 30 juillet 2026.
- Base : `main` après fusion du correctif Flutter 3.44.6 de la PR #1078.
- Branche active : `perf/prepublication-bootstrap-routing`.
- Règle : aucune baisse de seuil, aucun skip, aucune exclusion LCOV.

## Lot 1 — Bootstrap et routage initial

### Défauts confirmés

1. Le splash racine impose encore un délai fixe de trois secondes.
2. La détermination de la destination racine est répétée plusieurs fois.
3. `pendingPostAuthRoute` est remis à zéro à plusieurs endroits dans le même flow.
4. `LoginPage.routeName` est associé à `HomePage` dans la table des routes.
5. Le commentaire du bootstrap ne correspond plus au comportement réel.

### Résultat attendu

- premier rendu Flutter sans attente artificielle ;
- destination initiale déterminée une seule fois ;
- deep links et reprise post-auth préservés ;
- `/account`, `/publish`, messages, annonces et profils traités de façon déterministe ;
- aucune boucle splash/login/home ;
- tests widget et unitaires couvrant racine, route publique, route protégée, utilisateur connecté/déconnecté et OAuth.

### Découpage prévu

1. Extraire un résolveur de destination initiale sans dépendance UI.
2. Remplacer la minuterie de trois secondes par un bootstrap piloté par état.
3. Corriger la route de connexion.
4. Centraliser la consommation de `pendingPostAuthRoute`.
5. Ajouter les tests de non-régression.
6. Mesurer le temps de premier rendu et le bundle release.

## Lots suivants

- Réalignement et certification de la PR PDF #1060.
- Contrôles App Check, clés API, secrets et sécurité en mode strict.
- Traitement ciblé des dépendances npm vulnérables.
- Centralisation du design system et passe responsive complète.
- Découpage progressif des pages monolithiques.
- Lighthouse/Web Vitals et smoke tests sur staging.
- Certification Android/iOS sur appareils réels.

## Conditions de fusion

- `flutter analyze --fatal-infos` vert ;
- tests ciblés et suite complète verts ;
- couverture réelle mesurée ;
- aucun changement fonctionnel non documenté ;
- CI complète verte sur la PR ;
- branche réalignée sur le dernier `main` avant fusion.

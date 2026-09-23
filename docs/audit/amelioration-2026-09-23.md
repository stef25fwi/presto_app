# Plan d’amélioration IliPresto — 23 septembre 2026

Référence de départ : `e56851b6087ad28d9a100f8191955df0a6a8bb40`.

## Contrainte produit

Le hero de la page Home et ses trois affiches sont conservés intégralement,
conformément à la demande du propriétaire. Le constat D01 de l’audit ne donne
lieu à aucune modification du hero, de ses médias, de son défilement ni de son
agencement. La correction U01 dans `home_page.dart` concerne uniquement le
maintien du formulaire de publication dans les onglets déjà visités.

## Lot 1 — sécurité et continuité du brouillon

| Constat | Correction de cette branche | Validation | État |
| --- | --- | --- | --- |
| S01 | nodemailer ≥ 9.1.1, sharp ≥ 0.35.4, qs verrouillé à 6.16.0 ; audit de production sur PR/main et chaque lundi, échec sur high/critical, preuves en artefact | Audit npm : 0 vulnérabilité ; build et tests Functions réussis | Implémenté, non déployé |
| S02 | Suppression de toute création cliente de messages ; l’application conserve son envoi existant via `sendConversationMessage` | Émulateur : l’ancien payload de secours est refusé pour participants, participant bloqué et tiers, avec/sans pièce jointe ; lectures légitimes préservées | Implémenté, non déployé |
| S03 | Suppression des compteurs de clics, des callbacks de déverrouillage et du pont JavaScript ; ancien indicateur de session invalidé | 11 tests comportementaux du bootstrap réussis ; tests Flutter adaptés pour les routes et appuis répétés | Implémenté ; validation Flutter en CI |
| U01 | Publication montée au premier accès puis conservée pendant les changements d’onglet ; animations suspendues lorsque l’onglet est masqué | Nouveau test Publier → saisie → Accueil → Publier et vérification TickerMode ; diff Home limité au montage de l’onglet Publier | Implémenté ; validation Flutter en CI |

La conservation U01 couvre les changements d’onglet dans la même Home. Elle ne
constitue pas encore une sauvegarde durable après rechargement, fermeture de
l’application ou changement de compte. Les conditions de reprise et de purge
seront traitées dans le lot publication, sans stocker de données sensibles de
façon indéfinie.

La fermeture du pré-lancement concerne le mécanisme d’accès public caché, pas
une authentification de sécurité remplaçant les règles Firebase. Les canaux de
prévisualisation restent disponibles. La racine publique reste statique comme
auparavant : le futur passage à l’ouverture devra également traiter le
bootstrap web, en plus du paramétrage Remote Config. Aucune ouverture ni
modification Remote Config n’est faite dans ce lot.

## Preuves locales

- `npm audit --package-lock-only --omit=dev --audit-level=high` : réussite,
  0 vulnérabilité dans les dépendances de production.
- `npm test` dans `functions` : compilation TypeScript réussie ;
  353 tests réussis, 2 ignorés, 0 échec (Node 24 local ; Node 22 requis en CI).
- `npm run test:firestore:canonical-rules` : réussite en émulateur.
- `node --test tools/public_prelaunch_bootstrap.test.mjs` : 11/11.
- `git diff --check` : aucune erreur.
- Flutter n’est pas installé dans cet environnement local ; les nouveaux tests
  de navigation et de pré-lancement doivent être validés par la CI configurée
  avec Flutter 3.44.6 avant fusion.

## Lots suivants

| Ordre | Constats | Travail | Critère de sortie |
| --- | --- | --- | --- |
| 2 | S04, S05 | Protection de main, contrôles requis et preuves de sécurité actualisées | Fusion refusée en cas d’échec requis ; inventaire des secrets/restrictions de clés/revue OWASP étayés |
| 3 | U02, U01 | Saisie manuelle complète, IA facultative, erreurs et reprise de brouillon | Publication de test avec/sans IA et sans perte de saisie |
| 4 | U03, U04, U05 | Pagination filtrée, combinaisons utiles et compteur cohérent | Correspondance après la 100e annonce trouvée ; nombre de résultats exact |
| 5 | S06 | États canoniques des anciennes annonces | Documents retirés/archivés refusés malgré d’anciens drapeaux publics |
| 6 | D02, D03, D04 | Cartes de pré-lancement, vraies fontes et accessibilité | Grilles équilibrées, fontes valides, matrice clavier/lecteur d’écran/mobile |
| 7 | P01, P02, P03 | Démarrage Flutter mesuré, données terrain, pages légales légères | Mesures séparées vitrine/application, échantillons suffisants, contenu légal accessible |
| 8 | Q01 | Tests de parcours et critères d’ouverture | Parcours connectés représentatifs et preuves sur le SHA à livrer |
| Exclu | D01 | Refonte du hero Home | Les trois affiches et leur présentation restent inchangées |

## Conditions de livraison du lot 1

La première validation complète sur `185de1fe` a réussi l'analyse Flutter,
les seuils qualité et couverture, les tests Functions et Firestore, le build
web et le budget bundle. La suite Flutter a signalé un seul échec : le nouveau
test U01 tentait de saisir dans la description encore en lecture seule, sans
le clic utilisateur qui active son édition. Le scénario est corrigé et
vérifie désormais le texte avant de quitter, pendant le masquage et au retour,
ainsi que l'identité de l'état et du contrôleur. Sa nouvelle CI reste requise.

Obtenir les résultats de la CI sur le SHA exact, vérifier les éventuels
correctifs générés automatiquement et confirmer le build web. Déployer les
règles Firestore et le code de façon cohérente lors d’une livraison autorisée.
Ne pas présenter les modifications de branche comme déjà actives en production.

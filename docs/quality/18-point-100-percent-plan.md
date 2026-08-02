# Plan séquentiel iliprestō — atteindre 100 % sur les 18 points

## Objectif

Faire passer iliprestō de son niveau actuel à un état entièrement vérifié sur les 18 lots de reconstruction et de préparation au lancement, sans ouvrir officiellement un nouveau lot avant la clôture du précédent.

Le programme est piloté par :

- `quality/18-point-completion.json` : registre autoritaire des 18 lots ;
- `tools/quality/check_18_point_completion.mjs` : moteur de validation et de promotion ;
- `.github/workflows/18-point-supervisor.yml` : agent GitHub Actions de surveillance ;
- une issue GitHub unique mise à jour par l’agent avec le point actif, les preuves manquantes et les contrôles restant à fermer.

## Règle absolue de séquence

À tout moment :

1. tous les points antérieurs au point actif doivent être `verified` ;
2. exactement un point peut être `active` ;
3. tous les points suivants doivent rester `blocked` ;
4. un point ne peut passer à `verified` que si toutes ses preuves existent, tous ses contrôles obligatoires ont un statut accepté et toutes ses commandes de validation réussissent ;
5. la promotion est préparée dans une PR dédiée ; le point suivant ne devient actif sur `main` qu’après fusion de cette PR.

La présence préalable de code dans un point futur est conservée comme acquis technique, mais elle ne vaut pas validation officielle et ne permet pas de sauter l’ordre.

## Fonctionnement de l’agent

### Surveillance automatique

L’agent s’exécute :

- quotidiennement ;
- après une modification du registre, des preuves ou des fichiers de gouvernance ;
- sur les PR qui modifient le dispositif ;
- manuellement en mode `monitor`.

Il vérifie la séquence, exécute les tests de son propre moteur, produit un rapport Markdown, archive ce rapport pendant 90 jours et crée ou met à jour l’issue `[Agent 18/18] Supervision séquentielle iliprestō`.

### Promotion contrôlée

Le mode manuel `advance` :

1. relit le point actif depuis `main` ;
2. prépare l’environnement demandé (`docs`, `node`, `flutter`, `full` ou `mobile`) ;
3. vérifie toutes les preuves ;
4. vérifie tous les registres de contrôle ;
5. exécute toutes les commandes de validation ;
6. refuse l’avancement à la première preuve absente ou au premier échec ;
7. en cas de succès, crée une branche et une PR qui passe le point actif à `verified` et le point suivant à `active`.

L’agent ne fusionne pas silencieusement la PR de promotion. La fusion reste le dernier acte de contrôle et rend l’avancement officiel.

## Plan des 18 lots

| Ordre | Lot | Baseline | Travaux nécessaires pour atteindre 100 % | Preuve de clôture principale |
|---:|---|---:|---|---|
| 1 | Cadrage produit | 85 % | Figer personas, rôles, modèle bêta/commercial, périmètre de release, exclusions et KPI. | `quality/product-readiness.json` à 100 % `verified` |
| 2 | UX/UI et design system | 68 % | Centraliser le design system, certifier responsive, contrastes, focus, lecteur d’écran, cibles tactiles et texte agrandi. | `quality/accessibility_ux_readiness.json` entièrement `verified` |
| 3 | Architecture technique | 75 % | Fermer la dette P0, découper les écrans critiques, clarifier repositories/controllers et documenter tous les flux. | `quality/architecture-readiness.json` entièrement `verified` |
| 4 | Socle Flutter multiplateforme | 75 % | Produire des builds Web, Android et iOS reproductibles, certifier navigation, démarrage et reprise. | `quality/flutter-platform-readiness.json` entièrement `verified` |
| 5 | Comptes et authentification | 82 % | Certifier email, Google, Apple, récupération, suppression, rôles, OTP et App Check sur les plateformes concernées. | `quality/auth-readiness.json` entièrement `verified` |
| 6 | Marketplace d’annonces | 87 % | Certifier brouillon, médias, publication, modération, recherche, pagination, favoris, contacts, avis et quotas. | `quality/marketplace-readiness.json` entièrement `verified` |
| 7 | Messagerie complète | 82 % | Certifier texte, photos, fichiers, audio, plein écran, watermark, suppression, blocage, signalement et push réel. | `quality/messaging-readiness.json` entièrement `verified` |
| 8 | Fonctions IA | 88 % | Fermer évaluations qualité/coût/latence, smoke production, observabilité et test du rollback Remote Config. | `quality/ai-readiness.json` entièrement `verified` |
| 9 | Administration et modération | 82 % | Certifier matrice des rôles, actions serveur, journaux, modération et maintenabilité des écrans admin. | `quality/admin-readiness.json` entièrement `verified` |
| 10 | Parcours « Je me lance » | 87 % | Auditer toutes les fiches, liens, contenus, étapes, progression, absence de doublons et exports PDF. | `quality/guided-journey-readiness.json` entièrement `verified` |
| 11 | Paiements et abonnements | 90 % | Ajouter le test avec utilisateur Firebase réel, certifier alertes et décider puis appliquer la politique de paiement mobile. | Stripe 7/7 maintenu et preuves complémentaires présentes |
| 12 | Sécurité et conformité | 62 % | Produire les sept preuves externes : App Check, restrictions API, secrets, dépendances et OWASP ; clôturer RGPD. | `quality/security-controls.json` 9/9 `verified` |
| 13 | Tests et qualité | 74 % | Atteindre LCOV 70 % global, 85 % modules critiques et 90 % paiements/droits, sans skip ni exclusion artificielle. | `quality/testing-readiness.json` entièrement `verified` |
| 14 | CI/CD et déploiement | 82 % | Créer staging, certifier le rollback, les smoke tests fonctionnels, les artefacts, statuts et alertes. | `quality/cicd-readiness.json` entièrement `verified` |
| 15 | SEO et pré-lancement | 93 % | Prouver indexation, données structurées, routes publiques, pages légales et bascule sans double rendu. | `quality/seo-readiness.json` entièrement `verified` |
| 16 | Publication mobile | 50 % | Produire et tester AAB/IPA, configurer signatures, Play Integrity, App Check, deep links, push, stores et appareils réels. | `quality/mobile_readiness.json` 8/8 `verified` |
| 17 | Gestion de projet | 75 % | Formaliser responsabilités, backlog, politique des branches/PR, releases, support et incidents. | `quality/project-governance-readiness.json` entièrement `verified` |
| 18 | Stabilisation avant lancement | 70 % | Figer la release candidate, exécuter smoke tests et rollback, activer monitoring/alertes et obtenir les approbations finales. | `quality/production_go_live_readiness.json` 10/10 `verified` |

## Méthode de travail pour chaque lot

Chaque lot suit le même cycle :

### 1. Constater

- mesurer le niveau réel ;
- relever les écarts ;
- relier chaque écart à un contrôle du registre du lot ;
- ne pas déclarer un contrôle terminé sur la seule présence du code.

### 2. Corriger

- créer des PR limitées au lot actif ;
- inclure les tests de non-régression ;
- mettre à jour la documentation et les preuves dans la même PR ;
- ne pas réduire les seuils pour rendre la CI verte.

### 3. Vérifier

- exécuter les commandes définies dans le registre central ;
- produire les preuves externes lorsque la console Firebase, GCP, Stripe, Play ou Apple est nécessaire ;
- convertir chaque contrôle `pending` ou `implemented` en `verified` seulement après constat réel.

### 4. Promouvoir

- déclencher `18-Point Sequential Supervisor` avec l’action `advance` ;
- laisser l’agent refuser l’avancement si une condition manque ;
- examiner puis fusionner la PR de promotion ;
- commencer officiellement le point suivant seulement après cette fusion.

## Critère final du programme

Le programme est terminé uniquement lorsque :

- les 18 points sont `verified` ;
- aucun point n’est `active` ou `blocked` ;
- toutes les commandes du point 18 passent ;
- le registre go-live est intégralement vérifié ;
- la dernière release candidate est déployable, observable et réversible ;
- l’issue de suivi affiche `18/18 points verified`.

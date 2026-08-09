# Phase 2 — SEO Programmatique Local

Objectif : construire une surface SEO locale capable de croître avec l’activité réelle d’iliprestō sans créer de pages satellites faibles.

## Architecture pilote

Deux intentions sont générées pour chaque combinaison :

- `/services/{service}/{ville}/` pour les demandeurs ;
- `/missions/{service}/{ville}/` pour les personnes qui recherchent des besoins correspondant à leurs compétences.

Pilote initial :

- services : bricolage, jardinage, aide au déménagement / manutention ;
- villes : Les Abymes, Baie-Mahault, Pointe-à-Pitre, Fort-de-France, Le Lamentin (Martinique), Cayenne ;
- total : 3 × 6 × 2 = 36 pages générables.

## SEO Activation Gate

Une URL locale existe techniquement mais reste `noindex,follow` tant que les données réelles ne franchissent pas les seuils suivants :

- au moins 3 entités réelles agrégées ;
- au moins 1 entité récente sur la fenêtre de 90 jours ;
- introduction locale unique ;
- maillage interne présent.

Le sitemap local contient uniquement les pages ayant franchi le gate. Une page `noindex` ne doit jamais être ajoutée à `sitemap-local.xml`.

## Données de production

Le collecteur `functions/scripts/generate_programmatic_seo_signals.mjs` lit uniquement des champs nécessaires des annonces `listings` ayant simultanément :

- `status == active` ;
- `visibility == public`.

Les champs texte privés, téléphone, médias et contenu de conversation ne sont pas lus. Les signaux utilisés sont des compteurs agrégés par catégorie et ville.

Le collecteur fonctionne en mode fail-safe : si Firestore est indisponible ou si le compte de déploiement ne peut pas lire les agrégats nécessaires, le fichier de signaux revient à un état non daté et toutes les pages restent `noindex`.

## Pipeline

1. Génération locale avec les signaux neutres du dépôt.
2. Quality gate SEO programmatique.
3. Authentification WIF et installation des dépendances Functions.
4. Agrégation des annonces publiques réelles depuis Firestore production.
5. Régénération des pages et du sitemap local.
6. Nouveau quality gate.
7. `flutter build web`.
8. Déploiement Firebase Hosting.
9. Smoke test d’une URL pilote et de `sitemap-local.xml`.

## Garde-fous

- aucune donnée structurée `JobPosting` sur les missions de services ;
- aucune promesse d’emploi, revenu, mission ou délai de réponse ;
- pas de page indexable sans données réelles ;
- pas de publication de la source interne de signaux dans Hosting ;
- les profils ne comptent pas encore dans l’activation tant que les champs publics et le consentement n’ont pas été audités.

## Suite de la Phase 2

1. Auditer le modèle des profils publics et brancher `qualifiedProfiles` / `recentProfiles`.
2. Créer des URLs publiques SEO pour les annonces réellement publiques.
3. Créer des pages publiques de profils avec `ProfilePage` lorsque le consentement et les règles produit le permettent.
4. Ajouter les sous-services à fort potentiel (montage de meubles, tonte, débroussaillage, manutention, etc.).
5. Étendre progressivement les villes uniquement lorsque les signaux locaux sont suffisants.
6. Mesurer impressions, clics, CTR, positions et indexation par cluster dans Search Console.

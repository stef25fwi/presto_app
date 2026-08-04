# Point 6 SEO — Suivi, analyse et amélioration continue

## Objectif

Le suivi SEO d’iliprestō détecte les régressions techniques, mesure la visibilité organique et transforme les données en actions vérifiables. Le positionnement général reste national ; les analyses territoriales concernent uniquement les pages locales.

## Sources de données

### Contrôle direct de la production

`tools/seo/monitor_public_seo.mjs` contrôle chaque jour les douze URL indexables déclarées dans `config/seo-monitoring.json` et présentes dans le sitemap national :

- statut HTTP, domaine final et temps de réponse ;
- title, meta description, canonical, H1 et robots ;
- données structurées ;
- registre des routes publiques dynamiques ;
- `robots.txt`, `sitemap.xml` et présence de chaque URL canonique.

Les deux pages éditoriales `/trouver-une-personne-disponible/` et `/guides/creer-micro-entreprise-services/` font partie du contrôle. La page historique `/services-outre-mer/`, retirée du sitemap national, n’est pas comptée comme URL indexable à surveiller.

Pour les pages légales enrichies au chargement par `public-route-seo.js`, le contrôle ne recherche pas une URL complète écrite en dur. Il vérifie quatre éléments : la route déclarée, le domaine de base officiel, la construction `baseUrl + path` et l’application du canonical au DOM, à Open Graph et au JSON-LD. Cette méthode évite les faux positifs tout en conservant une preuve réelle du contrat SEO.

Une indisponibilité, un `noindex`, un canonical incorrect, un H1 manquant ou une URL absente du sitemap est une régression bloquante.

### Search Console

Le connecteur Search Console compare deux périodes consécutives de 28 jours, avec trois jours de décalage de consolidation. Il suit clics, impressions, CTR, position moyenne, principales requêtes, principales pages et appareils. La propriété attendue est `sc-domain:ilipresto.fr`.

### Google Analytics 4

Le connecteur GA4 part du measurement ID Firebase `G-NT4PEHQ3CJ`, retrouve automatiquement la propriété visible par le compte Google et limite l’analyse au canal `Organic Search`. Il suit sessions, engagement, pages d’entrée et événements clés : inscription, première valeur, contact, sélection de plan et paiement confirmé.

Les événements Analytics restent conditionnés au consentement. Aucun email, téléphone, nom, adresse, texte libre, jeton ou identifiant utilisateur brut ne doit être envoyé.

## Configuration GitHub et Google

Le workflow réutilise la fédération d’identité configurée dans l’environnement GitHub `recaptcha` :

1. `WIF_PROVIDER` désigne le fournisseur Workload Identity Federation ;
2. `WIF_SERVICE_ACCOUNT` désigne le compte de service Google impersonné ;
3. GitHub crée un jeton OAuth court limité aux besoins du contrôle ;
4. le workflow tente d’activer dans `presto-app-74abe` les API `searchconsole.googleapis.com`, `analyticsadmin.googleapis.com` et `analyticsdata.googleapis.com` ;
5. aucune clé privée longue durée n’est ajoutée au dépôt ou aux nouveaux secrets.

Le compte impersonné doit disposer du droit Google Cloud permettant d’activer les services requis, d’un accès en lecture à la propriété Search Console `sc-domain:ilipresto.fr` et d’un rôle de lecture sur la propriété GA4. Les droits Search Console et GA4 sont propres à ces produits : un rôle Google Cloud sur le projet ne les remplace pas.

La variable facultative `SEO_GA4_PROPERTY_ID` peut forcer une propriété numérique. Sans cette variable, le connecteur la retrouve depuis `G-NT4PEHQ3CJ`. Le fallback local `SEO_GOOGLE_SERVICE_ACCOUNT_JSON` reste accepté pour un diagnostic ponctuel, mais ne doit pas être utilisé dans la CI normale.

## Déclenchement

Le workflow `SEO continuous monitoring` s’exécute :

- chaque jour à 06:17 en Guadeloupe ;
- immédiatement après une fusion dans `main` touchant le suivi, le sitemap ou le registre public ;
- manuellement avec possibilité d’exiger ou non les données externes.

Une issue unique intitulée `[SEO] Alerte de suivi continu iliprestō` est ouverte ou mise à jour lorsqu’une régression apparaît. Elle est fermée automatiquement après retour à la normale.

## Seuils et faux positifs

Les seuils sont centralisés dans `config/seo-monitoring.json`. Une alerte de tendance n’est déclenchée qu’au-dessus d’un volume précédent minimum.

Valeurs initiales : disponibilité 100 %, avertissement de réponse au-delà de 3 500 ms, recul de 20 % des clics/impressions/sessions/conversions, perte de CTR de 1 point et perte moyenne de 3 positions. Les seuils ne doivent pas être abaissés uniquement pour masquer une alerte.

## Revue hebdomadaire

Chaque semaine :

1. vérifier le dernier rapport et l’issue d’alerte ;
2. comparer requêtes et pages gagnantes ou perdues ;
3. contrôler les pages à fortes impressions et faible CTR ;
4. comparer clics Search Console et sessions organiques GA4 ;
5. prioriser au maximum trois corrections mesurables ;
6. documenter page, hypothèse, indicateur attendu et date de relecture.

Les modifications de title, meta description ou contenu doivent préserver le positionnement national. Les termes géographiques sont réservés aux pages régionales.

## Revue mensuelle

Chaque mois :

1. comparer les deux dernières périodes de 28 jours ;
2. examiner visibilité, acquisition, activation et contact organiques ;
3. classer les améliorations comme efficaces, neutres, incomplètes ou à annuler ;
4. vérifier la couverture du sitemap ;
5. créer le backlog du mois suivant avec responsable et mesure de succès ;
6. archiver les décisions dans la PR ou l’issue liée.

Une hausse de trafic sans activation ni contact n’est pas une réussite complète.

## Preuves produites

Chaque exécution produit `seo-monitoring-report.json`, `seo-monitoring-report.md` et un artefact conservé 90 jours. Le résumé affiche séparément l’état du site, l’authentification Google et l’activation des API afin de distinguer une régression SEO d’un problème de droits ou de configuration externe.

## Commandes locales

Validation hors réseau :

```bash
node tools/quality/check_seo_monitoring_readiness.test.mjs
node tools/seo/runtime_seo_registry_contract.test.mjs
```

Contrôle public :

```bash
node tools/seo/monitor_public_seo.mjs --enforce
```

Rapport complet avec un jeton OAuth temporaire :

```bash
SEO_GOOGLE_ACCESS_TOKEN="$(gcloud auth print-access-token)" \
node tools/seo/build_seo_monitoring_report.mjs \
  --require-external-data \
  --enforce
```

Fallback local exceptionnel :

```bash
SEO_GOOGLE_SERVICE_ACCOUNT_JSON="$(cat service-account.json)" \
node tools/seo/build_seo_monitoring_report.mjs --require-external-data --enforce
```

Tout fichier de compte de service doit rester hors du dépôt et être supprimé après usage.

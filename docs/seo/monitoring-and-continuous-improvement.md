# Point 6 SEO — Suivi, analyse et amélioration continue

## Objectif

Le suivi SEO d’iliprestō détecte les régressions techniques, mesure la visibilité organique et transforme les données en actions vérifiables. Le positionnement général reste national ; les analyses territoriales concernent uniquement les pages locales.

## Sources de données

### Contrôle direct de la production

`tools/seo/monitor_public_seo.mjs` contrôle chaque jour les dix URL publiques déclarées dans `config/seo-monitoring.json` :

- statut HTTP, domaine final et temps de réponse ;
- title, meta description, canonical, H1 et robots ;
- données structurées ;
- registre des routes publiques dynamiques ;
- `robots.txt`, `sitemap.xml` et présence de chaque URL canonique.

Une indisponibilité, un `noindex`, un canonical incorrect, un H1 manquant ou une URL absente du sitemap est une régression bloquante.

### Search Console

Le connecteur Search Console compare deux périodes consécutives de 28 jours, avec trois jours de décalage de consolidation. Il suit clics, impressions, CTR, position moyenne, principales requêtes, principales pages et appareils. La propriété attendue est `sc-domain:ilipresto.fr`.

### Google Analytics 4

Le connecteur GA4 part du measurement ID Firebase `G-NT4PEHQ3CJ`, retrouve automatiquement la propriété visible par le compte Google et limite l’analyse au canal `Organic Search`. Il suit sessions, engagement, pages d’entrée et événements clés : inscription, première valeur, contact, sélection de plan et paiement confirmé.

Les événements Analytics restent conditionnés au consentement. Aucun email, téléphone, nom, adresse, texte libre, jeton ou identifiant utilisateur brut ne doit être envoyé.

## Configuration GitHub

Le workflow réutilise la fédération d’identité déjà configurée dans l’environnement GitHub `recaptcha` :

1. `WIF_PROVIDER` désigne le fournisseur Workload Identity Federation ;
2. `WIF_SERVICE_ACCOUNT` désigne le compte de service Google impersonné ;
3. ce compte reçoit uniquement un accès en lecture à la propriété Search Console `sc-domain:ilipresto.fr` et à la propriété GA4 ;
4. GitHub crée à chaque exécution un jeton OAuth court limité aux scopes `webmasters.readonly` et `analytics.readonly` ;
5. aucune clé privée longue durée n’est ajoutée au dépôt ou aux nouveaux secrets.

La variable facultative `SEO_GA4_PROPERTY_ID` peut forcer une propriété numérique. Sans cette variable, le connecteur la retrouve depuis `G-NT4PEHQ3CJ`. Le fallback local `SEO_GOOGLE_SERVICE_ACCOUNT_JSON` reste accepté pour un diagnostic ponctuel, mais ne doit pas être utilisé dans la CI normale.

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

## Alertes automatiques

Le workflow `SEO continuous monitoring` s’exécute quotidiennement à 06:17 en Guadeloupe. Il produit `seo-monitoring-report.json`, `seo-monitoring-report.md` et une issue unique intitulée `[SEO] Alerte de suivi continu iliprestō` en cas de régression. L’issue est mise à jour plutôt que dupliquée, puis fermée automatiquement après retour à la normale.

Chaque exécution est rattachée au SHA contrôlé afin que les métriques Search Console, GA4 et les vérifications de production restent auditables.

## Commandes locales

Validation hors réseau :

```bash
node tools/quality/check_seo_monitoring_readiness.test.mjs
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

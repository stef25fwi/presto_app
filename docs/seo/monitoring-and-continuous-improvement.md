# Point 6 SEO — Suivi, analyse et amélioration continue

## Objectif

Le suivi SEO d’iliprestō doit détecter rapidement une régression technique, mesurer l’évolution de la visibilité organique et transformer les données en actions vérifiables. Le positionnement général reste national. Les analyses territoriales servent uniquement les pages locales correspondantes.

## Sources de données

### Contrôle direct de la production

Le script `tools/seo/monitor_public_seo.mjs` contrôle quotidiennement les dix URL publiques déclarées dans `config/seo-monitoring.json` :

- statut HTTP et domaine final ;
- temps de réponse ;
- title, meta description, canonical, H1 et robots ;
- présence des données structurées ;
- cohérence du registre des routes publiques dynamiques ;
- disponibilité de `robots.txt` et `sitemap.xml` ;
- présence de chaque URL canonique dans le sitemap.

Une indisponibilité, un `noindex`, un canonical incorrect, un H1 manquant ou une URL absente du sitemap constitue une régression bloquante.

### Search Console

Le connecteur Search Console compare deux périodes consécutives de 28 jours, avec trois jours de décalage afin de limiter l’effet du retard de consolidation des données. Il suit :

- clics ;
- impressions ;
- CTR ;
- position moyenne ;
- principales requêtes ;
- principales pages ;
- répartition par appareil.

La propriété attendue est `sc-domain:ilipresto.fr`.

### Google Analytics 4

Le connecteur GA4 utilise le measurement ID déjà déclaré par Firebase, `G-NT4PEHQ3CJ`. Il limite l’analyse au canal `Organic Search` et suit :

- sessions ;
- sessions engagées ;
- taux d’engagement ;
- pages d’entrée ;
- événements clés du tunnel organique : inscription, première valeur, contact, sélection de plan et paiement confirmé.

Les événements Analytics restent conditionnés au consentement de l’utilisateur. Aucun email, téléphone, nom, adresse, texte libre, jeton ou identifiant utilisateur brut ne doit être envoyé.

## Configuration GitHub

Le workflow fonctionne immédiatement pour les contrôles publics sans secret. Les données réelles Search Console et GA4 nécessitent :

1. un compte de service Google disposant d’un accès en lecture à la propriété Search Console et d’un rôle de lecture sur la propriété GA4 ;
2. un secret GitHub nommé `SEO_GOOGLE_SERVICE_ACCOUNT_JSON`, contenant le JSON complet du compte de service ;
3. une variable GitHub nommée `SEO_GA4_PROPERTY_ID`, contenant uniquement l’identifiant numérique de la propriété GA4 ;
4. aucune clé privée, aucun jeton et aucun identifiant sensible dans le dépôt.

Le compte de service ne doit recevoir aucun droit d’écriture. La propriété GA4 n’est pas le measurement ID : la variable doit contenir l’identifiant numérique visible dans l’administration GA4.

## Seuils et faux positifs

Les seuils sont centralisés dans `config/seo-monitoring.json`. Les alertes de tendance ne sont déclenchées qu’au-dessus d’un volume précédent minimum. Cette règle évite de considérer comme critique une variation importante portant sur quelques clics ou sessions seulement.

Valeurs initiales :

- disponibilité des pages : 100 % ;
- réponse publique : avertissement au-delà de 3 500 ms ;
- recul des clics ou impressions : 20 % ;
- recul du CTR : 1 point ;
- perte de position moyenne : 3 positions ;
- recul des sessions ou événements clés organiques : 20 %.

Ces seuils doivent évoluer avec le volume réel du site, sans être abaissés uniquement pour masquer une alerte.

## Revue hebdomadaire

Chaque semaine :

1. vérifier le rapport quotidien le plus récent et les éventuelles issues ouvertes ;
2. comparer les requêtes et pages gagnantes ou perdantes ;
3. contrôler les pages à fortes impressions et faible CTR ;
4. vérifier les écarts entre clics Search Console et sessions organiques GA4 ;
5. prioriser au maximum trois corrections mesurables ;
6. documenter pour chaque correction la page, l’hypothèse, l’indicateur attendu et la date de relecture.

Les changements de title, meta description ou contenu doivent préserver le positionnement national de la page d’accueil. Les termes géographiques sont réservés aux pages régionales.

## Revue mensuelle

Chaque mois :

1. comparer les deux dernières périodes de 28 jours ;
2. examiner visibilité, acquisition, activation et contact issus du trafic organique ;
3. classer les améliorations terminées, efficaces, neutres ou à annuler ;
4. vérifier la couverture du sitemap et les pages réellement utiles ;
5. créer le backlog du mois suivant avec un responsable et une mesure de succès ;
6. archiver les décisions dans la PR ou l’issue liée.

Une amélioration est considérée comme validée uniquement après mesure. Une hausse de trafic sans activation ni contact n’est pas une réussite complète.

## Alertes automatiques

Le workflow `SEO continuous monitoring` s’exécute chaque jour. Il génère :

- `seo-monitoring-report.json`, exploitable par une machine ;
- `seo-monitoring-report.md`, lisible dans le résumé GitHub Actions ;
- une issue unique intitulée `[SEO] Alerte de suivi continu iliprestō` lorsqu’une régression est détectée.

L’issue est mise à jour plutôt que dupliquée. Elle est commentée puis fermée automatiquement lorsque le rapport redevient sain.

## Commandes locales

Validation hors réseau :

```bash
node tools/quality/check_seo_monitoring_readiness.test.mjs
```

Contrôle des pages publiques :

```bash
node tools/seo/monitor_public_seo.mjs --enforce
```

Rapport complet, avec données externes obligatoires :

```bash
SEO_GOOGLE_SERVICE_ACCOUNT_JSON="$(cat service-account.json)" \
SEO_GA4_PROPERTY_ID="123456789" \
node tools/seo/build_seo_monitoring_report.mjs \
  --require-external-data \
  --enforce
```

Le fichier de compte de service doit rester hors du dépôt et être supprimé de l’environnement local après usage.

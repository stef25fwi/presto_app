# Lot 15 — Search Console automatisée

## Objectif

Produire chaque jour une preuve Search Console indépendante de GA4 pour `ilipresto.fr` :

- authentification GitHub Actions par Workload Identity Federation ;
- aucune clé de service longue durée ;
- découverte des propriétés réellement accessibles ;
- préférence pour `sc-domain:ilipresto.fr` ;
- repli automatique vers `https://ilipresto.fr/` si seule la propriété URL est partagée ;
- collecte des clics, impressions, CTR, position moyenne, requêtes, pages et appareils ;
- comparaison des 28 derniers jours avec les 28 jours précédents ;
- artefact conservé 90 jours ;
- statut GitHub `quality/search-console-lot15`.

Une période à zéro clic et zéro impression est un résultat valide. La certification porte sur l’accès réel à l’API et à la propriété, pas sur un volume artificiel de trafic.

## Blocage constaté le 6 août 2026

Le jeton WIF est correctement généré, mais Google répond :

`Google Search Console API has not been used in project 151421230024 before or it is disabled.`

Le compte de service WIF ne dispose pas de `serviceusage.services.enable`. Le workflow ne tente donc plus d’activer les API à chaque exécution.

## Action Google Cloud unique

Un propriétaire du projet Google Cloud `151421230024` doit activer :

`searchconsole.googleapis.com`

Exemple avec un compte autorisé :

```bash
gcloud services enable searchconsole.googleapis.com \
  --project=presto-app-74abe
```

Cette commande n’est exécutée qu’une seule fois. Elle ne doit pas être intégrée au workflow quotidien.

## Autorisation Search Console

Dans Search Console, ouvrir la propriété `sc-domain:ilipresto.fr`, puis ajouter l’adresse du compte de service référencé par le secret GitHub `WIF_SERVICE_ACCOUNT` avec au minimum un accès complet.

Le workflow liste d’abord les propriétés accessibles. Il distingue ensuite :

- `api_disabled` : API non activée dans Google Cloud ;
- `authentication_failed` : problème WIF ou jeton expiré ;
- `permission_denied` : droits Google insuffisants ;
- `property_not_granted` : aucune propriété ilipresto.fr partagée avec le compte ;
- `available` : requêtes Search Analytics exécutées avec succès.

## Certification

Le lot 15 passe à `complete` lorsque :

1. le workflow `Search Console lot 15` termine avec succès ;
2. le statut `quality/search-console-lot15` est vert sur `main` ;
3. la propriété utilisée correspond à `ilipresto.fr` ;
4. l’artefact contient les périodes actuelle et précédente ;
5. le rapport est généré avec un jeton WIF de courte durée ;
6. le registre qualité référence le SHA et le run certifiés.

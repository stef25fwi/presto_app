# Lot 14 — Core Web Vitals réels

## Objectif

Mesurer en production les trois Core Web Vitals sur des navigations réelles :

- **LCP** : seuil bon à 2 500 ms ;
- **INP** : seuil bon à 200 ms ;
- **CLS** : seuil bon à 0,1.

La décision est prise au **75e centile**, séparément pour les appareils mobiles et desktop, sur une fenêtre glissante de 28 jours.

## Architecture

1. `web/web-vitals-rum.js` utilise uniquement `PerformanceObserver` dans le navigateur.
2. Le script est injecté dans toutes les pages HTML produites par le build Web.
3. Les métriques sont envoyées à `collectWebVitals` dans `europe-west1`.
4. Les échantillons anonymes sont conservés 35 jours dans `web_vitals_samples`.
5. `aggregateWebVitals28Days` produit chaque jour `web_vitals_reports/latest` et une preuve datée.
6. Le workflow `Core Web Vitals field report` exporte le rapport, conserve l’artefact 90 jours et publie le statut GitHub `quality/core-web-vitals-field`.

## Données collectées

- métrique : LCP, INP ou CLS ;
- valeur et classement technique ;
- catégorie mobile ou desktop ;
- route normalisée, sans paramètres et avec identifiants remplacés par `:id` ;
- type de navigation ;
- SHA de la version déployée lorsqu’il est disponible ;
- date de collecte ;
- identifiant aléatoire de page vue, immédiatement transformé en hash de document côté serveur.

Aucun nom, email, identifiant de compte, contenu saisi, cookie publicitaire ou adresse IP n’est enregistré. L’adresse IP sert uniquement à une limitation de débit en mémoire et n’est jamais écrite en base.

## Opposition et exclusions

La collecte ne démarre pas lorsque :

- `Do Not Track` est actif ;
- `Global Privacy Control` est actif ;
- le navigateur est piloté par une automatisation ou Lighthouse ;
- l’utilisateur a refusé les analytics dans l’application ;
- l’utilisateur a utilisé le bouton d’opposition sur `/confidentialite`.

Le stockage local `ilipresto-cwv-optout=1` sert uniquement à mémoriser cette opposition et ne contient aucun identifiant.

## Règle de certification

Le registre reste `pending` tant que l’une des conditions suivantes n’est pas remplie :

- au moins 75 échantillons par métrique sur mobile ;
- au moins 75 échantillons par métrique sur desktop ;
- LCP p75 ≤ 2 500 ms sur les deux catégories ;
- INP p75 ≤ 200 ms sur les deux catégories ;
- CLS p75 ≤ 0,1 sur les deux catégories ;
- rapport quotidien âgé de moins de 36 heures.

Aucune donnée synthétique Lighthouse ne peut faire progresser ce volume. Le lot passe à `complete` uniquement à partir du rapport terrain archivé et relié aux versions réellement déployées.

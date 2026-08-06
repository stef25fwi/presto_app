# Lot 16 — GA4 Organic Search

## Objectif

Mesurer chaque jour le trafic issu du canal `Organic Search` dans GA4, indépendamment du workflow Search Console du lot 15.

Le rapport compare les 28 derniers jours disponibles aux 28 jours précédents avec un décalage de trois jours afin de respecter la latence des données Google Analytics.

## Mesures archivées

- sessions organiques ;
- sessions engagées et taux d’engagement ;
- événements clés organiques ;
- dix principales landing pages ;
- événements de conversion configurés ;
- évolution entre les deux périodes.

Une période à zéro session est un résultat valide lorsque l’accès à la propriété et la requête Analytics Data API réussissent.

## Authentification

Le workflow `.github/workflows/ga4-organic-lot16.yml` utilise Workload Identity Federation avec :

- `WIF_PROVIDER` ;
- `WIF_SERVICE_ACCOUNT` ;
- le scope `https://www.googleapis.com/auth/analytics.readonly`.

Aucune clé JSON longue durée n’est nécessaire.

## Préparation Google Cloud

Les API suivantes doivent être activées une seule fois dans le projet `presto-app-74abe` :

```bash
gcloud services enable \
  analyticsdata.googleapis.com \
  analyticsadmin.googleapis.com \
  --project=presto-app-74abe
```

## Accès à la propriété GA4

Dans Google Analytics :

1. ouvrir **Administration** ;
2. sélectionner la propriété contenant le flux Web `G-NT4PEHQ3CJ` ;
3. ouvrir **Gestion des accès à la propriété** ;
4. ajouter `github-firebase-deploy@presto-app-74abe.iam.gserviceaccount.com` ;
5. lui attribuer le rôle **Lecteur**.

Le workflow découvre automatiquement la propriété à partir du Measurement ID. La variable d’environnement GitHub `SEO_GA4_PROPERTY_ID` peut aussi contenir directement l’identifiant numérique de la propriété.

## Preuves

Le workflow publie :

- le statut `quality/ga4-organic-lot16` sur le SHA contrôlé ;
- un rapport JSON et Markdown ;
- un artefact conservé 90 jours ;
- une issue `[SEO lot 16] GA4 Organic Search` lorsqu’une action est requise.

L’issue est fermée automatiquement dès qu’une requête GA4 réelle réussit.

## Certification

Le lot passe à `complete` uniquement après :

1. authentification WIF réussie ;
2. accès à la propriété GA4 confirmé ;
3. requête Analytics Data API réussie ;
4. rapport réel archivé ;
5. statut `quality/ga4-organic-lot16` vert.

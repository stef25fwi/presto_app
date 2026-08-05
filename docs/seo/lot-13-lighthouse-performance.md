# Lot 13 — Baseline Lighthouse Performance

## Objectif

Produire une preuve Lighthouse reproductible, liée au SHA réellement déployé sur `https://ilipresto.fr`, avec rapports HTML/JSON archivés et budgets bloquants.

## Périmètre initial

Le workflow mesure trois fois chaque page, puis utilise la mesure médiane :

- accueil `/` ;
- page pilier `/trouver-une-personne-disponible/` ;
- guide `/guides/creer-micro-entreprise-services/` ;
- page régionale `/guadeloupe`.

Deux profils sont exécutés en parallèle : mobile et desktop.

## Déclenchement

Le workflow `.github/workflows/lighthouse-performance.yml` fonctionne :

- manuellement, avec l’URL et le SHA Firebase réellement déployé ;
- chaque lundi pour surveiller une éventuelle dérive de production.

Une exécution planifiée mesure la production mais ne constitue une preuve de certification que si le SHA de référence correspond au SHA déployé. Pour la certification, lancer manuellement le workflow et renseigner `deployed_sha`.

## Budgets initiaux bloquants

Les seuils sont centralisés dans `config/lighthouse-thresholds.json`.

### Mobile

- performance ≥ 65 ;
- SEO ≥ 95 ;
- accessibilité ≥ 90 ;
- bonnes pratiques ≥ 90 ;
- FCP ≤ 3 000 ms ;
- LCP ≤ 4 000 ms ;
- CLS ≤ 0,15 ;
- TBT ≤ 650 ms ;
- Speed Index ≤ 5 000 ms.

### Desktop

- performance ≥ 80 ;
- SEO ≥ 95 ;
- accessibilité ≥ 90 ;
- bonnes pratiques ≥ 90 ;
- FCP ≤ 2 000 ms ;
- LCP ≤ 3 000 ms ;
- CLS ≤ 0,10 ;
- TBT ≤ 400 ms ;
- Speed Index ≤ 3 500 ms.

Ces seuils constituent le plancher de départ. Ils ne doivent être abaissés pour rendre un contrôle vert. Les corrections doivent porter sur le site, puis les seuils pourront être relevés progressivement.

## Preuves archivées

Chaque profil conserve pendant 90 jours :

- les rapports Lighthouse HTML ;
- les rapports Lighthouse JSON ;
- le manifeste des mesures représentatives ;
- un résumé JSON structuré ;
- un tableau Markdown ajouté au résumé GitHub Actions ;
- le SHA de référence et le SHA du workflow.

## Condition de clôture du lot

Le lot 13 pourra passer de `pending` à `complete` lorsque :

1. le workflow aura été exécuté avec le SHA réellement déployé ;
2. les profils mobile et desktop seront verts ;
3. les quatre pages respecteront tous les budgets ;
4. les artefacts du run seront disponibles ;
5. le registre `quality/seo_acquisition_readiness.json` pointera vers cette preuve.

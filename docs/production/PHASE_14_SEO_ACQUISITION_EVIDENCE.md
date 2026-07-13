# Phase 14 — SEO, acquisition, CRM et contenu

## Objectif

Rendre mesurables la découvrabilité Web, l’attribution des campagnes, les deep links, le CRM consenti et le coût d’acquisition par canal.

## Registre de preuves

Le fichier `quality/seo_acquisition_readiness.json` centralise les contrôles attendus. Un contrôle ne passe à `complete` qu’avec une preuve reproductible : rapport Lighthouse, capture d’outil webmaster, test UTM/deep link, preuve de consentement ou dashboard d’attribution.

## Commandes

```bash
node tools/quality/check_seo_acquisition_readiness.test.mjs
node tools/quality/check_seo_acquisition_readiness.mjs
node tools/quality/check_seo_acquisition_readiness.mjs --enforce
```

Le mode standard produit un inventaire sans masquer les éléments encore en attente. Le mode `--enforce` est destiné à la clôture effective de la phase.

## Definition of Done

- métadonnées, sitemap, robots.txt et indexation validés ;
- pages publiques performantes et partageables ;
- campagnes attribuées par canal ;
- deep links testés sur les plateformes cibles ;
- CRM email/push fondé sur un consentement versionné ;
- referral, onboarding et réactivation mesurés ;
- CAC et conversion suivis dans un dashboard exploitable.

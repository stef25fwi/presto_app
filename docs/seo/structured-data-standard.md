# Standard des données structurées iliprestō

Le point 5 définit les graphes JSON-LD autorisés sur les pages publiques d’iliprestō.

## Identifiants stables

| Entité | `@id` |
|---|---|
| Organisation | `https://ilipresto.fr/#organization` |
| Site web | `https://ilipresto.fr/#website` |
| Logo | `https://ilipresto.fr/#logo` |
| Service national | `https://ilipresto.fr/#service` |

Ces identifiants doivent être réutilisés au lieu de recréer des entités différentes sur chaque page.

## Types autorisés et usages

- `Organization` : identité officielle d’iliprestō, logo, zone France et langue française.
- `WebSite` : site national et relation avec l’organisation éditrice.
- `WebPage` : URL canonique, langue, rattachement au site et sujet principal.
- `Service` : mise en relation nationale ou territoriale.
- `ProfilePage` : page `/a-propos`, centrée sur l’organisation iliprestō.
- `Article` : guides éditoriaux avec auteur, éditeur et dates visibles.
- `BreadcrumbList` : hiérarchie visible et URLs canoniques.

## Types interdits sans validation produit

`Product`, `Offer`, `AggregateOffer`, `LocalBusiness`, `AggregateRating` et `Review` sont bloqués. iliprestō ne doit pas se présenter comme vendeur d’un produit, commerce local unique, ni publier des notes ou avis absents du contenu visible.

Les propriétés `sameAs`, coordonnées, identifiants légaux, avis et notes ne sont ajoutés que lorsqu’une source officielle et vérifiable existe. Aucune valeur ne doit être inventée pour compléter un schéma.

## Pages contrôlées

Le registre `web/structured-data-registry.json` définit les types obligatoires pour l’accueil, les trois pages territoriales, la page À propos, le guide public et les quatre routes légales.

## Vérifications

```bash
node tools/quality/check_structured_data.mjs
node tools/quality/check_live_structured_data.mjs
```

Le premier contrôle analyse les fichiers du dépôt et bloque les graphes invalides, incohérents ou trompeurs. Le second s’exécute après un déploiement Firebase réussi et vérifie les pages réellement servies par `ilipresto.fr`.

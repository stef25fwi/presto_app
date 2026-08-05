# Lot 13 — contrat de certification Lighthouse

Le lot 13 est certifié uniquement lorsque les profils `mobile` et `desktop` publient chacun un statut GitHub `success` sur le SHA Firebase réellement déployé.

## Contextes attendus

- `quality/lighthouse-mobile` ;
- `quality/lighthouse-desktop` ;
- `quality/lighthouse-lot13`.

## Preuves exigées

Chaque profil doit fournir un artefact GitHub Actions conservé 90 jours contenant un fichier `summary.json` avec :

- `lot` égal à `13` ;
- `referenceSha` égal au SHA contrôlé ;
- `status` égal à `passed` ;
- quatre pages publiques représentatives ;
- toutes les pages marquées `passed`.

Le statut global ne passe à `success` que si le workflow Lighthouse, le téléchargement des artefacts et les deux profils sont conformes.

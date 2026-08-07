# Lot 3 — Code mort — tranche 4

## Zone

`lib/pages/home_page.dart`

## Suppressions prouvées

Trois déclarations sans aucun appel ont été supprimées :
- `_homeSlideTitleFontSize` ;
- `_responsiveHeroTitleFontSize(BuildContext)` ;
- `_responsiveHeroSubtitleFontSize(BuildContext)`.

Les variantes `_responsiveHomeSlideTitleFontSize` et `_responsiveHomeSlideSubtitleFontSize` restent en place car elles sont effectivement utilisées dans le rendu des slides.

La recherche et l’inspection du fichier avant modification montraient une occurrence unique pour chacune des trois déclarations supprimées. Aucun comportement, route, Auth, App Check, Firebase ou deep link n’est modifié.

Le workflow temporaire utilisé pour appliquer atomiquement la modification sur ce fichier volumineux s’est supprimé lui-même ; il ne fait pas partie du diff final.

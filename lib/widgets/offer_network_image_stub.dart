import 'package:flutter/widgets.dart';

Widget buildOfferNetworkImage({
  required String url,
  required BoxFit fit,
  required Widget errorChild,
  Widget? loadingChild,
  int? cacheWidth,
  int? cacheHeight,
}) {
  return Image.network(
    url,
    fit: fit,
    // Décode l'image à la résolution d'affichage plutôt qu'en plein format :
    // borne fortement la mémoire dans les listes de vignettes.
    cacheWidth: cacheWidth,
    cacheHeight: cacheHeight,
    filterQuality: FilterQuality.medium,
    gaplessPlayback: true,
    errorBuilder: (_, __, ___) => errorChild,
    loadingBuilder: (context, child, loadingProgress) {
      if (loadingProgress == null) {
        return child;
      }
      return loadingChild ?? errorChild;
    },
  );
}

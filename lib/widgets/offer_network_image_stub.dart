import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

Widget buildOfferNetworkImage({
  required String url,
  required BoxFit fit,
  required Widget errorChild,
  Widget? loadingChild,
  int? cacheWidth,
  int? cacheHeight,
}) {
  // Cache disque persistant entre les sessions (mobile) : évite de
  // re-télécharger les photos d'annonces et avatars à chaque ouverture.
  return CachedNetworkImage(
    imageUrl: url,
    fit: fit,
    // Décode l'image à la résolution d'affichage plutôt qu'en plein format :
    // borne fortement la mémoire dans les listes de vignettes.
    memCacheWidth: cacheWidth,
    memCacheHeight: cacheHeight,
    filterQuality: FilterQuality.medium,
    fadeInDuration: Duration.zero,
    fadeOutDuration: Duration.zero,
    errorWidget: (_, __, ___) => errorChild,
    placeholder: (context, _) => loadingChild ?? errorChild,
  );
}

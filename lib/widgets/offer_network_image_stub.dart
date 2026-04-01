import 'package:flutter/widgets.dart';

Widget buildOfferNetworkImage({
  required String url,
  required BoxFit fit,
  required Widget errorChild,
  Widget? loadingChild,
}) {
  return Image.network(
    url,
    fit: fit,
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
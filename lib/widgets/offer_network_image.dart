import 'package:flutter/widgets.dart';

import 'offer_network_image_stub.dart'
    if (dart.library.js_interop) 'offer_network_image_web.dart' as impl;

class OfferNetworkImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final Widget errorChild;
  final Widget? loadingChild;

  const OfferNetworkImage({
    super.key,
    required this.url,
    required this.fit,
    required this.errorChild,
    this.loadingChild,
  });

  @override
  Widget build(BuildContext context) {
    return impl.buildOfferNetworkImage(
      url: url,
      fit: fit,
      errorChild: errorChild,
      loadingChild: loadingChild,
    );
  }
}

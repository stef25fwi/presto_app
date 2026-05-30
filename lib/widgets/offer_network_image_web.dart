// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

final Set<String> _registeredImageViewTypes = <String>{};

String _cssObjectFit(BoxFit fit) {
  switch (fit) {
    case BoxFit.contain:
      return 'contain';
    case BoxFit.fill:
      return 'fill';
    case BoxFit.none:
      return 'none';
    case BoxFit.scaleDown:
      return 'scale-down';
    case BoxFit.cover:
    case BoxFit.fitHeight:
    case BoxFit.fitWidth:
      return 'cover';
  }
}

Widget buildOfferNetworkImage({
  required String url,
  required BoxFit fit,
  required Widget errorChild,
  Widget? loadingChild,
}) {
  final trimmedUrl = url.trim();
  if (trimmedUrl.isEmpty) {
    return errorChild;
  }

  final viewType = 'offer-network-image-${Object.hash(trimmedUrl, fit)}';
  if (_registeredImageViewTypes.add(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final container = web.HTMLDivElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.overflow = 'hidden'
        ..style.pointerEvents = 'none';
      final image = web.HTMLImageElement()
        ..src = trimmedUrl
        ..loading = 'lazy'
        ..decoding = 'async'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.display = 'block'
        ..style.objectFit = _cssObjectFit(fit)
        ..style.pointerEvents = 'none';
      container.append(image);
      return container;
    });
  }

  return HtmlElementView(viewType: viewType);
}
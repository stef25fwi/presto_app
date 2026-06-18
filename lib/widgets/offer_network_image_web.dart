// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:js_interop';
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
    default:
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
  if (trimmedUrl.isEmpty) return errorChild;

  final viewType = 'offer-network-image-${Object.hash(trimmedUrl, fit)}';
  if (_registeredImageViewTypes.add(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final image = web.HTMLImageElement()
        ..decoding = 'async'
        // 'lazy' supprimé — chargement immédiat (cache browser exploité)
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.display = 'block'
        ..style.objectFit = _cssObjectFit(fit)
        ..style.pointerEvents = 'none'
        ..style.opacity = '0'
        ..style.transition = 'opacity 0.18s ease-in';

      // Fade-in au chargement (et à l'erreur pour éviter une zone blanche)
      void onReady(JSAny? _) => image.style.opacity = '1';
      image.addEventListener('load', onReady.toJS);
      image.addEventListener('error', onReady.toJS);

      // src défini APRÈS les listeners pour éviter la race condition
      image.src = trimmedUrl;

      final container = web.HTMLDivElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.overflow = 'hidden'
        ..style.pointerEvents = 'none';
      container.append(image);
      return container;
    });
  }

  final htmlView = HtmlElementView(viewType: viewType);
  if (loadingChild == null) return htmlView;

  // loadingChild visible pendant l'init du HtmlElementView
  // puis recouvert par l'image qui fade-in
  return Stack(
    fit: StackFit.expand,
    children: [loadingChild, htmlView],
  );
}

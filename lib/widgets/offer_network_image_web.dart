// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

int _offerNetworkImageViewTypeSeed = 0;

Widget buildOfferNetworkImage({
  required String url,
  required BoxFit fit,
  required Widget errorChild,
  Widget? loadingChild,
}) {
  return _OfferNetworkImageWeb(
    url: url,
    fit: fit,
    errorChild: errorChild,
    loadingChild: loadingChild,
  );
}

class _OfferNetworkImageWeb extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final Widget errorChild;
  final Widget? loadingChild;

  const _OfferNetworkImageWeb({
    required this.url,
    required this.fit,
    required this.errorChild,
    this.loadingChild,
  });

  @override
  State<_OfferNetworkImageWeb> createState() => _OfferNetworkImageWebState();
}

class _OfferNetworkImageWebState extends State<_OfferNetworkImageWeb> {
  late String _viewType;
  bool _loaded = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _configureViewType();
  }

  @override
  void didUpdateWidget(covariant _OfferNetworkImageWeb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.fit != widget.fit) {
      _loaded = false;
      _failed = false;
      _configureViewType();
    }
  }

  void _configureViewType() {
    _viewType = 'offer-network-image-${_offerNetworkImageViewTypeSeed++}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final image = html.ImageElement()
        ..draggable = false
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = _objectFit(widget.fit);

      image.onLoad.listen((_) {
        if (!mounted) return;
        setState(() {
          _loaded = true;
          _failed = false;
        });
      });

      image.onError.listen((_) {
        if (!mounted) return;
        setState(() {
          _failed = true;
          _loaded = false;
        });
      });

      image.src = widget.url;

      if (image.complete == true && image.naturalWidth > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _loaded = true;
            _failed = false;
          });
        });
      }

      return image;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return widget.errorChild;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        HtmlElementView(viewType: _viewType),
        if (!_loaded)
          Positioned.fill(
            child: IgnorePointer(
              child: widget.loadingChild ?? widget.errorChild,
            ),
          ),
      ],
    );
  }
}

String _objectFit(BoxFit fit) {
  switch (fit) {
    case BoxFit.contain:
      return 'contain';
    case BoxFit.cover:
      return 'cover';
    case BoxFit.fill:
      return 'fill';
    case BoxFit.fitHeight:
      return 'contain';
    case BoxFit.fitWidth:
      return 'contain';
    case BoxFit.none:
      return 'none';
    case BoxFit.scaleDown:
      return 'scale-down';
  }
}
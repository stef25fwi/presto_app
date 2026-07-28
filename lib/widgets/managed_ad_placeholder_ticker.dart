import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:presto_app/services/ad_placeholder_image_service.dart';

class ManagedAdPlaceholderTicker extends StatefulWidget {
  const ManagedAdPlaceholderTicker({
    super.key,
    required this.fallbackFolderPrefix,
    required this.borderRadius,
    required this.enabled,
    this.interval = const Duration(seconds: 4),
    this.antiRepeatWindow = 0,
    this.target = 'consult_offers',
  });

  final String fallbackFolderPrefix;
  final BorderRadius borderRadius;
  final bool enabled;
  final Duration interval;
  final int antiRepeatWindow;
  final String target;

  @override
  State<ManagedAdPlaceholderTicker> createState() =>
      _ManagedAdPlaceholderTickerState();
}

class _ManagedAdPlaceholderTickerState
    extends State<ManagedAdPlaceholderTicker> {
  final List<int> _recentIndexes = <int>[];

  StreamSubscription<List<AdPlaceholderImage>>? _remoteSubscription;
  List<_BannerImageSource> _remoteImages = <_BannerImageSource>[];
  List<_BannerImageSource> _fallbackImages = <_BannerImageSource>[];

  int _index = 0;
  double? _aspectRatio;
  Timer? _timer;
  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;

  List<_BannerImageSource> get _activeImages {
    if (_remoteImages.isNotEmpty) return _remoteImages;
    return _fallbackImages;
  }

  _BannerImageSource? get _currentImage {
    final images = _activeImages;
    if (images.isEmpty) return null;
    return images[_index.clamp(0, images.length - 1)];
  }

  @override
  void initState() {
    super.initState();
    _watchRemoteImages();
    _loadFallbackAssets();
  }

  @override
  void didUpdateWidget(covariant ManagedAdPlaceholderTicker oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.target != widget.target) {
      _remoteSubscription?.cancel();
      _watchRemoteImages();
    }

    if (oldWidget.fallbackFolderPrefix != widget.fallbackFolderPrefix) {
      _fallbackImages = <_BannerImageSource>[];
      _loadFallbackAssets();
    }

    if (oldWidget.enabled != widget.enabled ||
        oldWidget.interval != widget.interval) {
      _startTimer();
    }
  }

  void _watchRemoteImages() {
    _remoteSubscription?.cancel();

    try {
      _remoteSubscription =
          AdPlaceholderImageService.watchVisible(target: widget.target).listen(
        (images) {
          if (!mounted) return;

          setState(() {
            _remoteImages = images
                .where((image) => image.imageUrl.trim().isNotEmpty)
                .map(
                  (image) => _BannerImageSource.network(
                    image.imageUrl.trim(),
                  ),
                )
                .toList();
            _index = 0;
            _aspectRatio = null;
          });

          _resolveCurrentImageRatio();
          _startTimer();
        },
        onError: (_) {
          if (!mounted) return;
          setState(() => _remoteImages = <_BannerImageSource>[]);
        },
      );
    } catch (_) {
      _remoteSubscription = null;
      _remoteImages = <_BannerImageSource>[];
    }
  }

  Future<void> _loadFallbackAssets() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);

    final normalizedPrefix = widget.fallbackFolderPrefix.endsWith('/')
        ? widget.fallbackFolderPrefix
        : '${widget.fallbackFolderPrefix}/';

    final assets = manifest
        .listAssets()
        .where(
          (asset) =>
              asset.startsWith(normalizedPrefix) &&
              RegExp(r'\.(png|jpg|jpeg|webp)$', caseSensitive: false)
                  .hasMatch(asset),
        )
        .toList()
      ..sort();

    if (!mounted) return;

    setState(() {
      _fallbackImages = assets.map(_BannerImageSource.asset).toList();
      _index = 0;
    });

    _resolveCurrentImageRatio();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();

    if (!widget.enabled || _activeImages.length <= 1) return;

    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted || _activeImages.length <= 1) return;

      setState(() {
        _index = _nextIndex();
      });

      _resolveCurrentImageRatio();
    });
  }

  int _nextIndex() {
    final images = _activeImages;

    if (images.length <= 1) return 0;

    final blocked = _recentIndexes.toSet();

    for (var attempt = 1; attempt <= images.length; attempt++) {
      final candidate = (_index + attempt) % images.length;
      if (!blocked.contains(candidate)) {
        _rememberIndex(candidate);
        return candidate;
      }
    }

    final fallback = (_index + 1) % images.length;
    _rememberIndex(fallback);
    return fallback;
  }

  void _rememberIndex(int index) {
    if (widget.antiRepeatWindow <= 0) return;

    _recentIndexes.add(index);

    while (_recentIndexes.length > widget.antiRepeatWindow) {
      _recentIndexes.removeAt(0);
    }
  }

  void _resolveCurrentImageRatio() {
    final image = _currentImage;
    if (image == null) return;

    final provider = image.provider;
    final stream = provider.resolve(createLocalImageConfiguration(context));

    if (_imageStream?.key == stream.key) return;

    if (_imageListener != null) {
      _imageStream?.removeListener(_imageListener!);
    }

    _imageStream = stream;
    _imageListener = ImageStreamListener((info, _) {
      final width = info.image.width.toDouble();
      final height = info.image.height.toDouble();

      if (!mounted || width <= 0 || height <= 0) return;

      setState(() {
        _aspectRatio = width / height;
      });
    });

    stream.addListener(_imageListener!);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _remoteSubscription?.cancel();

    if (_imageListener != null) {
      _imageStream?.removeListener(_imageListener!);
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _currentImage;

    if (image == null) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        final ratio = _aspectRatio ?? (16 / 9);
        final calculatedHeight = availableWidth / ratio;

        return SizedBox(
          width: double.infinity,
          height: calculatedHeight,
          child: ClipRRect(
            borderRadius: widget.borderRadius,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: Image(
                key: ValueKey<String>(image.key),
                image: image.provider,
                width: double.infinity,
                height: calculatedHeight,
                fit: BoxFit.contain,
                alignment: Alignment.center,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BannerImageSource {
  const _BannerImageSource._({
    required this.key,
    required this.provider,
  });

  factory _BannerImageSource.asset(String assetPath) {
    return _BannerImageSource._(
      key: 'asset:$assetPath',
      provider: AssetImage(assetPath),
    );
  }

  factory _BannerImageSource.network(String url) {
    return _BannerImageSource._(
      key: 'network:$url',
      provider: NetworkImage(url),
    );
  }

  final String key;
  final ImageProvider provider;
}

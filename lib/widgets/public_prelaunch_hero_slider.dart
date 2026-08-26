import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/hero_slide.dart';
import '../services/hero_slides_service.dart';

/// Hero média de la page publique « Bientôt disponible ».
///
/// La source par défaut est exactement la même que celle du Hero de l'accueil :
/// la collection `heroSlides`, administrée depuis « Espace admin > Gestion du Hero ».
/// Cela permet de réutiliser les mêmes outils de gestion (photo/vidéo, ordre,
/// durée, activation, premier slide et point focal) sans créer un second
/// back-office divergent.
class PublicPrelaunchHeroSlider extends StatelessWidget {
  const PublicPrelaunchHeroSlider({
    super.key,
    this.slidesStream,
  });

  /// Injection utile pour les tests. En production, seuls les slides globaux
  /// sont affichés afin de ne pas mélanger une campagne régionale avec la
  /// landing nationale de pré-lancement.
  final Stream<List<HeroSlide>>? slidesStream;

  @override
  Widget build(BuildContext context) {
    final stream =
        slidesStream ?? HeroSlidesService().watchSlidesForRegion(null);

    return StreamBuilder<List<HeroSlide>>(
      stream: stream,
      builder: (context, snapshot) {
        final slides = (snapshot.data ?? const <HeroSlide>[])
            .where((slide) =>
                slide.isActive && slide.mediaUrl.trim().isNotEmpty)
            .toList(growable: false)
          ..sort(HeroSlide.compareDisplayOrder);

        // Aucun espace vide tant qu'aucun média Hero n'est publié.
        if (slides.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: _PublicPrelaunchHeroCarousel(slides: slides),
        );
      },
    );
  }
}

class _PublicPrelaunchHeroCarousel extends StatefulWidget {
  const _PublicPrelaunchHeroCarousel({required this.slides});

  final List<HeroSlide> slides;

  @override
  State<_PublicPrelaunchHeroCarousel> createState() =>
      _PublicPrelaunchHeroCarouselState();
}

class _PublicPrelaunchHeroCarouselState
    extends State<_PublicPrelaunchHeroCarousel> {
  final PageController _controller = PageController();
  Timer? _timer;
  int _index = 0;
  bool _muted = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _precacheImages();
      _scheduleNext();
    });
  }

  @override
  void didUpdateWidget(covariant _PublicPrelaunchHeroCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldIds = oldWidget.slides.map((slide) => slide.id).join('|');
    final newIds = widget.slides.map((slide) => slide.id).join('|');
    if (oldIds != newIds) {
      _index = 0;
      if (_controller.hasClients) {
        _controller.jumpToPage(0);
      }
      _precacheImages();
    } else if (_index >= widget.slides.length) {
      _index = 0;
    }
    _scheduleNext();
  }

  void _precacheImages() {
    for (final slide in widget.slides) {
      if (slide.isImage && slide.mediaUrl.trim().isNotEmpty) {
        precacheImage(CachedNetworkImageProvider(slide.mediaUrl), context);
      }
    }
  }

  void _scheduleNext() {
    _timer?.cancel();
    if (widget.slides.length <= 1) return;

    final safeIndex = _index.clamp(0, widget.slides.length - 1);
    final duration =
        widget.slides[safeIndex].durationSeconds.clamp(3, 60).toInt();
    _timer = Timer(Duration(seconds: duration), () {
      if (!mounted || !_controller.hasClients || widget.slides.length <= 1) {
        return;
      }
      final next = (_index + 1) % widget.slides.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = width < 420
            ? (width * 0.60).clamp(190.0, 250.0).toDouble()
            : width < 720
                ? (width * 0.46).clamp(220.0, 300.0).toDouble()
                : 320.0;
        final safeIndex = _index.clamp(0, widget.slides.length - 1);
        final currentIsVideo = widget.slides[safeIndex].isVideo;

        return Semantics(
          container: true,
          label: 'Présentation iliprestō',
          child: SizedBox(
            width: double.infinity,
            height: height,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: _controller,
                    itemCount: widget.slides.length,
                    onPageChanged: (value) {
                      setState(() => _index = value);
                      _scheduleNext();
                    },
                    itemBuilder: (context, index) {
                      return _PublicPrelaunchHeroMedia(
                        key: ValueKey(widget.slides[index].id),
                        slide: widget.slides[index],
                        muted: _muted,
                      );
                    },
                  ),
                  if (widget.slides.length > 1)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 12,
                      child: IgnorePointer(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List<Widget>.generate(
                            widget.slides.length,
                            (dotIndex) => AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: dotIndex == _index ? 18 : 8,
                              height: 7,
                              decoration: BoxDecoration(
                                color: dotIndex == _index
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.48),
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: const <BoxShadow>[
                                  BoxShadow(
                                    color: Color(0x33000000),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (currentIsVideo)
                    Positioned(
                      right: 12,
                      bottom: 10,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.48),
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: _muted ? 'Activer le son' : 'Couper le son',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => setState(() => _muted = !_muted),
                          icon: Icon(
                            _muted
                                ? Icons.volume_off_rounded
                                : Icons.volume_up_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PublicPrelaunchHeroMedia extends StatefulWidget {
  const _PublicPrelaunchHeroMedia({
    super.key,
    required this.slide,
    required this.muted,
  });

  final HeroSlide slide;
  final bool muted;

  @override
  State<_PublicPrelaunchHeroMedia> createState() =>
      _PublicPrelaunchHeroMediaState();
}

class _PublicPrelaunchHeroMediaState
    extends State<_PublicPrelaunchHeroMedia> {
  VideoPlayerController? _videoController;
  bool _videoFailed = false;

  @override
  void initState() {
    super.initState();
    _initialiseVideo();
  }

  @override
  void didUpdateWidget(covariant _PublicPrelaunchHeroMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slide.mediaUrl != widget.slide.mediaUrl ||
        oldWidget.slide.mediaType != widget.slide.mediaType) {
      _disposeVideo();
      _videoFailed = false;
      _initialiseVideo();
      return;
    }

    if (oldWidget.muted != widget.muted) {
      _videoController?.setVolume(widget.muted ? 0 : 1);
    }
  }

  Future<void> _initialiseVideo() async {
    if (!widget.slide.isVideo || widget.slide.mediaUrl.trim().isEmpty) return;

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.slide.mediaUrl),
    );
    _videoController = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(widget.muted ? 0 : 1);
      await controller.play();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        setState(() => _videoFailed = true);
      }
    }
  }

  void _disposeVideo() {
    final controller = _videoController;
    _videoController = null;
    if (controller != null) {
      unawaited(controller.dispose());
    }
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.slide.isImage) {
      return CachedNetworkImage(
        imageUrl: widget.slide.mediaUrl,
        fit: BoxFit.cover,
        alignment: widget.slide.focalAlignment,
        fadeInDuration: const Duration(milliseconds: 180),
        placeholder: (_, __) => const _HeroLoadingSurface(),
        errorWidget: (_, __, ___) => const _HeroErrorSurface(),
      );
    }

    final controller = _videoController;
    if (_videoFailed) {
      return const _HeroErrorSurface();
    }
    if (controller == null || !controller.value.isInitialized) {
      return const _HeroLoadingSurface();
    }

    return ColoredBox(
      color: Colors.black,
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }
}

class _HeroLoadingSurface extends StatelessWidget {
  const _HeroLoadingSurface();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFF1F5F9),
      child: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ),
    );
  }
}

class _HeroErrorSurface extends StatelessWidget {
  const _HeroErrorSurface();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFF8FAFC),
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: Color(0xFF94A3B8),
          size: 34,
        ),
      ),
    );
  }
}

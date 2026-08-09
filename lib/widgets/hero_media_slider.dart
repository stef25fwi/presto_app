import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../models/hero_slide.dart';

double _responsiveHeroHeightForWidth(double width) {
  final factor = width < 360 ? 0.62 : (width < 700 ? 0.54 : 0.38);
  return (width * factor).clamp(180.0, 360.0).toDouble();
}

String _muteKey(String uid) => 'hero_video_muted_$uid';

class HeroMediaSlider extends StatefulWidget {
  final List<HeroSlide> slides;
  final Widget fallback;
  final double borderRadius;

  const HeroMediaSlider({
    super.key,
    required this.slides,
    required this.fallback,
    this.borderRadius = 22,
  });

  @override
  State<HeroMediaSlider> createState() => _HeroMediaSliderState();
}

class _HeroMediaSliderState extends State<HeroMediaSlider> {
  static const Duration _seoIntroDuration = Duration(seconds: 9);

  final PageController _pageController = PageController();
  Timer? _introTimer;
  Timer? _slideTimer;
  int _currentIndex = 0;
  bool _isMuted = false;
  bool _showSeoIntro = true;

  @override
  void initState() {
    super.initState();
    _loadMutePreference();
    _scheduleSeoIntro();
    WidgetsBinding.instance.addPostFrameCallback((_) => _precacheSlideImages());
  }

  @override
  void didUpdateWidget(covariant HeroMediaSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slides.map((slide) => slide.id).join('|') !=
        widget.slides.map((slide) => slide.id).join('|')) {
      _currentIndex = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
      _precacheSlideImages();
    } else if (_currentIndex >= widget.slides.length) {
      _currentIndex = 0;
    }
    if (!_showSeoIntro) {
      _scheduleNextSlide();
    }
  }

  void _scheduleSeoIntro() {
    _introTimer?.cancel();
    _introTimer = Timer(_seoIntroDuration, () {
      if (!mounted) return;
      setState(() => _showSeoIntro = false);
      _scheduleNextSlide();
    });
  }

  void _precacheSlideImages() {
    for (final slide in widget.slides) {
      if (!slide.isVideo && slide.mediaUrl.isNotEmpty) {
        precacheImage(CachedNetworkImageProvider(slide.mediaUrl), context);
      }
    }
  }

  @override
  void dispose() {
    _introTimer?.cancel();
    _slideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadMutePreference() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool(_muteKey(user.uid));
    if (saved != null && mounted) {
      setState(() => _isMuted = saved);
    }
  }

  Future<void> _toggleMute() async {
    final newMuted = !_isMuted;
    setState(() => _isMuted = newMuted);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_muteKey(user.uid), newMuted);
    }
  }

  void _scheduleNextSlide() {
    _slideTimer?.cancel();
    if (widget.slides.length <= 1) {
      return;
    }

    final slide =
        widget.slides[_currentIndex.clamp(0, widget.slides.length - 1)];
    final seconds = slide.durationSeconds < 1 ? 5 : slide.durationSeconds;
    _slideTimer = Timer(Duration(seconds: seconds), () {
      if (!mounted ||
          !_pageController.hasClients ||
          widget.slides.length <= 1) {
        return;
      }
      final nextIndex = (_currentIndex + 1) % widget.slides.length;
      _pageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showSeoIntro) {
      return _PrestoStableHeroViewport(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: const _SeoIntroSlide(),
        ),
      );
    }

    final activeSlides = widget.slides
        .where((slide) => slide.mediaUrl.trim().isNotEmpty)
        .toList(growable: false);
    if (activeSlides.isEmpty) {
      return widget.fallback;
    }

    final safeIndex = _currentIndex.clamp(0, activeSlides.length - 1);
    final currentSlideIsVideo = activeSlides[safeIndex].isVideo;

    return _PrestoStableHeroViewport(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: GestureDetector(
          onHorizontalDragEnd: (details) {
            if (!_pageController.hasClients || activeSlides.length <= 1) return;
            final v = details.primaryVelocity ?? 0;
            if (v < -200) {
              _pageController.animateToPage(
                (_currentIndex + 1) % activeSlides.length,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOutCubic,
              );
            } else if (v > 200) {
              _pageController.animateToPage(
                (_currentIndex - 1 + activeSlides.length) % activeSlides.length,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOutCubic,
              );
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: activeSlides.length,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                  _scheduleNextSlide();
                },
                itemBuilder: (context, index) {
                  final slide = activeSlides[index];
                  return _HeroMediaSlideView(
                    slide: slide,
                    isMuted: _isMuted,
                    onVideoError: activeSlides.length <= 1
                        ? null
                        : () {
                            if (!_pageController.hasClients) return;
                            _pageController.animateToPage(
                              (index + 1) % activeSlides.length,
                              duration: const Duration(milliseconds: 360),
                              curve: Curves.easeOutCubic,
                            );
                          },
                  );
                },
              ),
              if (activeSlides.length > 1)
                Positioned(
                  bottom: 8,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      activeSlides.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: _currentIndex == index ? 16 : 8,
                        height: 7,
                        decoration: BoxDecoration(
                          color: _currentIndex == index
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ),
              if (currentSlideIsVideo)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: _MuteToggleButton(
                    isMuted: _isMuted,
                    onToggle: _toggleMute,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeoIntroSlide extends StatelessWidget {
  const _SeoIntroSlide();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final compact = width < 430;
        final titleSize = width < 360 ? 19.0 : (compact ? 22.0 : 29.0);
        final bodySize = width < 360 ? 11.5 : (compact ? 12.5 : 14.5);
        final footerSize = width < 360 ? 11.0 : (compact ? 12.0 : 14.0);

        return Semantics(
          container: true,
          header: true,
          label: 'La solution à tout moment pour tous vos besoins du quotidien',
          child: Container(
            color: const Color(0xFFFF6600),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 16 : 24,
              vertical: compact ? 12 : 18,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: width - (compact ? 32 : 48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'La solution à tout moment pour tous vos besoins du quotidien',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: titleSize,
                        fontWeight: FontWeight.w900,
                        height: 1.12,
                        shadows: const [
                          Shadow(
                            color: Color(0x40000000),
                            blurRadius: 6,
                            offset: Offset(0, 1.5),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: compact ? 8 : 12),
                    Text(
                      'Publiez une annonce assistée par IA à partir d’un texte ou de votre voix pour trouver une réponse adaptée à vos besoins du quotidien.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: bodySize,
                        fontWeight: FontWeight.w600,
                        height: 1.32,
                      ),
                    ),
                    SizedBox(height: compact ? 6 : 9),
                    Text(
                      'iliprestō ne prélève aucune commission sur vos prestations et ne collecte ni ne gère les paiements entre utilisateurs.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: bodySize,
                        fontWeight: FontWeight.w600,
                        height: 1.32,
                      ),
                    ),
                    SizedBox(height: compact ? 8 : 12),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 10 : 13,
                        vertical: compact ? 6 : 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.48),
                        ),
                      ),
                      child: Text(
                        'Annonces assistées par IA, échange direct et 0 % de commission : une solution simple à tout moment.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: footerSize,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MuteToggleButton extends StatelessWidget {
  final bool isMuted;
  final VoidCallback onToggle;

  const _MuteToggleButton({required this.isMuted, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          color: Colors.white,
          size: 17,
        ),
      ),
    );
  }
}

class _HeroMediaSlideView extends StatefulWidget {
  final HeroSlide slide;
  final VoidCallback? onVideoError;
  final bool isMuted;

  const _HeroMediaSlideView({
    required this.slide,
    required this.isMuted,
    this.onVideoError,
  });

  @override
  State<_HeroMediaSlideView> createState() => _HeroMediaSlideViewState();
}

class _HeroMediaSlideViewState extends State<_HeroMediaSlideView> {
  VideoPlayerController? _videoController;
  bool _hasVideoError = false;

  @override
  void initState() {
    super.initState();
    _initVideoIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _HeroMediaSlideView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slide.mediaUrl != widget.slide.mediaUrl ||
        oldWidget.slide.mediaType != widget.slide.mediaType) {
      _disposeVideo();
      _hasVideoError = false;
      _initVideoIfNeeded();
    } else if (oldWidget.isMuted != widget.isMuted) {
      _videoController?.setVolume(widget.isMuted ? 0.0 : 1.0);
    }
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  Future<void> _initVideoIfNeeded() async {
    if (!widget.slide.isVideo) {
      return;
    }

    final uri = Uri.tryParse(widget.slide.mediaUrl);
    if (uri == null) {
      _markVideoError();
      return;
    }

    final controller = VideoPlayerController.networkUrl(uri);
    _videoController = controller;
    try {
      await controller.initialize();
      await controller.setVolume(widget.isMuted ? 0.0 : 1.0);
      await controller.setLooping(true);
      await controller.play();
      if (mounted) {
        setState(() {});
      }
    } catch (error) {
      _markVideoError();
    }
  }

  void _markVideoError() {
    if (!mounted) {
      return;
    }
    setState(() => _hasVideoError = true);
    widget.onVideoError?.call();
  }

  void _disposeVideo() {
    final controller = _videoController;
    _videoController = null;
    controller?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.slide.isVideo) {
      return Image(
        image: CachedNetworkImageProvider(widget.slide.mediaUrl),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        alignment: widget.slide.focalAlignment,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => const _HeroMediaErrorFallback(),
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) return child;
          return const _HeroMediaLoadingFallback();
        },
      );
    }

    final controller = _videoController;
    if (_hasVideoError) {
      return const _HeroMediaErrorFallback();
    }
    if (controller == null || !controller.value.isInitialized) {
      return const _HeroMediaLoadingFallback();
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        alignment: widget.slide.focalAlignment,
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

class _HeroMediaLoadingFallback extends StatelessWidget {
  const _HeroMediaLoadingFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      alignment: Alignment.center,
      child: const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Color(0xFF1A73E8),
        ),
      ),
    );
  }
}

class _HeroMediaErrorFallback extends StatelessWidget {
  const _HeroMediaErrorFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFF6600),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_not_supported_outlined,
        color: Colors.white,
        size: 34,
      ),
    );
  }
}

class _PrestoStableHeroViewport extends StatelessWidget {
  const _PrestoStableHeroViewport({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final stableHeight = _responsiveHeroHeightForWidth(width);

        return SizedBox(
          width: double.infinity,
          height: stableHeight,
          child: child,
        );
      },
    );
  }
}

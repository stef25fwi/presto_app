import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/hero_slide.dart';

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
  final PageController _pageController = PageController();
  Timer? _slideTimer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _scheduleNextSlide();
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
    } else if (_currentIndex >= widget.slides.length) {
      _currentIndex = 0;
    }
    _scheduleNextSlide();
  }

  @override
  void dispose() {
    _slideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
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
    final activeSlides = widget.slides
        .where((slide) => slide.mediaUrl.trim().isNotEmpty)
        .toList(growable: false);
    if (activeSlides.isEmpty) {
      return widget.fallback;
    }

    return ClipRRect(
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
          ],
        ),
      ),
    );
  }
}

class _HeroMediaSlideView extends StatefulWidget {
  final HeroSlide slide;
  final VoidCallback? onVideoError;

  const _HeroMediaSlideView({
    required this.slide,
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
      await controller.setVolume(0);
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
      return Image.network(
        widget.slide.mediaUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => const _HeroMediaErrorFallback(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
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

    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: controller.value.size.width,
        height: controller.value.size.height,
        child: VideoPlayer(controller),
      ),
    );
  }
}

class _HeroMediaLoadingFallback extends StatelessWidget {
  const _HeroMediaLoadingFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A73E8),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white,
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

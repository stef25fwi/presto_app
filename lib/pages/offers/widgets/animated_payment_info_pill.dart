import 'dart:math' as math;

import 'package:flutter/material.dart';

class AnimatedPaymentInfoPill extends StatefulWidget {
  final VoidCallback onTap;

  const AnimatedPaymentInfoPill({
    super.key,
    required this.onTap,
  });

  @override
  State<AnimatedPaymentInfoPill> createState() =>
      _AnimatedPaymentInfoPillState();
}

class _AnimatedPaymentInfoPillState extends State<AnimatedPaymentInfoPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _animationsDisabled = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animationsDisabled =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (animationsDisabled == _animationsDisabled &&
        (_controller.isAnimating || animationsDisabled)) {
      return;
    }

    _animationsDisabled = animationsDisabled;
    if (_animationsDisabled) {
      _controller
        ..stop()
        ..value = 0;
    } else {
      _controller.repeat();
    }
  }

  void _handleHover(bool isHovered) {
    if (_isHovered == isHovered) return;
    setState(() => _isHovered = isHovered);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const blueGradient = [Color(0xFF1A73E8), Color(0xFF0D5FD1)];
    const hoverGradient = [Color(0xFFE8EAEE), Color(0xFFDDE1E7)];
    const hoverTextColor = Color(0xFF303846);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = _controller.value;
          final wave = (1 - math.cos(progress * math.pi * 2)) / 2;
          final burstProgress =
              (progress / 0.24).clamp(0.0, 1.0).toDouble();
          final burst = progress < 0.24
              ? math.sin(math.pi * burstProgress)
              : 0.0;
          final animatedShake = progress < 0.24
              ? math.sin(burstProgress * math.pi * 8) * burst * 1.7
              : 0.0;
          final animatedScale = 1 + (wave * 0.018) + (burst * 0.055);
          final shineProgress =
              (progress / 0.62).clamp(0.0, 1.0).toDouble();
          final shine = -2.4 + (4.8 * shineProgress);
          final shake = _isHovered ? 0.0 : animatedShake;
          final scale = _isHovered ? 1.0 : animatedScale;

          return Semantics(
            button: true,
            label: 'Informations sur le paiement',
            child: Transform.translate(
              offset: Offset(shake, 0),
              child: Transform.scale(
                scale: scale,
                child: AnimatedContainer(
                  key: const ValueKey<String>('payment-info-pill-container'),
                  duration: _animationsDisabled
                      ? Duration.zero
                      : const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isHovered ? hoverGradient : blueGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: _isHovered
                          ? const Color(0xFFCDD2DA)
                          : Colors.white.withValues(alpha: 0.22),
                      width: 0.8,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      hoverColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      onHover: _handleHover,
                      onTap: widget.onTap,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 5,
                            ),
                            child: SizedBox(
                              width: 44,
                              child: Center(
                                child: AnimatedDefaultTextStyle(
                                  key: const ValueKey<String>(
                                    'payment-info-pill-text-style',
                                  ),
                                  duration: _animationsDisabled
                                      ? Duration.zero
                                      : const Duration(milliseconds: 160),
                                  curve: Curves.easeOut,
                                  style: TextStyle(
                                    color: _isHovered
                                        ? hoverTextColor
                                        : Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                  ),
                                  child: const Text(
                                    'Infos',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: AnimatedOpacity(
                                duration: _animationsDisabled
                                    ? Duration.zero
                                    : const Duration(milliseconds: 120),
                                opacity: _isHovered ? 0 : 1,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment(shine - 1.2, -0.3),
                                      end: Alignment(shine + 1.2, 0.3),
                                      colors: const [
                                        Colors.transparent,
                                        Color(0x66FFFFFF),
                                        Colors.transparent,
                                      ],
                                      stops: const [0.35, 0.5, 0.65],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

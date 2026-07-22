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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = _controller.value;
          final wave =
              (1 - math.cos(progress * math.pi * 2)) / 2;
          final burstProgress =
              (progress / 0.24).clamp(0.0, 1.0).toDouble();
          final burst = progress < 0.24
              ? math.sin(math.pi * burstProgress)
              : 0.0;
          final shake = progress < 0.24
              ? math.sin(burstProgress * math.pi * 8) * burst * 1.7
              : 0.0;
          final scale = 1 + (wave * 0.018) + (burst * 0.055);
          final glow = 0.28 + (wave * 0.18) + (burst * 0.20);
          final shineProgress =
              (progress / 0.62).clamp(0.0, 1.0).toDouble();
          final shine = -2.4 + (4.8 * shineProgress);

          return Semantics(
            button: true,
            label: 'Informations sur le paiement',
            child: Transform.translate(
              offset: Offset(shake, 0),
              child: Transform.scale(
                scale: scale,
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1A73E8), Color(0xFF0D5FD1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1A73E8)
                              .withValues(alpha: glow),
                          blurRadius: 12 + (glow * 8),
                          spreadRadius: 0.5 + (glow * 0.8),
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: widget.onTap,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 5,
                              ),
                              child: SizedBox(
                                width: 44,
                                child: Center(
                                  child: Text(
                                    'Infos',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: IgnorePointer(
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
                          ],
                        ),
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

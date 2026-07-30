import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

class IliprestoSplashScreenClassic extends StatefulWidget {
  final Widget nextPage;
  final Duration splashDuration;
  final bool autoNavigate;

  const IliprestoSplashScreenClassic({
    super.key,
    required this.nextPage,
    this.splashDuration = const Duration(seconds: 3),
    this.autoNavigate = true,
  });

  @override
  State<IliprestoSplashScreenClassic> createState() =>
      _IliprestoSplashScreenClassicState();
}

class _IliprestoSplashScreenClassicState
    extends State<IliprestoSplashScreenClassic> with TickerProviderStateMixin {
  late final AnimationController _textController;
  late final AnimationController _logoController;
  late final Animation<double> _textScale;
  late final Animation<double> _textOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    );

    _textScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.96, end: 1.03)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.03, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
    ]).animate(_textController);

    _textOpacity = CurvedAnimation(
      parent: _textController,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
    );

    _logoScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.90, end: 1.03)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.03, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
    ]).animate(_logoController);

    _logoOpacity = CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );

    _logoController.forward();
    Future<void>.delayed(const Duration(milliseconds: 160), () {
      if (mounted) _textController.forward();
    });

    if (widget.autoNavigate) {
      _navTimer = Timer(widget.splashDuration, _goNext);
    }
  }

  void _goNext() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, __, ___) => widget.nextPage,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _textController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final logoSize = math.min(size.width * 0.30, 142.0);

          return Stack(
            fit: StackFit.expand,
            children: [
              const _ClassicSplitBackground(),
              const _ClassicCenterGlow(),
              const _ClassicBottomTint(),
              const _ClassicGrainOverlay(opacity: 0.07),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _logoController,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _logoOpacity.value,
                            child: Transform.scale(
                              scale: _logoScale.value,
                              child: child,
                            ),
                          );
                        },
                        child: _ClassicTopLogo(size: logoSize),
                      ),
                      const Spacer(flex: 3),
                      AnimatedBuilder(
                        animation: _textController,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _textOpacity.value,
                            child: Transform.scale(
                              scale: _textScale.value,
                              child: child,
                            ),
                          );
                        },
                        child: const _ClassicBrandTitle(),
                      ),
                      const Spacer(flex: 5),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ClassicTopLogo extends StatelessWidget {
  final double size;

  const _ClassicTopLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Logo iliprestō',
      image: true,
      child: SizedBox(
        key: const Key('ilipresto-splash-top-logo'),
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Container(
                width: size * 0.78,
                height: size * 0.78,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(size * 0.22),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x38000000),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                    BoxShadow(
                      color: Color(0x30FFFFFF),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
            Image.asset(
              'assets/images/ilipresto_splash_logo.webp',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _ClassicSplitBackground extends StatelessWidget {
  const _ClassicSplitBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF2250F4),
            Color(0xFF2250F4),
            Color(0xFFFF8A1D),
            Color(0xFFFF8A1D),
          ],
          stops: [0.0, 0.499, 0.501, 1.0],
        ),
      ),
    );
  }
}

class _ClassicCenterGlow extends StatelessWidget {
  const _ClassicCenterGlow();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FractionallySizedBox(
        widthFactor: 0.22,
        heightFactor: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.00),
                Colors.white.withValues(alpha: 0.08),
                Colors.white.withValues(alpha: 0.14),
                Colors.white.withValues(alpha: 0.06),
                Colors.white.withValues(alpha: 0.00),
              ],
              stops: const [0.0, 0.22, 0.48, 0.72, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClassicBottomTint extends StatelessWidget {
  const _ClassicBottomTint();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: const Alignment(0, 0.90),
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: 260,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                const Color(0xFFD2A4BC).withValues(alpha: 0.52),
                const Color(0xFFD2A4BC).withValues(alpha: 0.14),
                Colors.transparent,
              ],
              stops: const [0.0, 0.52, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClassicBrandTitle extends StatelessWidget {
  const _ClassicBrandTitle();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final fontSize = width < 360 ? 46.0 : 54.0;

    return Text(
      'iliprestō',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: 'Inter',
        fontFamilyFallback: const ['Inter'],
        fontSize: fontSize,
        height: 1,
        fontWeight: FontWeight.w800,
        letterSpacing: -2.4,
        color: Colors.white,
        shadows: const [
          Shadow(
            color: Color(0x28000000),
            offset: Offset(0, 8),
            blurRadius: 14,
          ),
          Shadow(
            color: Color(0x12000000),
            offset: Offset(0, 2),
            blurRadius: 2,
          ),
        ],
      ),
    );
  }
}

class _ClassicGrainOverlay extends StatelessWidget {
  final double opacity;

  const _ClassicGrainOverlay({required this.opacity});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _ClassicNoisePainter(opacity: opacity),
        size: Size.infinite,
      ),
    );
  }
}

class _ClassicNoisePainter extends CustomPainter {
  final double opacity;

  const _ClassicNoisePainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    const spacing = 6.0;

    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        final n = _hash(x, y);
        final alpha = (n * 255 * opacity).clamp(0, 255).toInt();
        paint.color = Color.fromARGB(alpha, 255, 255, 255);
        canvas.drawRect(
          Rect.fromLTWH(
            x + (n - 0.5) * 1.8,
            y + (n - 0.5) * 1.8,
            1.2,
            1.2,
          ),
          paint,
        );
      }
    }
  }

  double _hash(double x, double y) {
    final v = math.sin(x * 12.9898 + y * 78.233) * 43758.5453;
    return v - v.floorToDouble();
  }

  @override
  bool shouldRepaint(covariant _ClassicNoisePainter oldDelegate) {
    return oldDelegate.opacity != opacity;
  }
}

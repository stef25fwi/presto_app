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
    this.splashDuration = const Duration(milliseconds: 2200),
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
        tween: Tween(begin: 0.92, end: 1.02)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.02, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
    ]).animate(_logoController);

    _logoOpacity = CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );

    _textController.forward();
    Future.delayed(const Duration(milliseconds: 160), () {
      if (mounted) _logoController.forward();
    });

    if (widget.autoNavigate) {
      _navTimer = Timer(widget.splashDuration, _goNext);
    }
  }

  void _goNext() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
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
          final logoSize = math.min(size.width * 0.52, 300.0);

          return Stack(
            fit: StackFit.expand,
            children: [
              const _ClassicSplitBackground(),
              const _ClassicCenterGlow(),
              const _ClassicBottomTint(),
              const _ClassicGrainOverlay(opacity: 0.07),
              SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),
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
                    const Spacer(flex: 2),
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
                      child: _ClassicCenterLogo(size: logoSize),
                    ),
                    const Spacer(flex: 3),
                  ],
                ),
              ),
            ],
          );
        },
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
    return const Text(
      'iliprestō',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: 'Inter',
        fontFamilyFallback: ['Inter'],
        fontSize: 54,
        height: 1,
        fontWeight: FontWeight.w800,
        letterSpacing: -2.4,
        color: Colors.white,
        shadows: [
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

class _ClassicCenterLogo extends StatelessWidget {
  final double size;

  const _ClassicCenterLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: size * 0.03,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                width: size * 0.55,
                height: size * 0.12,
                decoration: BoxDecoration(
                  color: const Color(0x662F3654),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
          ),
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: CustomPaint(
              size: Size(size, size),
              painter: _ClassicLogoGlowPainter(),
            ),
          ),
          CustomPaint(
            size: Size(size, size),
            painter: _ClassicLogoPainter(),
          ),
        ],
      ),
    );
  }
}

class _ClassicLogoGlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      size.width * 0.12,
      size.height * 0.12,
      size.width * 0.76,
      size.height * 0.76,
    );

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0.18),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(rect.inflate(30));

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.inflate(8),
        Radius.circular(size.width * 0.16),
      ),
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ClassicLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      size.width * 0.12,
      size.height * 0.12,
      size.width * 0.76,
      size.height * 0.76,
    );

    final radius = Radius.circular(size.width * 0.14);
    final rrect = RRect.fromRectAndRadius(rect, radius);

    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Color(0xFF2250F4),
          Color(0xFF2250F4),
          Color(0xFFFF8A1D),
          Color(0xFFFF8A1D),
        ],
        stops: [0.0, 0.499, 0.501, 1.0],
      ).createShader(rect);

    canvas.drawRRect(rrect, fillPaint);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.014
      ..color = Colors.white.withValues(alpha: 0.92)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(rrect, borderPaint);

    final whitePaint = Paint()..color = const Color(0xFFF6F6F6);
    final shadowPaint = Paint()
      ..color = const Color(0x22000000)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.012);

    final leftCenterX = rect.left + rect.width * 0.32;
    final rightCenterX = rect.left + rect.width * 0.68;
    final dotY = rect.top + rect.height * 0.30;
    final stemTop = rect.top + rect.height * 0.43;
    final stemHeight = rect.height * 0.32;
    final stemWidth = rect.width * 0.16;
    final dotRadius = rect.width * 0.08;

    void drawIPillar(double x) {
      final stemRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x, stemTop + stemHeight / 2),
          width: stemWidth,
          height: stemHeight,
        ),
        Radius.circular(stemWidth * 0.18),
      );

      canvas.drawCircle(Offset(x, dotY + 3), dotRadius, shadowPaint);
      canvas.drawRRect(stemRect.shift(const Offset(0, 4)), shadowPaint);
      canvas.drawCircle(Offset(x, dotY), dotRadius, whitePaint);
      canvas.drawRRect(stemRect, whitePaint);
    }

    drawIPillar(leftCenterX);
    drawIPillar(rightCenterX);

    final smilePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = rect.width * 0.055
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFF6F6F6);

    final smileShadowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = rect.width * 0.055
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x22000000)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.01);

    final smilePath = Path()
      ..moveTo(rect.left + rect.width * 0.38, rect.top + rect.height * 0.73)
      ..quadraticBezierTo(
        rect.left + rect.width * 0.50,
        rect.top + rect.height * 0.84,
        rect.left + rect.width * 0.64,
        rect.top + rect.height * 0.75,
      );

    canvas.drawPath(smilePath.shift(const Offset(0, 3)), smileShadowPaint);
    canvas.drawPath(smilePath, smilePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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

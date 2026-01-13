import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';

class SplashScreenV2 extends StatefulWidget {
  const SplashScreenV2({super.key});

  @override
  State<SplashScreenV2> createState() => _SplashScreenV2State();
}

class _SplashScreenV2State extends State<SplashScreenV2>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bumpCtrl;

  // Durée mini d'affichage (évite un flash si ça charge très vite)
  static const Duration _minSplash = Duration(milliseconds: 900);

  // Timeout sécurité (si réseau lent, on ouvre quand même Home)
  static const Duration _maxWait = Duration(seconds: 4);

  @override
  void initState() {
    super.initState();

    // Effet bump: petite pulsation douce
    _bumpCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..repeat(reverse: true);

    _boot();
  }

  Future<void> _boot() async {
    final stopwatch = Stopwatch()..start();

    // Précharge en parallèle : annonces + (optionnel) autres datas
    Future<void> preload = Future.wait([
      _preloadHomeOffers(limit: 30), // ✅ "Dernières offres" sera déjà prêt
      // Optionnel: ajouter d'autres préchargements
    ]).timeout(_maxWait, onTimeout: () {
      // On ne bloque pas l'ouverture si le réseau est lent.
      debugPrint('⏱️ Timeout préchargement, on continue');
      return [];
    });

    // Affichage min du splash
    final minDelay = Future<void>.delayed(_minSplash);

    await Future.wait([preload, minDelay]);

    stopwatch.stop();

    if (!mounted) return;

    // ✅ Navigation vers Home
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomePage(),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  Future<void> _preloadHomeOffers({required int limit}) async {
    try {
      await FirebaseFirestore.instance
          .collection('offers')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
    } catch (e) {
      // Ignorer les erreurs de préchargement
      debugPrint('Erreur préchargement offres: $e');
    }
  }

  @override
  void dispose() {
    _bumpCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const kPrestoOrange = Color(0xFFFF6600);
    const kPrestoBlue = Color(0xFF1A73E8);
    final w = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background split bleu/orange
          Row(
            children: const [
              Expanded(child: ColoredBox(color: kPrestoBlue)),
              Expanded(child: ColoredBox(color: kPrestoOrange)),
            ],
          ),

          // Légère brume / texture en bas
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.white.withOpacity(0.08),
                      Colors.white.withOpacity(0.14),
                    ],
                    stops: const [0.0, 0.55, 0.78, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // Contenu
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 36),

                // "iliprestō" bump
                AnimatedBuilder(
                  animation: _bumpCtrl,
                  builder: (_, __) {
                    // Bump doux: scale + micro-translation
                    final t = CurvedAnimation(
                      parent: _bumpCtrl,
                      curve: Curves.easeInOut,
                    ).value;

                    final scale = 1.0 + (0.06 * t); // 6% max
                    final dy = -2.0 * t;

                    return Transform.translate(
                      offset: Offset(0, dy),
                      child: Transform.scale(
                        scale: scale,
                        child: Text(
                          'iliprestō',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: w * 0.11,
                            height: 1.0,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const Spacer(),

                // Icone flat + contour blanc
                _FlatLogoOutlined(
                  size: w * 0.56,
                  borderWidth: math.max(5, w * 0.012),
                ),

                const Spacer(),

                const SizedBox(height: 22),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FlatLogoOutlined extends StatelessWidget {
  final double size;
  final double borderWidth;

  const _FlatLogoOutlined({
    required this.size,
    required this.borderWidth,
  });

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.18;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white, width: borderWidth),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Row(
            children: const [
              Expanded(child: ColoredBox(color: Color(0xFF1A73E8))),
              Expanded(child: ColoredBox(color: Color(0xFFFF6600))),
            ],
          ),

          // séparation centrale
          Align(
            alignment: Alignment.center,
            child: Container(width: borderWidth, color: Colors.white),
          ),

          // "i" gauche
          Align(
            alignment: Alignment.centerLeft,
            child: _IShape(
              sidePadding: size * 0.18,
              color: Colors.white,
              height: size * 0.54,
              dot: size * 0.11,
              stemWidth: size * 0.16,
              stemRadius: size * 0.05,
            ),
          ),

          // "i" droite
          Align(
            alignment: Alignment.centerRight,
            child: _IShape(
              sidePadding: size * 0.18,
              color: Colors.white,
              height: size * 0.54,
              dot: size * 0.11,
              stemWidth: size * 0.16,
              stemRadius: size * 0.05,
            ),
          ),

          // Smile
          Positioned(
            left: size * 0.20,
            right: size * 0.20,
            bottom: size * 0.20,
            child: CustomPaint(
              size: Size(size * 0.60, size * 0.20),
              painter: _SmilePainter(
                color: Colors.white,
                strokeWidth: size * 0.085,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IShape extends StatelessWidget {
  final double sidePadding;
  final Color color;
  final double height;
  final double dot;
  final double stemWidth;
  final double stemRadius;

  const _IShape({
    required this.sidePadding,
    required this.color,
    required this.height,
    required this.dot,
    required this.stemWidth,
    required this.stemRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: sidePadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: dot,
            height: dot,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(height: height * 0.10),
          Container(
            width: stemWidth,
            height: height,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(stemRadius),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmilePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _SmilePainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(0, size.height * 0.25);
    path.quadraticBezierTo(
      size.width * 0.50,
      size.height * 1.10,
      size.width,
      size.height * 0.25,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SmilePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

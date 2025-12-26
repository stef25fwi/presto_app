import 'dart:math' as math;
import 'package:flutter/material.dart';

class EntrepreneurToolboxSlide extends StatefulWidget {
  final VoidCallback? onTap;
  const EntrepreneurToolboxSlide({super.key, this.onTap});

  @override
  State<EntrepreneurToolboxSlide> createState() => _EntrepreneurToolboxSlideState();
}

class _EntrepreneurToolboxSlideState extends State<EntrepreneurToolboxSlide>
    with SingleTickerProviderStateMixin {
  // Couleurs Prestō (à aligner sur tes constantes si tu en as déjà)
  static const Color kOrange = Color(0xFFFF6600);
  static const Color kPrestoBlue = Color(0xFF1A73E8);

  late final AnimationController _ctl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();

    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _opacity = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(parent: _ctl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ajuste facilement la taille/position en un seul endroit
    const double iconSize = 112;      // cercle blanc
    const double arrowSize = 58;      // longueur visuelle de la flèche
    const double gap = 14;            // distance flèche ↔ icône
    const double topArrowAngleDeg = -35;
    const double bottomArrowAngleDeg = 35;

    return Container(
      decoration: BoxDecoration(
        color: kOrange,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // TEXTES
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "PRO",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  "Boîte à outils de\nl’entrepreneur",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  "Liens utiles CCI, Région, aides et infos clés.",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.70),
                    fontSize: 18,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // ZONE ICONE + FLÈCHES
          Positioned(
            right: 18,
            top: 86,
            child: SizedBox(
              width: 170,
              height: 240,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // ICONE "i" + OMBRE (effet 3D) + TAP
                  Positioned(
                    right: 0,
                    top: 56,
                    child: GestureDetector(
                      onTap: widget.onTap,
                      behavior: HitTestBehavior.opaque,
                      child: _InfoIcon3D(
                        size: iconSize,
                        blue: kPrestoBlue,
                      ),
                    ),
                  ),

                  // FLÈCHES (toutes identiques) + micro pulsation opacity
                  // 1) flèche TOP (diagonale)
                  Positioned(
                    right: iconSize * 0.55,
                    top: 10,
                    child: AnimatedBuilder(
                      animation: _opacity,
                      builder: (_, __) => Opacity(
                        opacity: _opacity.value,
                        child: Transform.rotate(
                          angle: _degToRad(topArrowAngleDeg),
                          child: _InstitutionalArrow(
                            size: arrowSize,
                            color: kPrestoBlue,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 2) flèche LEFT (horizontale)
                  Positioned(
                    right: iconSize + gap,
                    top: 100,
                    child: AnimatedBuilder(
                      animation: _opacity,
                      builder: (_, __) => Opacity(
                        opacity: _opacity.value,
                        child: _InstitutionalArrow(
                          size: arrowSize,
                          color: kPrestoBlue,
                        ),
                      ),
                    ),
                  ),

                  // 3) flèche BOTTOM (diagonale)
                  Positioned(
                    right: iconSize * 0.55,
                    top: 176,
                    child: AnimatedBuilder(
                      animation: _opacity,
                      builder: (_, __) => Opacity(
                        opacity: _opacity.value,
                        child: Transform.rotate(
                          angle: _degToRad(bottomArrowAngleDeg),
                          child: _InstitutionalArrow(
                            size: arrowSize,
                            color: kPrestoBlue,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // DOTS (optionnel)
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _dot(false),
                const SizedBox(width: 8),
                _pill(true),
                const SizedBox(width: 8),
                _dot(false),
                const SizedBox(width: 8),
                _dot(false),
                const SizedBox(width: 8),
                _dot(false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static double _degToRad(double deg) => deg * math.pi / 180.0;

  Widget _dot(bool active) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.white.withOpacity(0.35),
          shape: BoxShape.circle,
        ),
      );

  Widget _pill(bool active) => Container(
        width: 26,
        height: 10,
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.white.withOpacity(0.35),
          borderRadius: BorderRadius.circular(999),
        ),
      );
}

/// Icône info avec effet “3D” (ombre + léger relief)
class _InfoIcon3D extends StatelessWidget {
  final double size;
  final Color blue;

  const _InfoIcon3D({
    required this.size,
    required this.blue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          // Ombre douce pour effet 3D
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
          // Mini “liseré” de relief
          BoxShadow(
            color: Colors.white.withOpacity(0.6),
            blurRadius: 2,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Center(
        child: Text(
          "i",
          style: TextStyle(
            color: blue,
            fontSize: size * 0.62,
            height: 1.0,
            fontWeight: FontWeight.w800,
            shadows: [
              // léger relief sur la lettre
              Shadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Flèche “institutionnelle” (pleine, propre) – TOUTES IDENTIQUES
class _InstitutionalArrow extends StatelessWidget {
  final double size;
  final Color color;

  const _InstitutionalArrow({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Une flèche simple, propre, et scalable
    return CustomPaint(
      size: Size(size, size * 0.55),
      painter: _ArrowPainter(color: color),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  final Color color;
  _ArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final w = size.width;
    final h = size.height;

    // Flèche propre type “institutionnel”
    // - tige rectangulaire + pointe triangulaire
    final shaftH = h * 0.40;
    final shaftY = (h - shaftH) / 2;
    final headW = w * 0.34;

    final path = Path()
      // tige
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, shaftY, w - headW, shaftH),
        Radius.circular(shaftH * 0.22),
      ))
      // pointe
      ..moveTo(w - headW, 0)
      ..lineTo(w, h / 2)
      ..lineTo(w - headW, h)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter oldDelegate) =>
      oldDelegate.color != color;
}

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final containerWidth = constraints.maxWidth;
        final containerHeight = constraints.maxHeight;
        
        // Tailles basées sur la largeur du container
        final iconSize = containerWidth * 0.28;
        final arrowSize = containerWidth * 0.145;
        
        // Fonts responsives
        final titleFontSize = containerWidth * 0.095;
        final subtitleFontSize = containerWidth * 0.045;
        final badgeFontSize = containerWidth * 0.04;
        
        // Paddings responsifs
        final horizontalPad = containerWidth * 0.055;
        final topPad = containerHeight * 0.08;
        final bottomPad = containerHeight * 0.06;
        final gapVertical = containerHeight * 0.04;
        final gapVerticalLarge = containerHeight * 0.05;
        final borderRadius = containerWidth * 0.055;
        
        const double topArrowAngleDeg = -35;
        const double bottomArrowAngleDeg = 35;

        return Container(
          decoration: BoxDecoration(
            color: kOrange,
            borderRadius: BorderRadius.circular(borderRadius),
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
                padding: EdgeInsets.fromLTRB(
                  horizontalPad,
                  topPad,
                  horizontalPad,
                  bottomPad,
                ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "PRO",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: badgeFontSize,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                SizedBox(height: gapVertical),
                Text(
                  "Boîte à outils de\nl’entrepreneur",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: titleFontSize,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: gapVerticalLarge),
                Text(
                  "Liens utiles CCI, Région, aides et infos clés.",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.70),
                    fontSize: subtitleFontSize,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

              // ZONE ICONE + FLÈCHES
              Positioned(
                right: containerWidth * 0.045,
                top: containerHeight * 0.25,
                child: SizedBox(
                  width: containerWidth * 0.38,
                  height: containerHeight * 0.7,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // ICONE "i" + OMBRE (effet 3D) + TAP
                  Positioned(
                    right: 0,
                    top: containerHeight * 0.15,
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
                    right: containerWidth * 0.18,
                    top: containerHeight * 0.02,
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
                    right: containerWidth * 0.195,
                    top: containerHeight * 0.32,
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
                    right: containerWidth * 0.18,
                    top: containerHeight * 0.55,
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

              // DOTS (responsif)
              Positioned(
                left: 0,
                right: 0,
                bottom: containerHeight * 0.04,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _dot(containerWidth * 0.025, false),
                    SizedBox(width: containerWidth * 0.02),
                    _pill(containerWidth * 0.065, containerWidth * 0.025, true),
                    SizedBox(width: containerWidth * 0.02),
                    _dot(containerWidth * 0.025, false),
                    SizedBox(width: containerWidth * 0.02),
                    _dot(containerWidth * 0.025, false),
                    SizedBox(width: containerWidth * 0.02),
                    _dot(containerWidth * 0.025, false),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static double _degToRad(double deg) => deg * math.pi / 180.0;

  Widget _dot(double size, bool active) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.white.withOpacity(0.35),
          shape: BoxShape.circle,
        ),
      );

  Widget _pill(double width, double height, bool active) => Container(
        width: width,
        height: height,
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
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: size * 0.16,
            offset: Offset(0, size * 0.09),
          ),
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
              Shadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: size * 0.054,
                offset: Offset(0, size * 0.018),
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

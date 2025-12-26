import 'dart:math' as math;
import 'package:flutter/material.dart';

class EntrepreneurToolboxSlide extends StatelessWidget {
  const EntrepreneurToolboxSlide({super.key});

  // Couleurs Prestō (ajuste si tu as déjà des constantes)
  static const Color kPrestoOrange = Color(0xFFFF6600);
  static const Color kPrestoBlue = Color(0xFF1A73E8);

  @override
  Widget build(BuildContext context) {
    // Paramètres (proportions propres)
    const double iconSize = 112;
    const double arrowSize = 62; // toutes identiques
    const double gap = 14;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      decoration: BoxDecoration(
        color: kPrestoOrange,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // TEXTES (mêmes tailles que ton slide 1 "marketing")
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "PRO",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.70),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  "Boîte à outils de\nl'entrepreneur",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 40, // gros titre (proche de ton rendu)
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  "Liens utiles CCI, Région, aides et infos clés.",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 19,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // ICON + FLÈCHES
          Positioned(
            right: 18,
            top: 86,
            child: SizedBox(
              width: 190,
              height: 240,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Icône "i" cliquable -> page EntrepreneurToolboxPage
                  Positioned(
                    right: 0,
                    top: 56,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const EntrepreneurToolboxPage(),
                          ),
                        );
                      },
                      child: _InfoIcon3D(
                        size: iconSize,
                        blue: kPrestoBlue,
                      ),
                    ),
                  ),

                  // 3 flèches identiques (institutionnelles)
                  // Top (diagonale)
                  Positioned(
                    right: iconSize * 0.55,
                    top: 8,
                    child: Transform.rotate(
                      angle: _degToRad(-35),
                      child: const _InstitutionalArrow(
                        size: arrowSize,
                        color: kPrestoBlue,
                      ),
                    ),
                  ),

                  // Gauche (horizontale)
                  Positioned(
                    right: iconSize + gap,
                    top: 100,
                    child: const _InstitutionalArrow(
                      size: arrowSize,
                      color: kPrestoBlue,
                    ),
                  ),

                  // Bas (diagonale)
                  Positioned(
                    right: iconSize * 0.55,
                    top: 176,
                    child: Transform.rotate(
                      angle: _degToRad(35),
                      child: const _InstitutionalArrow(
                        size: arrowSize,
                        color: kPrestoBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ❌ Pas de points en bas (supprimés)
        ],
      ),
    );
  }

  static double _degToRad(double deg) => deg * math.pi / 180.0;
}

/// Icône info avec effet 3D (ombre)
class _InfoIcon3D extends StatelessWidget {
  final double size;
  final Color blue;

  const _InfoIcon3D({required this.size, required this.blue});

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
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.65),
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

/// Flèche "institutionnelle" (pleine et propre) – toutes identiques
class _InstitutionalArrow extends StatelessWidget {
  final double size;
  final Color color;

  const _InstitutionalArrow({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 0.55),
      painter: _ArrowPainter(color),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  final Color color;
  _ArrowPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final w = size.width;
    final h = size.height;

    final shaftH = h * 0.40;
    final shaftY = (h - shaftH) / 2;
    final headW = w * 0.34;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, shaftY, w - headW, shaftH),
          Radius.circular(shaftH * 0.22),
        ),
      )
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

/// ✅ Remplace par TON import réel
/// Exemple:
/// import 'package:presto_app/pages/entrepreneur_toolbox_page.dart';
class EntrepreneurToolboxPage extends StatelessWidget {
  const EntrepreneurToolboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text("EntrepreneurToolboxPage")),
    );
  }
}

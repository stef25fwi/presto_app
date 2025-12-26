import 'package:flutter/material.dart';
import 'package:presto_app/pages/entrepreneur_toolbox_page.dart';

class EntrepreneurToolboxSlide extends StatelessWidget {
  const EntrepreneurToolboxSlide({super.key});

  // Couleurs Prestō
  static const Color kPrestoOrange = Color(0xFFFF6600);
  static const Color kPrestoBlue = Color(0xFF1A73E8);

  @override
  Widget build(BuildContext context) {
    const double iconSize = 112;

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
          // TEXTES
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "PRO",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.70),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Boîte à outils de\nl'entrepreneur",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    height: 1.25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Liens utiles CCI, Région, aides et infos clés.",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.70),
                    fontSize: 14,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // ICÔNE SEULE (sans flèches)
          Positioned(
            right: 18,
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
        ],
      ),
    );
  }
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

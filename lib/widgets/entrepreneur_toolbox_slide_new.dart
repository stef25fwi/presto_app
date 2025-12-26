import 'package:flutter/material.dart';

class EntrepreneurToolboxSlide extends StatelessWidget {
  const EntrepreneurToolboxSlide({super.key});

  static const Color kOrange = Color(0xFFFF6600);
  static const Color kPrestoBlue = Color(0xFF1A73E8);

  @override
  Widget build(BuildContext context) {
    const double iconSize = 70;

    return Container(
      decoration: BoxDecoration(
        color: kOrange,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "PRO",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.70),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Boîte à outils de l'entrepreneur",
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Liens utiles CCI, Région, aides et infos clés.",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.70),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _InfoIcon3D(
              size: iconSize,
              blue: kPrestoBlue,
            ),
          ],
        ),
      ),
    );
  }
}

/// Icône info avec effet "3D" (ombre + léger relief)
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
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.6),
            blurRadius: 2,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Icon(
        Icons.business_center_outlined,
        color: blue,
        size: 32,
      ),
    );
  }
}

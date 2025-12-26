import 'package:flutter/material.dart';
import 'package:presto_app/pages/entrepreneur_toolbox_page.dart';
import 'package:presto_app/widgets/presto_info_icon_animated.dart';

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

          // ICÔNE ANIMÉE
          Positioned(
            right: 18,
            top: 42,
            child: PrestoInfoIconAnimated(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const EntrepreneurToolboxPage(),
                  ),
                );
              },
              showBadge: true,
              badgeText: "Nouveau",
            ),
          ),
        ],
      ),
    );
  }
}

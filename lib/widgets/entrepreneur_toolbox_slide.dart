import 'package:flutter/material.dart';
import 'package:presto_app/pages/toolbox_hub_page.dart';
import 'package:presto_app/widgets/presto_info_icon_animated.dart';

class EntrepreneurToolboxSlide extends StatelessWidget {
  const EntrepreneurToolboxSlide({super.key});

  // Couleurs Prestō
  static const Color kPrestoOrange = Color(0xFFFF6600);
  static const Color kPrestoBlue = Color(0xFF1A73E8);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 0),
      decoration: BoxDecoration(
        color: kPrestoOrange,
        borderRadius: BorderRadius.zero,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
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
                    color: Colors.white.withValues(alpha: 0.70),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Boîte à outils de\nl'entrepreneur",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    height: 1.25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Liens utiles CCI, Région, aides et infos clés.",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.70),
                    fontSize: 15,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // BOUTON INFO ANIMÉ AVEC BUMP ET VIBRATION
          Positioned(
            right: 18,
            top: 12,
            child: PrestoInfoIconAnimated(
              size: 130,
              badgeText: 'Clique ici!',
              showBadge: true,
              centerChild: Transform.translate(
                offset: const Offset(0, -1.5),
                child: Text(
                  'I',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: kPrestoBlue,
                    fontSize: 68,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ToolboxHubPage(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

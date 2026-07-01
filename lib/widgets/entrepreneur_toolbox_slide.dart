import 'package:flutter/material.dart';
import 'package:presto_app/pages/toolbox_hub_page.dart';
import 'package:presto_app/widgets/presto_info_icon_animated.dart';

class EntrepreneurToolboxSlide extends StatelessWidget {
  const EntrepreneurToolboxSlide({super.key});

  // Couleurs Prestō
  static const Color kPrestoOrange = Color(0xFFFF6600);
  static const Color kPrestoBlue = Color(0xFF1A73E8);

  void _openToolbox(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ToolboxHubPage(),
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    return GestureDetector(
      onTap: () => _openToolbox(context),
      child: Container(
        height: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: kPrestoOrange,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: kPrestoBlue,
            width: 1.8,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                "Boites a outils de l'entrepreneur",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0D6EFD),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0D6EFD).withValues(alpha: 0.45),
                    blurRadius: 10,
                    spreadRadius: 0.5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                'Cliquez ici',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return Container(
      height: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 0),
      decoration: BoxDecoration(
        color: kPrestoOrange,
        borderRadius: BorderRadius.circular(20),
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
                  "Boites a outils de\nl'entrepreneur",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    height: 1.25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Liens utiles CCI, Region, aides et infos cles.",
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
          Positioned(
            right: 18,
            top: 12,
            child: PrestoInfoIconAnimated(
              size: 130,
              badgeText: 'Cliquez ici',
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
              onTap: () => _openToolbox(context),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight <= 130;
        if (isCompact) return _buildCompact(context);
        return _buildHero(context);
      },
    );
  }
}

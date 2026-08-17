import 'package:flutter/material.dart';
import 'package:presto_app/pages/toolbox_page.dart';
import 'package:presto_app/widgets/presto_info_icon_animated.dart';
import 'package:presto_app/widgets/presto_tap_target.dart';
import 'package:presto_app/widgets/rocket_takeoff_icon.dart';

class EntrepreneurToolboxSlide extends StatelessWidget {
  const EntrepreneurToolboxSlide({super.key});

  static const Color kPrestoOrange = Color(0xFFFF6600);
  static const Color kPrestoBlue = Color(0xFF1A73E8);

  void _openToolbox(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ToolboxPage(),
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    return PrestoTapTarget(
      semanticLabel: "Boîte à outils de l'entrepreneur",
      color: kPrestoOrange,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Boite a outils de l'entrepreneur",
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                height: 1.12,
              ),
            ),
            const Spacer(),
            SizedBox(
              height: 32,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const RocketTakeoffIcon(),
                  const Spacer(),
                  const _VibrantPulseChip(label: 'Cliquez ici'),
                ],
              ),
            ),
            const SizedBox(height: 5),
            const Row(
              children: [
                Expanded(
                  child: _CompactTutorialBanner(),
                ),
              ],
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
                  "Boite a outils de\nl'entrepreneur",
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

class _VibrantPulseChip extends StatefulWidget {
  const _VibrantPulseChip({required this.label});

  final String label;

  @override
  State<_VibrantPulseChip> createState() => _VibrantPulseChipState();
}

class _VibrantPulseChipState extends State<_VibrantPulseChip>
    with TickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scale;
  late final AnimationController _vibrationController;
  late final Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scale = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );

    _vibrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..repeat(reverse: true);

    _rotation = Tween<double>(begin: -0.02, end: 0.02).animate(
      CurvedAnimation(parent: _vibrationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _vibrationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_scaleController, _vibrationController]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scale.value,
          child: Transform.rotate(
            angle: _rotation.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1A73E8),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        );
      },
      child: Text(
        widget.label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CompactTutorialBanner extends StatelessWidget {
  const _CompactTutorialBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Color(0xFFFF6600),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: const [
          Icon(
            Icons.play_circle_fill_rounded,
            size: 15,
            color: Colors.white,
          ),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'Tutoriel: je me lance!',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

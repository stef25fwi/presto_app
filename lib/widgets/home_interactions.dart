import 'package:flutter/material.dart';

import '../utils/friendly_snackbar.dart';
import '../utils/runtime_action_logger.dart';

const _homePrestoOrange = Color(0xFFFF6600);
const _homePrestoBlue = Color(0xFF1A73E8);
const _homeMarketplaceOutlineWidth = 2.0;

class HomeSlide {
  final String title;
  final String subtitle;
  final String badge;
  final IconData? icon;
  final String? imageAsset;

  const HomeSlide({
    required this.title,
    required this.subtitle,
    required this.badge,
    this.icon,
    this.imageAsset,
  });
}

class PrestoTapScale extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const PrestoTapScale({
    super.key,
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Widget réutilisable : InkWell fournit gratuitement le focus clavier,
    // l'activation Entrée/Espace et la sémantique bouton à chaque usage,
    // sans qu'un appelant ait à y penser individuellement.
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: AnimatedScale(
          scale: 1.0,
          duration: const Duration(milliseconds: 120),
          child: child,
        ),
      ),
    );
  }
}

class HomeCategoryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final double iconScale;

  const HomeCategoryChip({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.iconScale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return PrestoTapScale(
      onTap: onTap ??
          () {
            logRuntimeAction(
              area: 'home',
              action: 'category-coming-soon',
              details: <String, Object?>{
                'category': label,
              },
            );
            showSuccessSnackBar(
              context,
              'Catégorie "$label" : bientôt disponible',
            );
          },
      child: SizedBox(
        height: 86,
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _homePrestoOrange,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _homePrestoBlue,
                  width: _homeMarketplaceOutlineWidth,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                  const BoxShadow(
                    color: Color(0x2B1A73E8),
                    blurRadius: 18,
                    spreadRadius: 0.5,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: Transform.scale(
                  scale: iconScale,
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 25,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 72,
              height: 28,
              child: Align(
                alignment: Alignment.topCenter,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  strutStyle: const StrutStyle(
                    fontSize: 11,
                    height: 1.15,
                    forceStrutHeight: true,
                  ),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PrestoNotificationBellBase extends StatelessWidget {
  final int badgeCount;
  final bool showBackground;
  final Color iconColor;

  const PrestoNotificationBellBase({
    super.key,
    required this.badgeCount,
    this.showBackground = true,
    this.iconColor = Colors.black87,
  });

  @override
  Widget build(BuildContext context) {
    final String? label;
    if (badgeCount <= 0) {
      label = null;
    } else if (badgeCount > 9) {
      label = '9+';
    } else {
      label = badgeCount.toString();
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: showBackground
              ? BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                )
              : null,
          child: Icon(
            Icons.notifications_none_outlined,
            size: 22,
            color: iconColor,
          ),
        ),
        if (label != null)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

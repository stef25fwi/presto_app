import 'package:flutter/material.dart';

import '../app/presto_design_tokens.dart';
import '../utils/friendly_snackbar.dart';
import '../utils/runtime_action_logger.dart';
import 'presto_accessible_action.dart';

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

class PrestoTapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final String? semanticHint;
  final bool? selected;
  final BorderRadius borderRadius;

  const PrestoTapScale({
    super.key,
    required this.child,
    this.onTap,
    this.semanticLabel,
    this.semanticHint,
    this.selected,
    this.borderRadius = const BorderRadius.all(
      Radius.circular(PrestoRadii.md),
    ),
  });

  @override
  State<PrestoTapScale> createState() => _PrestoTapScaleState();
}

class _PrestoTapScaleState extends State<PrestoTapScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return PrestoAccessibleAction(
      onActivate: widget.onTap,
      enabled: widget.onTap != null,
      semanticLabel: widget.semanticLabel,
      semanticHint: widget.semanticHint,
      selected: widget.selected,
      borderRadius: widget.borderRadius,
      excludeChildSemantics: widget.semanticLabel != null,
      onPressedChanged: (value) => setState(() => _pressed = value),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
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
    final action = onTap ??
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
        };

    return PrestoTapScale(
      onTap: action,
      semanticLabel: 'Catégorie $label',
      semanticHint: 'Afficher les annonces de la catégorie $label',
      borderRadius: BorderRadius.circular(PrestoRadii.md),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: PrestoColors.brandOrange,
              shape: BoxShape.circle,
              border: Border.all(
                color: PrestoColors.brandBlue,
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
            width: 64,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),
          ),
        ],
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

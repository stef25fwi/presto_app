import 'dart:async';

import 'package:flutter/material.dart';

/// Bouton premium AI style Material 3
/// Grand bouton bleu en forme de pilule avec dégradé et ombre douce
class PremiumAiButton extends StatelessWidget {
  final FutureOr<void> Function()? onPressed;
  final String label;
  final double width;
  final bool isLoading;
  final IconData icon;
  final List<Color>? gradientColors;
  final Color? shadowColor;

  const PremiumAiButton({
    super.key,
    required this.onPressed,
    this.label = 'Décrire mon besoin (IA)',
    this.width = 0.92, // 92% de la largeur
    this.isLoading = false,
    this.icon = Icons.auto_awesome,
    this.gradientColors,
    this.shadowColor,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonWidth = screenWidth * width;
    final effectiveGradientColors =
        gradientColors ?? const [Color(0xFF2D84F6), Color(0xFF1A73E8)];
    final effectiveShadowColor = shadowColor ?? effectiveGradientColors.last;
    final disabled = isLoading || onPressed == null;

    return Semantics(
      button: true,
      enabled: !disabled,
      label: label,
      child: Container(
        width: buttonWidth,
        height: 56, // Entre 54-58px
        decoration: BoxDecoration(
          // Dégradé vertical : bleu plus clair en haut → plus profond en bas
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: effectiveGradientColors,
          ),
          borderRadius: BorderRadius.circular(20), // Forme de pilule (18-22px)
          // Ombre douce
          boxShadow: [
            BoxShadow(
              color: effectiveShadowColor.withValues(alpha: 0.22),
              blurRadius: 14, // Entre 12-16
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: effectiveGradientColors.first.withValues(alpha: 0.10),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: disabled
                ? null
                : () {
                    onPressed!();
                  },
            borderRadius: BorderRadius.circular(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icône sparkles blanc
                if (!isLoading) ...[
                  const SizedBox(width: 4),
                  Icon(
                    icon,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                ],

                // Texte centré
                if (isLoading)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withValues(alpha: 0.9),
                      ),
                      strokeWidth: 2,
                    ),
                  )
                else
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600, // Semi-bold
                          fontSize: 17, // Entre 16-18px
                          letterSpacing: 0.3,
                        ),
                    textAlign: TextAlign.center,
                  ),

                if (!isLoading) const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

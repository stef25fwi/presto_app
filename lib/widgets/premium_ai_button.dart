import 'package:flutter/material.dart';

/// Bouton premium AI style Material 3
/// Grand bouton bleu en forme de pilule avec dégradé et ombre douce
class PremiumAiButton extends StatefulWidget {
  final dynamic onPressed; // VoidCallback ou Future<void> Function()
  final String label;
  final double width;
  final bool isLoading;

  const PremiumAiButton({
    Key? key,
    required this.onPressed,
    this.label = 'Décrire mon besoin (IA)',
    this.width = 0.92, // 92% de la largeur
    this.isLoading = false,
  }) : super(key: key);

  @override
  State<PremiumAiButton> createState() => _PremiumAiButtonState();
}

class _PremiumAiButtonState extends State<PremiumAiButton> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonWidth = screenWidth * widget.width;

    return Container(
      width: buttonWidth,
      height: 56, // Entre 54-58px
      decoration: BoxDecoration(
        // Dégradé vertical : bleu plus clair en haut → plus profond en bas
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF2D84F6), // Bleu plus clair en haut
            Color(0xFF1A73E8), // Bleu principal plus profond en bas
          ],
        ),
        borderRadius: BorderRadius.circular(20), // Forme de pilule (18-22px)
        // Ombre douce
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A73E8).withOpacity(0.18), // 15-20% opacity
            blurRadius: 14, // Entre 12-16
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: (_isLoading || widget.isLoading || widget.onPressed == null)
              ? null
              : _handlePress,
          borderRadius: BorderRadius.circular(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icône sparkles blanc
              if (!widget.isLoading && !_isLoading) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.auto_awesome, // Sparkles icon
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
              ],

              // Texte centré
              if (widget.isLoading || _isLoading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withOpacity(0.9),
                    ),
                    strokeWidth: 2,
                  ),
                )
              else
                Text(
                  widget.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600, // Semi-bold
                        fontSize: 17, // Entre 16-18px
                        letterSpacing: 0.3,
                      ),
                  textAlign: TextAlign.center,
                ),

              if (!widget.isLoading && !_isLoading) const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handlePress() async {
    if (widget.onPressed == null) return;

    setState(() => _isLoading = true);

    try {
      if (widget.onPressed is Future<void> Function()) {
        await (widget.onPressed as Future<void> Function())();
      } else if (widget.onPressed is VoidCallback) {
        (widget.onPressed as VoidCallback)();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

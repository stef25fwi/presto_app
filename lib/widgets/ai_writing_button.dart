import 'package:flutter/material.dart';

import 'presto_tap_target.dart';

/// Bouton "Remplir avec l'IA". Extrait de `widgets/ai_publish_control.dart`
/// pour rester sous le budget de lignes d'un widget.
class AiWritingButton extends StatelessWidget {
  const AiWritingButton({
    super.key,
    required this.isAnalyzing,
    required this.onTap,
  });

  final bool isAnalyzing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: "Remplir les champs avec l'IA",
      child: PrestoTapTarget(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color:
                isAnalyzing ? const Color(0xFFE65500) : const Color(0xFFFF6600),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6600).withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isAnalyzing)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  isAnalyzing
                      ? 'Amélioration en cours…'
                      : "Appuyez pour améliorer votre description avec l'IA",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

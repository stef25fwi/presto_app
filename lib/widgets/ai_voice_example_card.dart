import 'package:flutter/material.dart';

/// Exemple guidé affiché avant l'enregistrement d'une annonce vocale.
class AiVoiceExampleCard extends StatelessWidget {
  const AiVoiceExampleCard({super.key});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF1A6FFF);
    const textColor = Color(0xFF334155);

    return Semantics(
      label:
          'Exemple à dire : Je cherche un jardinier pour tailler une haie et nettoyer mon jardin dans le secteur de votre commune.',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFC8D9FF)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.10),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FF),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.record_voice_over_rounded, size: 15, color: accent),
                  SizedBox(width: 6),
                  Text(
                    'Exemple à dire',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '“',
                  style: TextStyle(
                    height: 0.9,
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFB7D2FF),
                  ),
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                      children: [
                        TextSpan(text: 'Je cherche un '),
                        TextSpan(
                          text: 'jardinier',
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        TextSpan(text: ' pour '),
                        TextSpan(
                          text: 'tailler une haie et nettoyer mon jardin',
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        TextSpan(text: ' dans le secteur de '),
                        TextSpan(
                          text: '…',
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 6),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Text(
                    '”',
                    style: TextStyle(
                      height: 1.5,
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFB7D2FF),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

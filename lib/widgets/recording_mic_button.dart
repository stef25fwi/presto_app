import 'dart:math';
import 'package:flutter/material.dart';

/// Bouton d'enregistrement audio avec animations basées sur le niveau audio réel
/// 
/// Fonctionnalités:
/// - Animation de pulsation du micro pendant l'enregistrement
/// - Barres audio animées basées sur le niveau réel (0.0 → 1.0)
/// - Lissage du niveau pour un rendu fluide (attaque/relâchement)
/// - Transition fluide entre les états (inactif/enregistrement)
/// - Design moderne bleu/rouge avec textes personnalisables
class RecordingMicButton extends StatefulWidget {
  final bool isRecording;
  final double level; // ✅ 0.0 → 1.0 (volume micro)
  final VoidCallback onTap;

  final String idleTitle;
  final String idleSubtitle;
  final String recTitle;
  final String recSubtitle;

  const RecordingMicButton({
    super.key,
    required this.isRecording,
    required this.level,
    required this.onTap,
    this.idleTitle = "🎤 Dicter mon annonce (IA)",
    this.idleSubtitle = "Parlez, l'IA s'occupe du reste",
    this.recTitle = "🔴 Enregistrement…",
    this.recSubtitle = "Parlez maintenant",
  });

  @override
  State<RecordingMicButton> createState() => _RecordingMicButtonState();
}

class _RecordingMicButtonState extends State<RecordingMicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  double _smoothLevel = 0.0;

  // Facteurs fixes pour donner une forme "onde" agréable
  static const List<double> _shape = [
    0.45, 0.60, 0.80, 1.00, 0.90, 0.75, 0.95, 1.00, 0.70, 0.55,
  ];

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant RecordingMicButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    // ✅ Lissage (évite des barres trop "nervous")
    // attaque rapide, relâchement plus lent (effet vu-mètre)
    final input = widget.level.clamp(0.0, 1.0);
    const attack = 0.35;
    const release = 0.12;

    if (input > _smoothLevel) {
      _smoothLevel = _smoothLevel + (input - _smoothLevel) * attack;
    } else {
      _smoothLevel = _smoothLevel + (input - _smoothLevel) * release;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color bg = widget.isRecording
        ? const Color(0xFFE53935) // 🔴 rouge punchy
        : const Color(0xFF1A73E8); // 🔵 bleu

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 110,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.20),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            // 🎤 Micro (pulsé si recording)
            ScaleTransition(
              scale: widget.isRecording
                  ? Tween(begin: 1.0, end: 1.18).animate(
                      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                    )
                  : const AlwaysStoppedAnimation(1),
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mic_rounded, color: Colors.white, size: 32),
              ),
            ),

            const SizedBox(width: 16),

            // 📊 Barres (selon vrai volume)
            Expanded(
              child: widget.isRecording
                  ? AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, __) {
                        final t = _pulse.value; // 0..1
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(_shape.length, (i) {
                            // Petite modulation pour éviter un aspect "plat"
                            final wobble = 0.10 * sin((t * 2 * pi) + i);
                            final amp = (_smoothLevel + wobble).clamp(0.0, 1.0);

                            // Hauteurs
                            const minH = 10.0;
                            const maxH = 46.0;
                            final h = minH + (maxH - minH) * amp * _shape[i];

                            return Container(
                              width: 6,
                              height: h,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.95),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          }),
                        );
                      },
                    )
                  : const SizedBox.shrink(),
            ),

            const SizedBox(width: 12),

            // 📝 Texte d'état
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  widget.isRecording ? widget.recTitle : widget.idleTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.isRecording ? widget.recSubtitle : widget.idleSubtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.78),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

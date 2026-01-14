import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Bouton d'enregistrement audio avec indicateur de niveau réel (0.0 → 1.0).
///
/// - `level` : niveau audio normalisé fourni par l'appelant.
/// - Plus de barres aléatoires : l'animation reflète le volume du micro.
class RecordingMicButton extends StatefulWidget {
  final bool isRecording;
  final VoidCallback onTap;
  final bool isDisabled;

  /// Niveau audio normalisé entre 0.0 et 1.0.
  ///
  /// Si non renseigné, 0.0 est utilisé (aucune barre).
  final double level;

  const RecordingMicButton({
    super.key,
    required this.isRecording,
    required this.onTap,
    this.isDisabled = false,
    this.level = 0.0,
  });

  @override
  State<RecordingMicButton> createState() => _RecordingMicButtonState();
}

class _RecordingMicButtonState extends State<RecordingMicButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  // Niveau lissé pour éviter les à-coups visuels.
  double _smoothLevel = 0.0;

  static const int _barCount = 8;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addListener(() {
        _updateSmoothLevel();
      });

    if (widget.isRecording) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(RecordingMicButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Démarrer / arrêter la pulsation selon l'état d'enregistrement.
    if (widget.isRecording != oldWidget.isRecording) {
      if (widget.isRecording) {
        _pulse.repeat(reverse: true);
      } else {
        _pulse.stop();
        _smoothLevel = 0.0;
      }
    } else if (widget.level != oldWidget.level) {
      _updateSmoothLevel();
    }
  }

  void _updateSmoothLevel() {
    if (!mounted) return;

    // Si pas en enregistrement, on retombe progressivement à 0.
    final double target = widget.isRecording
      ? widget.level.clamp(0.0, 1.0)
      : 0.0;

    // Attack plus rapide que release pour coller à la voix.
    const double attack = 0.45;
    const double release = 0.15;

    final double current = _smoothLevel;
    final double alpha = target > current ? attack : release;
    final double next = current + (target - current) * alpha;

    setState(() {
      _smoothLevel = next.clamp(0.0, 1.0);
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.isDisabled;
    final backgroundColor = isDisabled
        ? Colors.grey.shade400
        : (widget.isRecording
            ? const Color(0xFFE53935) // Rouge vif pendant enregistrement
            : const Color(0xFF1A73E8)); // Bleu Presto

    final pulseT = widget.isRecording ? _pulse.value : 0.0;
    final haloBlur = 12 + (12 * pulseT); // halo pulsé
    final haloSpread = 3 + (4 * pulseT);

    return Semantics(
      button: true,
      enabled: !isDisabled,
      label: widget.isRecording
          ? "Arrêter l'enregistrement vocal"
          : "Démarrer la dictée vocale de votre annonce",
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled ? null : widget.onTap,
          borderRadius: BorderRadius.circular(30),
          splashColor: Colors.white.withOpacity(0.3),
          highlightColor: Colors.white.withOpacity(0.1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.all(4),
            decoration: widget.isRecording
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(34),
                    boxShadow: [
                      BoxShadow(
                        color: backgroundColor.withOpacity(0.28),
                        blurRadius: haloBlur,
                        spreadRadius: haloSpread,
                      ),
                    ],
                  )
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              height: 110,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: backgroundColor.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                    spreadRadius: widget.isRecording ? 2 : 0,
                  ),
                  const BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // 🎤 Icône micro avec animation de pulsation
                  ScaleTransition(
                    scale: widget.isRecording
                        ? Tween(begin: 1.0, end: 1.25).animate(
                            CurvedAnimation(
                              parent: _pulse,
                              curve: Curves.easeInOut,
                            ),
                          )
                        : const AlwaysStoppedAnimation(1.0),
                    child: Icon(
                      widget.isRecording ? Icons.mic : Icons.mic_rounded,
                      color: Colors.white,
                      size: 36,
                      semanticLabel: widget.isRecording
                          ? 'Enregistrement en cours'
                          : 'Micro',
                    ),
                  ),
                  const SizedBox(width: 16),

                  // 📊 Barres audio animées en fonction du niveau réel.
                  if (widget.isRecording)
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(_barCount, (index) {
                          final height = _barHeightForIndex(index, _smoothLevel, pulseT);
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            width: 6,
                            height: height,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                    )
                  else
                    const Spacer(),

                  // 📝 Texte d'état
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            widget.isRecording
                                ? "🔴 Enregistrement…"
                                : "🎤 Dicter mon annonce",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            widget.isRecording
                                ? "Parlez maintenant"
                                : "Parlez, l'IA écrit pour vous",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              height: 1.2,
                            ),
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _barHeightForIndex(int index, double level, double pulseT) {
    // Profil en cloche: barres centrales légèrement plus hautes.
    final center = (_barCount - 1) / 2.0;
    final dist = (index - center).abs() / center; // 0 au centre, 1 aux bords
    final shape = 1.0 - dist; // 1 au centre, 0 aux bords

    // Hauteur de base selon le niveau lissé.
    const double minH = 8.0;
    const double maxH = 40.0;

    final base = minH + (maxH - minH) * (level * (0.3 + 0.7 * shape));

    // Léger wobble synchronisé avec la pulsation pour un rendu vivant.
    final wobble = 1.0 + 0.12 * math.sin(2 * math.pi * (pulseT + index / _barCount));
    return base * wobble;
  }
}

import 'dart:math';
import 'package:flutter/material.dart';

/// Bouton d'enregistrement audio avec animations fluides et indicateurs visuels
/// 
/// Fonctionnalités:
/// - Animation de pulsation du micro pendant l'enregistrement
/// - Barres audio animées avec hauteurs aléatoires qui changent en temps réel
/// - Transition fluide entre les états (inactif/enregistrement)
/// - Retour haptique lors du clic
/// - Accessibilité améliorée
class RecordingMicButton extends StatefulWidget {
  final bool isRecording;
  final VoidCallback onTap;
  final bool isDisabled;

  const RecordingMicButton({
    super.key,
    required this.isRecording,
    required this.onTap,
    this.isDisabled = false,
  });

  @override
  State<RecordingMicButton> createState() => _RecordingMicButtonState();
}

class _RecordingMicButtonState extends State<RecordingMicButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final Random _random = Random();
  
  // Liste de hauteurs aléatoires qui se régénèrent à chaque frame
  final List<double> _barHeights = List.generate(8, (_) => 10.0);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addListener(() {
        // Mettre à jour les hauteurs des barres à chaque frame pour un effet fluide
        if (widget.isRecording && mounted) {
          setState(() {
            for (int i = 0; i < _barHeights.length; i++) {
              _barHeights[i] = 10 + _random.nextInt(30).toDouble();
            }
          });
        }
      });
    
    if (widget.isRecording) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(RecordingMicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording != oldWidget.isRecording) {
      if (widget.isRecording) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
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

    final pulseT = widget.isRecording ? _controller.value : 0.0;
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
                            parent: _controller,
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

                // 📊 Barres audio animées (uniquement pendant enregistrement)
                if (widget.isRecording)
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(_barHeights.length, (index) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          width: 6,
                          height: _barHeights[index],
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
}

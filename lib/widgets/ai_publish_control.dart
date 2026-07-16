import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'orbiting_ai_visual.dart';

enum AiPublishState {
  ready,
  recording,
  analyzing,
}

enum _AiMethod { vocal, texte }

// ─── AiPublishControl ─────────────────────────────────────────────────────────

class AiPublishControl extends StatefulWidget {
  const AiPublishControl({
    super.key,
    required this.state,
    required this.micAnchorLink,
    this.isAudioAnalyzing = false,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onSelectVocal,
    required this.onSelectText,
    required this.onDiagnostic,
    required this.onClear,
    this.showAdminDiagnostics = false,
    this.highlightVocalCard = false,
    this.dimVocalCard = false,
  });

  final AiPublishState state;
  final LayerLink micAnchorLink;
  final bool isAudioAnalyzing;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final VoidCallback onSelectVocal;
  final VoidCallback onSelectText;
  final VoidCallback onDiagnostic;
  final VoidCallback onClear;
  final bool showAdminDiagnostics;
  final bool highlightVocalCard;
  final bool dimVocalCard;

  @override
  State<AiPublishControl> createState() => _AiPublishControlState();
}

class _AiPublishControlState extends State<AiPublishControl> {
  _AiMethod _method = _AiMethod.vocal;

  bool get _isReady => widget.state == AiPublishState.ready;

  @override
  void didUpdateWidget(covariant AiPublishControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si un enregistrement démarre depuis le mode texte, on revient au mode vocal.
    if (oldWidget.state == AiPublishState.ready &&
        widget.state != AiPublishState.ready) {
      setState(() => _method = _AiMethod.vocal);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Choisissez votre méthode',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A2238),
          ),
        ),
        const SizedBox(height: 14),
        _MethodTabRow(
          isAudioAnalyzing: widget.isAudioAnalyzing,
          method: _method,
          enabled: _isReady,
          onSelectVocal: () {
            setState(() => _method = _AiMethod.vocal);
            widget.onSelectVocal();
          },
          onSelectTexte: () {
            setState(() => _method = _AiMethod.texte);
            widget.onSelectText();
          },
        ),
        const SizedBox(height: 16),
        _VocalModeCard(
          state: widget.state,
          visible: _method == _AiMethod.vocal,
          isHighlighted: widget.highlightVocalCard,
          isDimmed: widget.dimVocalCard,
          micAnchorLink: widget.micAnchorLink,
          onStartRecording: widget.onStartRecording,
          onStopRecording: widget.onStopRecording,
        ),
        if (widget.showAdminDiagnostics) ...[
          const SizedBox(height: 20),
          _MicroStateCard(state: widget.state),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _AiTextAction(
                icon: Icons.bug_report_outlined,
                label: 'Diagnostic IA',
                onTap: widget.onDiagnostic,
              ),
              const SizedBox(width: 28),
              _AiTextAction(
                icon: Icons.delete_outline,
                label: 'Effacer',
                onTap: widget.onClear,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ─── Tab switcher ─────────────────────────────────────────────────────────────

class _MethodTabRow extends StatelessWidget {
  const _MethodTabRow({
    required this.method,
    required this.enabled,
    required this.isAudioAnalyzing,
    required this.onSelectVocal,
    required this.onSelectTexte,
  });

  final _AiMethod method;
  final bool enabled;
  final bool isAudioAnalyzing;
  final VoidCallback onSelectVocal;
  final VoidCallback onSelectTexte;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MethodTabButton(
                icon: Icons.mic_rounded,
                label: 'IA vocale',
                showOrbit: isAudioAnalyzing,
                selected: method == _AiMethod.vocal,
                enabled: enabled,
                onTap: onSelectVocal,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MethodTabButton(
                icon: Icons.edit_rounded,
                label: 'Texte + IA',
                selectedColor: const Color(0xFFFF6600),
                selected: method == _AiMethod.texte,
                enabled: enabled,
                onTap: onSelectTexte,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                "Parlez, l'IA complète l'annonce pour vous.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: method == _AiMethod.vocal
                      ? const Color(0xFF1A6FFF)
                      : const Color(0xFF9CA3AF),
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Écrivez votre annonce puis améliorez-la avec l'IA.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: method == _AiMethod.texte
                      ? const Color(0xFF1A6FFF)
                      : const Color(0xFF9CA3AF),
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MethodTabButton extends StatelessWidget {
  const _MethodTabButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.selectedColor = const Color(0xFF1A6FFF),
    this.showOrbit = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final Color selectedColor;
  final bool showOrbit;

  bool get _isTextAiButton => label == 'Texte + IA';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
        decoration: BoxDecoration(
          color: _isTextAiButton
              ? const Color(0xFFFF6600)
              : (selected ? const Color(0xFF1A6FFF) : Colors.white),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: _isTextAiButton
                ? const Color(0xFFFF6600)
                : (selected
                    ? const Color(0xFF1A6FFF)
                    : const Color(0xFFD1D5DB)),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (_isTextAiButton
                      ? const Color(0xFFFF6600)
                      : (selected ? const Color(0xFF1A6FFF) : Colors.black))
                  .withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isTextAiButton
                    ? Colors.white
                    : (selected
                        ? Colors.white.withValues(alpha: 0.22)
                        : const Color(0xFFF3F4F6)),
              ),
              child: showOrbit
                  ? const SizedBox(
                      width: 38,
                      height: 38,
                      child: Center(
                        child: OrbitingAiVisual(size: 34),
                      ),
                    )
                  : Icon(
                      icon,
                      size: 16,
                      color: _isTextAiButton
                          ? const Color(0xFFFF6600)
                          : (selected ? Colors.white : const Color(0xFF6B7280)),
                    ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: _isTextAiButton
                      ? Colors.white
                      : (selected ? Colors.white : const Color(0xFF111827)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Carte mode vocal ─────────────────────────────────────────────────────────

class _VocalModeCard extends StatelessWidget {
  const _VocalModeCard({
    required this.state,
    required this.visible,
    required this.isHighlighted,
    required this.isDimmed,
    required this.micAnchorLink,
    required this.onStartRecording,
    required this.onStopRecording,
  });

  final AiPublishState state;
  final bool visible;
  final bool isHighlighted;
  final bool isDimmed;
  final LayerLink micAnchorLink;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;

  bool get _isRecording => state == AiPublishState.recording;
  bool get _isAnalyzing => state == AiPublishState.analyzing;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    final borderColor = isHighlighted
        ? Colors.white.withValues(alpha: 0.90)
        : const Color(0xFFC8D9FF);
    final borderRadius = BorderRadius.circular(20);

    return IgnorePointer(
      ignoring: isDimmed,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: isDimmed ? 0.44 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF4FF),
            borderRadius: borderRadius,
            border:
                Border.all(color: borderColor, width: isHighlighted ? 1.2 : 1),
          ),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          child: Stack(
            children: [
              if (isHighlighted)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: borderRadius,
                    child: IgnorePointer(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.24),
                                    const Color(0xFFB9D7FF)
                                        .withValues(alpha: 0.18),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.34, 1.0],
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.16),
                                    width: 1,
                                  ),
                                  gradient: RadialGradient(
                                    center: const Alignment(0, -0.9),
                                    radius: 1.15,
                                    colors: [
                                      Colors.white.withValues(alpha: 0.18),
                                      const Color(0xFF7DB7FF)
                                          .withValues(alpha: 0.12),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.42, 1.0],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Column(
                children: [
                  // En-tête : icône + titre + sous-titre
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFD6E6FF),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Color(0xFF1A6FFF),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Parlez, l'IA complète l'annonce",
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0A1F44),
                                height: 1.2,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Décrivez votre offre à l'oral. L'IA structure et rédige une annonce prête à publier.",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF6B7280),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // Bouton microphone central
                  CompositedTransformTarget(
                    link: micAnchorLink,
                    child: GestureDetector(
                      onTap: _isAnalyzing
                          ? null
                          : (_isRecording ? onStopRecording : onStartRecording),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isRecording
                              ? const Color(0xFFFF3B35)
                              : _isAnalyzing
                                  ? const Color(0xFF13C8FF)
                                  : const Color(0xFF1A6FFF),
                          boxShadow: [
                            BoxShadow(
                              color: (_isRecording
                                      ? const Color(0xFFFF3B35)
                                      : const Color(0xFF1A6FFF))
                                  .withValues(alpha: 0.38),
                              blurRadius: 18,
                              offset: const Offset(0, 7),
                            ),
                          ],
                        ),
                        child: Icon(
                          _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Texte d'état sous le bouton
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _isRecording
                          ? 'Appuyez pour arrêter'
                          : _isAnalyzing
                              ? 'Analyse en cours…'
                              : 'Appuyez pour parler',
                      key: ValueKey(state),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: _isRecording
                            ? const Color(0xFFFF3B35)
                            : const Color(0xFF1A6FFF),
                      ),
                    ),
                  ),

                  if (_isRecording) ...[
                    const SizedBox(height: 10),
                    const _AnimatedWaveform(
                      width: 100,
                      height: 22,
                      barColor: Color(0xBFFF3B35),
                      barWidth: 3,
                      barRadius: 8,
                      baseHeights: [6, 14, 9, 20, 12, 18, 8, 22, 14, 16, 9, 18],
                      duration: Duration(milliseconds: 900),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Mention sécurité
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.security_rounded,
                          size: 12, color: Color(0xFF9CA3AF)),
                      SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Vos données vocales sont sécurisées et non conservées.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9CA3AF),
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (isDimmed)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B7280).withValues(alpha: 0.42),
                      borderRadius: BorderRadius.circular(20),
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

// ─── AiWritingButton (bouton "Améliorer ma description avec l'IA") ────────────

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
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          height: 46,
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
          alignment: Alignment.center,
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
              Text(
                isAnalyzing
                    ? 'Amélioration en cours…'
                    : 'Appuyez pour améliorer votre description avec l\'IA',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Admin diagnostics ────────────────────────────────────────────────────────

class _AiTextAction extends StatelessWidget {
  const _AiTextAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 21, color: const Color(0xFF1672D8)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1672D8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MicroStateCard extends StatelessWidget {
  const _MicroStateCard({required this.state});

  final AiPublishState state;

  @override
  Widget build(BuildContext context) {
    final config = _MicroCardConfig.fromState(state);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: config.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.mic_rounded, size: 18, color: config.titleColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Micro classique web',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: config.titleColor,
                  ),
                ),
              ),
              _BadgeChip(
                label: config.badgeLabel,
                backgroundColor: config.badgeBackgroundColor,
                borderColor: config.badgeBorderColor,
                textColor: config.badgeTextColor,
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Transcription Whisper uniquement',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF222222),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _InfoChip(
                label: 'Mode serveur : Whisper',
                borderColor: config.chipBorderColor,
                textColor: const Color(0xFF333333),
              ),
              _InfoChip(
                label: config.stateLabel,
                borderColor: config.stateBorderColor,
                textColor: config.stateTextColor,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MicroCardConfig {
  const _MicroCardConfig({
    required this.backgroundColor,
    required this.borderColor,
    required this.titleColor,
    required this.badgeLabel,
    required this.badgeBackgroundColor,
    required this.badgeBorderColor,
    required this.badgeTextColor,
    required this.stateLabel,
    required this.stateTextColor,
    required this.stateBorderColor,
    required this.chipBorderColor,
  });

  final Color backgroundColor;
  final Color borderColor;
  final Color titleColor;
  final String badgeLabel;
  final Color badgeBackgroundColor;
  final Color badgeBorderColor;
  final Color badgeTextColor;
  final String stateLabel;
  final Color stateTextColor;
  final Color stateBorderColor;
  final Color chipBorderColor;

  factory _MicroCardConfig.fromState(AiPublishState state) {
    return switch (state) {
      AiPublishState.ready => const _MicroCardConfig(
          backgroundColor: Color(0xFFF8FAFC),
          borderColor: Color(0xFFD9E1EA),
          titleColor: Color(0xFF4E6475),
          badgeLabel: 'ADMIN',
          badgeBackgroundColor: Colors.white,
          badgeBorderColor: Color(0xFFD5DDE7),
          badgeTextColor: Color(0xFF4E6475),
          stateLabel: 'État : En attente',
          stateTextColor: Color(0xFF333333),
          stateBorderColor: Color(0xFFD9E1EA),
          chipBorderColor: Color(0xFFD9E1EA),
        ),
      AiPublishState.recording => const _MicroCardConfig(
          backgroundColor: Color(0xFFFFF7F2),
          borderColor: Color(0xFFFFD4C8),
          titleColor: Color(0xFFE92828),
          badgeLabel: 'LIVE',
          badgeBackgroundColor: Color(0xFFFF2D2D),
          badgeBorderColor: Color(0xFFFF2D2D),
          badgeTextColor: Colors.white,
          stateLabel: 'État : Écoute micro',
          stateTextColor: Color(0xFFE92828),
          stateBorderColor: Color(0xFFFFD4C8),
          chipBorderColor: Color(0xFFFFD4C8),
        ),
      AiPublishState.analyzing => const _MicroCardConfig(
          backgroundColor: Color(0xFFF1F8FF),
          borderColor: Color(0xFFC9E2FF),
          titleColor: Color(0xFF0078FF),
          badgeLabel: 'ANALYSE',
          badgeBackgroundColor: Color(0xFF006EEA),
          badgeBorderColor: Color(0xFF006EEA),
          badgeTextColor: Colors.white,
          stateLabel: 'État : Analyse en cours',
          stateTextColor: Color(0xFF0078FF),
          stateBorderColor: Color(0xFFC9E2FF),
          chipBorderColor: Color(0xFFC9E2FF),
        ),
    };
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({
    required this.label,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
  });

  final String label;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.borderColor,
    required this.textColor,
  });

  final String label;
  final Color borderColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}

// ─── Animations ───────────────────────────────────────────────────────────────

class _AnimatedWaveform extends StatefulWidget {
  const _AnimatedWaveform({
    required this.width,
    required this.height,
    required this.barColor,
    required this.barWidth,
    required this.barRadius,
    required this.baseHeights,
    required this.duration,
  });

  final double width;
  final double height;
  final Color barColor;
  final double barWidth;
  final double barRadius;
  final List<double> baseHeights;
  final Duration duration;

  @override
  State<_AnimatedWaveform> createState() => _AnimatedWaveformState();
}

class _AnimatedWaveformState extends State<_AnimatedWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final progress = Curves.easeInOut.transform(_controller.value);
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var index = 0; index < widget.baseHeights.length; index += 1)
                Container(
                  width: widget.barWidth,
                  height: _animatedBarHeight(
                    widget.baseHeights[index],
                    progress,
                    index,
                    widget.height,
                  ),
                  decoration: BoxDecoration(
                    color: widget.barColor,
                    borderRadius: BorderRadius.circular(widget.barRadius),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  double _animatedBarHeight(
    double baseHeight,
    double progress,
    int index,
    double maxHeight,
  ) {
    final shift = math.sin((progress * math.pi * 2) + (index * 0.55));
    final factor = 0.78 + ((shift + 1) * 0.18);
    return (baseHeight * factor).clamp(4, maxHeight);
  }
}

class _AnimatedProgressDots extends StatefulWidget {
  const _AnimatedProgressDots();

  @override
  State<_AnimatedProgressDots> createState() => _AnimatedProgressDotsState();
}

class _AnimatedProgressDotsState extends State<_AnimatedProgressDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 8,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final activeCount = 1 + (_controller.value * 5).floor().clamp(0, 4);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < 5; index += 1) ...[
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index < activeCount
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.45),
                  ),
                ),
                if (index != 4) const SizedBox(width: 6),
              ],
            ],
          );
        },
      ),
    );
  }
}

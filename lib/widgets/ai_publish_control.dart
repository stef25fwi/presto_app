import 'package:flutter/material.dart';

import 'ai_voice_example_card.dart';
import 'orbiting_ai_visual.dart';

export 'ai_writing_button.dart' show AiWritingButton;

enum AiPublishState { ready, recording, analyzing }

enum _AiMethod { vocal, texte }

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
          method: _method,
          enabled: _isReady,
          isAudioAnalyzing: widget.isAudioAnalyzing,
          onSelectVocal: () {
            setState(() => _method = _AiMethod.vocal);
            widget.onSelectVocal();
          },
          onSelectText: () {
            setState(() => _method = _AiMethod.texte);
            widget.onSelectText();
          },
        ),
        const SizedBox(height: 16),
        if (_method == _AiMethod.vocal)
          _VocalModeCard(
            state: widget.state,
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

class _MethodTabRow extends StatelessWidget {
  const _MethodTabRow({
    required this.method,
    required this.enabled,
    required this.isAudioAnalyzing,
    required this.onSelectVocal,
    required this.onSelectText,
  });

  final _AiMethod method;
  final bool enabled;
  final bool isAudioAnalyzing;
  final VoidCallback onSelectVocal;
  final VoidCallback onSelectText;

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
                selected: method == _AiMethod.vocal,
                enabled: enabled,
                showOrbit: isAudioAnalyzing,
                onTap: onSelectVocal,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MethodTabButton(
                icon: Icons.edit_rounded,
                label: 'Texte + IA',
                selected: method == _AiMethod.texte,
                enabled: enabled,
                selectedColor: const Color(0xFFFF6600),
                onTap: onSelectText,
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

  @override
  Widget build(BuildContext context) {
    final alwaysSelected = label == 'Texte + IA';
    final background = alwaysSelected
        ? const Color(0xFFFF6600)
        : (selected ? selectedColor : Colors.white);
    final foreground =
        alwaysSelected || selected ? Colors.white : const Color(0xFF111827);

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: enabled ? onTap : null,
          child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.72,
        duration: const Duration(milliseconds: 180),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: alwaysSelected
                  ? const Color(0xFFFF6600)
                  : (selected ? selectedColor : const Color(0xFFD1D5DB)),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: background.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: alwaysSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: selected ? 0.22 : 1),
                ),
                child: showOrbit
                    ? const Center(child: OrbitingAiVisual(size: 28))
                    : Icon(
                        icon,
                        size: 16,
                        color: alwaysSelected
                            ? const Color(0xFFFF6600)
                            : (selected
                                ? Colors.white
                                : const Color(0xFF6B7280)),
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
                    color: foreground,
                  ),
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

class _VocalModeCard extends StatelessWidget {
  const _VocalModeCard({
    required this.state,
    required this.isHighlighted,
    required this.isDimmed,
    required this.micAnchorLink,
    required this.onStartRecording,
    required this.onStopRecording,
  });

  final AiPublishState state;
  final bool isHighlighted;
  final bool isDimmed;
  final LayerLink micAnchorLink;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;

  bool get _isRecording => state == AiPublishState.recording;
  bool get _isAnalyzing => state == AiPublishState.analyzing;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: isDimmed,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: isDimmed ? 0.44 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF4FF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isHighlighted
                  ? Colors.white.withValues(alpha: 0.90)
                  : const Color(0xFFC8D9FF),
              width: isHighlighted ? 1.2 : 1,
            ),
          ),
          child: Column(
            children: [
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Color(0xFFD6E6FF),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFF1A6FFF),
                      size: 22,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Parlez, l'IA complète l'annonce",
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0A1F44),
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
              const SizedBox(height: 16),
              const AiVoiceExampleCard(),
              const SizedBox(height: 16),
              CompositedTransformTarget(
                link: micAnchorLink,
                child: Semantics(
                  button: true,
                  enabled: !_isAnalyzing,
                  label: _isRecording
                      ? 'Arrêter l\'enregistrement'
                      : (_isAnalyzing
                          ? 'Analyse de l\'enregistrement en cours'
                          : 'Démarrer l\'enregistrement vocal'),
                  child: Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
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
                ),
              ),
              const SizedBox(height: 10),
              Text(
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
              if (_isRecording) ...[
                const SizedBox(height: 10),
                const LinearProgressIndicator(
                  minHeight: 4,
                  backgroundColor: Color(0xFFFFD5D2),
                  color: Color(0xFFFF3B35),
                ),
              ],
              const SizedBox(height: 14),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.security_rounded,
                    size: 12,
                    color: Color(0xFF9CA3AF),
                  ),
                  SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      'Vos données vocales sont sécurisées et non conservées.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
    final stateLabel = switch (state) {
      AiPublishState.ready => 'État : En attente',
      AiPublishState.recording => 'État : Écoute micro',
      AiPublishState.analyzing => 'État : Analyse en cours',
    };

    final badgeLabel = switch (state) {
      AiPublishState.ready => 'ADMIN',
      AiPublishState.recording => 'LIVE',
      AiPublishState.analyzing => 'ANALYSE',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD9E1EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.mic_rounded,
                size: 18,
                color: Color(0xFF4E6475),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Micro classique web',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF4E6475),
                  ),
                ),
              ),
              Chip(label: Text(badgeLabel)),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Transcription Whisper uniquement',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              const Chip(label: Text('Mode serveur : Whisper')),
              Chip(label: Text(stateLabel)),
            ],
          ),
        ],
      ),
    );
  }
}

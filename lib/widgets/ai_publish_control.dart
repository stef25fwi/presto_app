import 'dart:math' as math;

import 'package:flutter/material.dart';

enum AiPublishState {
  ready,
  recording,
  analyzing,
}

class AiPublishControl extends StatelessWidget {
  const AiPublishControl({
    super.key,
    required this.state,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onDiagnostic,
    required this.onClear,
    this.showAdminDiagnostics = false,
  });

  final AiPublishState state;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final VoidCallback onDiagnostic;
  final VoidCallback onClear;
  final bool showAdminDiagnostics;

  bool get _isReady => state == AiPublishState.ready;
  bool get _isRecording => state == AiPublishState.recording;
  bool get _isAnalyzing => state == AiPublishState.analyzing;

  VoidCallback? get _primaryAction {
    if (_isRecording) return onStopRecording;
    if (_isAnalyzing) return null;
    return onStartRecording;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PrimaryAiButton(
          state: state,
          onTap: _primaryAction,
        ),
        const SizedBox(height: 18),
        _StatusPill(state: state),
        if (showAdminDiagnostics) ...[
          const SizedBox(height: 20),
          _MicroStateCard(state: state),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _AiTextAction(
                icon: Icons.bug_report_outlined,
                label: 'Diagnostic IA',
                onTap: onDiagnostic,
              ),
              const SizedBox(width: 28),
              _AiTextAction(
                icon: Icons.delete_outline,
                label: 'Effacer',
                onTap: onClear,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _PrimaryAiButton extends StatelessWidget {
  const _PrimaryAiButton({
    required this.state,
    required this.onTap,
  });

  final AiPublishState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final config = _PrimaryAiButtonConfig.fromState(state);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: config.gradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: config.shadowColor,
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: SizedBox(
            width: double.infinity,
            height: 88,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: switch (state) {
                AiPublishState.ready => const _ReadyButtonContent(),
                AiPublishState.recording => const _RecordingButtonContent(),
                AiPublishState.analyzing => const _AnalyzingButtonContent(),
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryAiButtonConfig {
  const _PrimaryAiButtonConfig({
    required this.gradient,
    required this.shadowColor,
  });

  final LinearGradient gradient;
  final Color shadowColor;

  factory _PrimaryAiButtonConfig.fromState(AiPublishState state) {
    return switch (state) {
      AiPublishState.ready => const _PrimaryAiButtonConfig(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A7CFF),
              Color(0xFF0058E8),
              Color(0xFF1434D9),
            ],
          ),
          shadowColor: Color(0x66005BEA),
        ),
      AiPublishState.recording => const _PrimaryAiButtonConfig(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFF5F57),
              Color(0xFFFF3B35),
              Color(0xFFE91F2A),
            ],
          ),
          shadowColor: Color(0x66FF2D2D),
        ),
      AiPublishState.analyzing => const _PrimaryAiButtonConfig(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF13C8FF),
              Color(0xFF0078FF),
              Color(0xFF004BE8),
            ],
          ),
          shadowColor: Color(0x6613A8FF),
        ),
    };
  }
}

class _ReadyButtonContent extends StatelessWidget {
  const _ReadyButtonContent();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        _AiCircleIcon(
          icon: Icons.auto_awesome,
          gradient: RadialGradient(
            colors: [
              Color(0xFF2EA7FF),
              Color(0xFF005BEA),
            ],
          ),
        ),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Décrire mon besoin (IA)',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.05,
                ),
              ),
              SizedBox(height: 4),
              Text(
                "Parlez, l'assistant IA analyse et complète votre annonce !",
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xE0FFFFFF),
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecordingButtonContent extends StatelessWidget {
  const _RecordingButtonContent();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        _RecordingStopCircle(),
        SizedBox(width: 14),
        Expanded(
          child: Text(
            'Arrêter',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.05,
            ),
          ),
        ),
        SizedBox(width: 12),
        _AnimatedWaveform(
          width: 82,
          height: 32,
          barColor: Color(0x59FFFFFF),
          barWidth: 3,
          barRadius: 8,
          baseHeights: [8, 18, 12, 26, 14, 22, 10, 28, 16, 20, 11, 24],
          duration: Duration(milliseconds: 900),
        ),
      ],
    );
  }
}

class _AnalyzingButtonContent extends StatelessWidget {
  const _AnalyzingButtonContent();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        _AiCircleIcon(
          icon: Icons.auto_awesome,
          gradient: RadialGradient(
            colors: [
              Color(0xFF42D8FF),
              Color(0xFF0078FF),
            ],
          ),
        ),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Analyse IA en cours',
                style: TextStyle(
                  fontSize: 18.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.05,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Nous analysons votre demande…',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xE0FFFFFF),
                  height: 1.2,
                ),
              ),
              SizedBox(height: 8),
              _AnimatedProgressDots(),
            ],
          ),
        ),
        SizedBox(width: 12),
        _OrbitingAiVisual(),
      ],
    );
  }
}

class _AiCircleIcon extends StatelessWidget {
  const _AiCircleIcon({
    required this.icon,
    required this.gradient,
  });

  final IconData icon;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: gradient,
        border: Border.all(
          color: Colors.white.withOpacity(0.18),
          width: 1.5,
        ),
      ),
      child: Icon(icon, size: 30, color: Colors.white),
    );
  }
}

class _RecordingStopCircle extends StatefulWidget {
  const _RecordingStopCircle();

  @override
  State<_RecordingStopCircle> createState() => _RecordingStopCircleState();
}

class _RecordingStopCircleState extends State<_RecordingStopCircle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 1 + (_controller.value * 0.05);
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.20),
        ),
        child: const Icon(
          Icons.stop_rounded,
          size: 26,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.state});

  final AiPublishState state;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      AiPublishState.ready => Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF7FBFF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFD5E7FA)),
          ),
          child: Row(
            children: const [
              Icon(
                Icons.lightbulb_outline,
                size: 18,
                color: Color(0xFF6B7F93),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Plus c'est précis, meilleurs sont les résultats.",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF52677D),
                  ),
                ),
              ),
            ],
          ),
        ),
      AiPublishState.recording => Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3F2),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFFFC6C2)),
          ),
          child: Row(
            children: const [
              Icon(
                Icons.mic,
                size: 18,
                color: Color(0xFFE92828),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Enregistrement en cours',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFE92828),
                  ),
                ),
              ),
              _AnimatedWaveform(
                width: 45,
                height: 18,
                barColor: Color(0xBFE92828),
                barWidth: 2,
                barRadius: 6,
                baseHeights: [5, 9, 7, 14, 8, 12, 6, 13],
                duration: Duration(milliseconds: 900),
              ),
            ],
          ),
        ),
      AiPublishState.analyzing => Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F8FF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFC9E2FF)),
          ),
          child: Row(
            children: const [
              Icon(
                Icons.auto_awesome,
                size: 17,
                color: Color(0xFF0078FF),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'IA en action : compréhension & suggestions',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1672D8),
                  ),
                ),
              ),
            ],
          ),
        ),
    };
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
                        : Colors.white.withOpacity(0.45),
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

class _OrbitingAiVisual extends StatefulWidget {
  const _OrbitingAiVisual();

  @override
  State<_OrbitingAiVisual> createState() => _OrbitingAiVisualState();
}

class _OrbitingAiVisualState extends State<_OrbitingAiVisual>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
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
      width: 54,
      height: 54,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Transform.rotate(
            angle: _controller.value * math.pi * 2,
            child: CustomPaint(
              painter: _OrbitPainter(),
            ),
          );
        },
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2 - 3;
    final innerRadius = size.width / 2 - 11;

    final strokePaint = Paint()
      ..color = Colors.white.withOpacity(0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawCircle(center, outerRadius, strokePaint);
    canvas.drawCircle(center, innerRadius, strokePaint);

    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final positions = [
      Offset(center.dx + outerRadius, center.dy),
      Offset(
        center.dx + (innerRadius * math.cos(math.pi * 0.75)),
        center.dy + (innerRadius * math.sin(math.pi * 0.75)),
      ),
      Offset(
        center.dx + (outerRadius * math.cos(math.pi * 1.4)),
        center.dy + (outerRadius * math.sin(math.pi * 1.4)),
      ),
    ];

    for (final position in positions) {
      canvas.drawCircle(position, 2.6, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

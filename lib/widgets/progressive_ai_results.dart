import 'package:flutter/material.dart';

enum ProgressiveAiStage {
  idle,
  recording,
  uploading,
  transcribing,
  extracting,
  complete,
  error,
}

class ProgressiveAiResult {
  final ProgressiveAiStage stage;
  final String? transcription;
  final String? partialTitle;
  final String? partialDescription;
  final String? category;
  final double? budget;
  final List<String>? skills;
  final String? errorMessage;
  final double? progress; // 0.0 to 1.0

  const ProgressiveAiResult({
    required this.stage,
    this.transcription,
    this.partialTitle,
    this.partialDescription,
    this.category,
    this.budget,
    this.skills,
    this.errorMessage,
    this.progress,
  });

  ProgressiveAiResult copyWith({
    ProgressiveAiStage? stage,
    String? transcription,
    String? partialTitle,
    String? partialDescription,
    String? category,
    double? budget,
    List<String>? skills,
    String? errorMessage,
    double? progress,
  }) {
    return ProgressiveAiResult(
      stage: stage ?? this.stage,
      transcription: transcription ?? this.transcription,
      partialTitle: partialTitle ?? this.partialTitle,
      partialDescription: partialDescription ?? this.partialDescription,
      category: category ?? this.category,
      budget: budget ?? this.budget,
      skills: skills ?? this.skills,
      errorMessage: errorMessage ?? this.errorMessage,
      progress: progress ?? this.progress,
    );
  }
}

class ProgressiveAiResultsWidget extends StatelessWidget {
  final ProgressiveAiResult result;
  final bool isCompact;

  const ProgressiveAiResultsWidget({
    super.key,
    required this.result,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (result.stage == ProgressiveAiStage.idle) {
      return const SizedBox.shrink();
    }

    if (result.stage == ProgressiveAiStage.error) {
      return _buildErrorState(context);
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProgressIndicator(context),
          const SizedBox(height: 16),
          if (result.stage.index >= ProgressiveAiStage.recording.index)
            _buildRecordingIndicator(),
          if (result.stage.index >= ProgressiveAiStage.uploading.index)
            _buildUploadingIndicator(),
          if (result.stage.index >= ProgressiveAiStage.transcribing.index)
            _buildTranscriptionSection(context),
          if (result.stage.index >= ProgressiveAiStage.extracting.index)
            _buildExtractionSection(context),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(BuildContext context) {
    final progress = result.progress ?? 0.0;
    String stageLabel = _getStageLabel();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              stageLabel,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A73E8),
                  ),
            ),
            if (progress > 0)
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: const Color(0xFF1A73E8).withValues(alpha: 0.1),
            valueColor: const AlwaysStoppedAnimation<Color>(
              Color(0xFF1A73E8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFFE53935),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const _PulsingDot(),
          ),
          const SizedBox(width: 8),
          const Text(
            'Enregistrement en cours…',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFFE53935),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const SizedBox(
            width: 8,
            height: 8,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                Color(0xFF1A73E8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Envoi en cours…',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF1A73E8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptionSection(BuildContext context) {
    if (result.transcription == null || result.transcription!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F7FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF1A73E8).withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  size: 16,
                  color: Color(0xFF1A73E8),
                ),
                const SizedBox(width: 8),
                Text(
                  'Transcription',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF1A73E8),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              result.transcription!,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExtractionSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (result.partialTitle != null && result.partialTitle!.isNotEmpty)
            _buildExtractedField(
              context,
              'Titre proposé',
              result.partialTitle!,
            ),
          if (result.category != null && result.category!.isNotEmpty)
            _buildExtractedField(
              context,
              'Catégorie',
              result.category!,
            ),
          if (result.budget != null && result.budget! > 0)
            _buildExtractedField(
              context,
              'Budget estimé',
              '${result.budget!.toStringAsFixed(0)}€',
            ),
          if (result.skills != null && result.skills!.isNotEmpty)
            _buildExtractedList(
              context,
              'Compétences',
              result.skills!,
            ),
        ],
      ),
    );
  }

  Widget _buildExtractedField(
      BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey[300]!,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExtractedList(
    BuildContext context,
    String label,
    List<String> values,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey[300]!,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: values
                  .take(4)
                  .map(
                    (skill) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A73E8).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        skill,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: const Color(0xFF1A73E8),
                            ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE53935).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.error_outline,
                size: 18,
                color: Color(0xFFE53935),
              ),
              const SizedBox(width: 8),
              Text(
                'Erreur',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xFFE53935),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            result.errorMessage ?? 'Une erreur est survenue',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFE53935),
                ),
          ),
        ],
      ),
    );
  }

  String _getStageLabel() {
    switch (result.stage) {
      case ProgressiveAiStage.recording:
        return 'Enregistrement…';
      case ProgressiveAiStage.uploading:
        return 'Envoi de l\'audio…';
      case ProgressiveAiStage.transcribing:
        return 'Transcription en cours…';
      case ProgressiveAiStage.extracting:
        return 'Analyse en cours…';
      case ProgressiveAiStage.complete:
        return 'Analyse terminée ✓';
      case ProgressiveAiStage.error:
        return 'Erreur';
      case ProgressiveAiStage.idle:
        return '';
    }
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: const Color(0xFFE53935),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

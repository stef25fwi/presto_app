import 'package:flutter/material.dart';

import '../app/presto_overlay_theme.dart';
import '../app_core.dart';
import '../constants.dart';

enum PublishAiTraceLevel { info, success, warning, error }

class PublishAiTraceEntry {
  const PublishAiTraceEntry({
    required this.timestamp,
    required this.level,
    required this.stage,
    required this.detail,
  });

  final DateTime timestamp;
  final PublishAiTraceLevel level;
  final String stage;
  final String detail;
}

String formatPublishAiTraceTime(DateTime value) {
  String two(int v) => v.toString().padLeft(2, '0');
  String three(int v) => v.toString().padLeft(3, '0');
  return '${two(value.hour)}:${two(value.minute)}:${two(value.second)}.${three(value.millisecond)}';
}

IconData iconForPublishAiTraceLevel(PublishAiTraceLevel level) {
  switch (level) {
    case PublishAiTraceLevel.success:
      return Icons.check_circle_rounded;
    case PublishAiTraceLevel.warning:
      return Icons.warning_amber_rounded;
    case PublishAiTraceLevel.error:
      return Icons.error_rounded;
    case PublishAiTraceLevel.info:
      return Icons.radio_button_checked_rounded;
  }
}

Color colorForPublishAiTraceLevel(PublishAiTraceLevel level) {
  switch (level) {
    case PublishAiTraceLevel.success:
      return const Color(0xFF2E7D32);
    case PublishAiTraceLevel.warning:
      return const Color(0xFFF9A825);
    case PublishAiTraceLevel.error:
      return const Color(0xFFC62828);
    case PublishAiTraceLevel.info:
      return kPrestoBlue;
  }
}

class PublishValidationBanner extends StatelessWidget {
  const PublishValidationBanner({super.key, required this.missingFields});

  final List<String> missingFields;

  @override
  Widget build(BuildContext context) {
    if (missingFields.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFC78F)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFB45309),
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Complète les champs mis en évidence : ${missingFields.join(', ')}.',
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PublishAiTraceDiagnosticDialog extends StatelessWidget {
  const PublishAiTraceDiagnosticDialog({
    super.key,
    required this.entries,
    required this.runtimeState,
    required this.latestTranscript,
    required this.onClear,
  });

  final List<PublishAiTraceEntry> entries;
  final String runtimeState;
  final String latestTranscript;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final overlayTheme = context.prestoOverlayTheme;

    return Dialog(
      backgroundColor: overlayTheme.surfaceColor,
      surfaceTintColor: overlayTheme.surfaceTintColor,
      insetPadding: const EdgeInsets.all(16),
      shape: overlayTheme.dialogShape,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Diagnostic micro IA',
                      style: kPrestoSectionTitleStyle,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fermer',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: kPrestoBlue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: kPrestoBlue.withOpacity(0.18),
                      ),
                    ),
                    child: Text(
                      'Etat: $runtimeState',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: kPrestoBlue,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Entrees: ${entries.length}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              if (latestTranscript.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.035),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Text(
                    'Dernière transcription: ${latestTranscript.trim()}',
                    style: const TextStyle(fontSize: 12, height: 1.35),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: entries.isEmpty ? null : onClear,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Effacer'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: entries.isEmpty
                    ? const Center(
                        child: Text(
                          'Aucun diagnostic pour le moment.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      )
                    : ListView.separated(
                        itemCount: entries.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          final color =
                              colorForPublishAiTraceLevel(entry.level);
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: color.withOpacity(0.18),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Icon(
                                    iconForPublishAiTraceLevel(entry.level),
                                    color: color,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${formatPublishAiTraceTime(entry.timestamp)}  ${entry.stage}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: color,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        entry.detail,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

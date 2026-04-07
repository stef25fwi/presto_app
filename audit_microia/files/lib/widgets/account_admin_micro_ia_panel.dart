import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AccountAdminMicroIaPanel extends StatelessWidget {
  static const Color _kPrestoOrange = Color(0xFFFF6600);
  static const Color _kPrestoBlue = Color(0xFF1A73E8);

  final List<String> techLines;
  final Widget buildVersionPanel;
  final Widget analyticsPanel;
  final String mode;
  final bool fallbackEnabled;
  final double qualityThreshold;
  final TextEditingController languageController;
  final bool canEdit;
  final bool isSaving;
  final ValueChanged<String?> onModeChanged;
  final ValueChanged<bool> onFallbackChanged;
  final ValueChanged<double> onThresholdChanged;
  final ValueChanged<String> onLanguageChanged;
  final VoidCallback onApplyPressed;
  final VoidCallback onEditPressed;

  const AccountAdminMicroIaPanel({
    super.key,
    required this.techLines,
    required this.buildVersionPanel,
    required this.analyticsPanel,
    required this.mode,
    required this.fallbackEnabled,
    required this.qualityThreshold,
    required this.languageController,
    required this.canEdit,
    required this.isSaving,
    required this.onModeChanged,
    required this.onFallbackChanged,
    required this.onThresholdChanged,
    required this.onLanguageChanged,
    required this.onApplyPressed,
    required this.onEditPressed,
  });

  @override
  Widget build(BuildContext context) {
    final disabledHintStyle = TextStyle(
      color: _kPrestoBlue.withOpacity(0.65),
      fontWeight: FontWeight.w700,
      fontSize: 12,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        const Text(
          'PANNEAU ADMIN',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: _kPrestoBlue,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Réglages et outils de gestion (fonctions à venir).',
          style: TextStyle(
            fontSize: 12,
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _kPrestoBlue.withOpacity(0.18)),
            boxShadow: [
              BoxShadow(
                color: _kPrestoBlue.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Espace admin',
                style: TextStyle(
                  fontSize: 12,
                  color: _kPrestoBlue,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _kPrestoBlue.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kPrestoBlue.withOpacity(0.18)),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Profil admin (technique)',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        color: _kPrestoBlue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      techLines.join('\n'),
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.25,
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              buildVersionPanel,
              const SizedBox(height: 12),
              const Text(
                'Micro-IA (transcription audio)',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: _kPrestoOrange,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🎙️ Pipelines Audio Actifs',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Colors.amber,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _AudioPipelineRow(
                      icon: '📱',
                      label: 'Mobile Streaming',
                      description: 'PCM16 16kHz real-time',
                      isActive: !kIsWeb,
                      status: !kIsWeb ? 'READY' : 'N/A',
                    ),
                    const SizedBox(height: 8),
                    _AudioPipelineRow(
                      icon: '🌐',
                      label: 'Web Chunking',
                      description: '2-sec chunks, stopToBlob()',
                      isActive: kIsWeb,
                      status: kIsWeb ? 'ACTIVE' : 'STANDBY',
                    ),
                    const SizedBox(height: 8),
                    const _AudioPipelineRow(
                      icon: '⏺️',
                      label: 'Standard Recording',
                      description: 'Fallback WAV 16k mono',
                      isActive: true,
                      status: 'AVAILABLE',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              analyticsPanel,
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: mode,
                items: const [
                  DropdownMenuItem(
                    value: 'HYBRID',
                    child: Text('Hybrid (recommandé)'),
                  ),
                  DropdownMenuItem(
                    value: 'GOOGLE_ONLY',
                    child: Text('Google STT uniquement'),
                  ),
                  DropdownMenuItem(
                    value: 'WHISPER_ONLY',
                    child: Text('Whisper uniquement'),
                  ),
                ],
                onChanged: canEdit ? onModeChanged : null,
                decoration: InputDecoration(
                  labelText: 'Mode',
                  helperText:
                      canEdit ? null : 'Lecture seule (appuie sur “Modifier”)',
                  helperStyle: disabledHintStyle,
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Fallback activé'),
                subtitle: const Text(
                  'Si la qualité est faible, tente un autre provider.',
                  style: TextStyle(fontSize: 12),
                ),
                value: fallbackEnabled,
                onChanged: canEdit ? onFallbackChanged : null,
              ),
              const SizedBox(height: 6),
              Text(
                'Seuil qualité: ${qualityThreshold.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Slider(
                value: qualityThreshold,
                min: 0.40,
                max: 0.95,
                divisions: 55,
                onChanged: canEdit ? onThresholdChanged : null,
              ),
              TextField(
                controller: languageController,
                decoration: const InputDecoration(
                  labelText: 'Language code',
                  hintText: 'fr-FR',
                ),
                enabled: canEdit,
                onChanged: onLanguageChanged,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: canEdit
                    ? ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kPrestoBlue,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: isSaving ? null : onApplyPressed,
                        icon: isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.check_circle_outline),
                        label: Text(
                          isSaving ? 'Application…' : 'Appliquer',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      )
                    : OutlinedButton.icon(
                        onPressed: isSaving ? null : onEditPressed,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text(
                          'Modifier',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Ces réglages modifient Firebase Remote Config (impact côté Functions).',
                style: TextStyle(fontSize: 11, color: Colors.black45),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AudioPipelineRow extends StatelessWidget {
  final String icon;
  final String label;
  final String description;
  final bool isActive;
  final String status;

  const _AudioPipelineRow({
    required this.icon,
    required this.label,
    required this.description,
    required this.isActive,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = isActive
        ? (status == 'ACTIVE' ? Colors.green : Colors.blue)
        : Colors.grey;
    final bgColor =
        isActive ? statusColor.withOpacity(0.1) : Colors.grey.withOpacity(0.05);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

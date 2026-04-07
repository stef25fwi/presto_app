import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/admin_audio_runtime_store.dart';

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
    final normalizedMode = mode.toUpperCase();
    final disabledHintStyle = TextStyle(
      color: _kPrestoBlue.withOpacity(0.65),
      fontWeight: FontWeight.w700,
      fontSize: 12,
    );
    const modeOptions = <_AudioModeOption>[
      _AudioModeOption(
        value: 'HYBRID',
        label: 'Hybride',
        description: 'Google STT puis nettoyage IA. Couvre le plus de cas.',
        routing: 'Tentatives: HYBRID -> WHISPER_ONLY -> GOOGLE_ONLY',
      ),
      _AudioModeOption(
        value: 'GOOGLE_ONLY',
        label: 'Google STT',
        description: 'Transcription la plus directe, utile pour la latence.',
        routing: 'Tentatives: GOOGLE_ONLY uniquement',
      ),
      _AudioModeOption(
        value: 'WHISPER_ONLY',
        label: 'Whisper',
        description: 'Transcription OpenAI sans nettoyage hybride Google.',
        routing: 'Tentatives: WHISPER_ONLY uniquement',
      ),
    ];

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
              AnimatedBuilder(
                animation: AdminAudioRuntimeStore.instance,
                builder: (context, _) {
                  final runtimeStore = AdminAudioRuntimeStore.instance;
                  final latestEntry = runtimeStore.latestEntry;
                  final history = runtimeStore.history;

                  return Container(
                    decoration: BoxDecoration(
                      color: _kPrestoBlue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kPrestoBlue.withOpacity(0.18)),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Indicateur runtime admin',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: _kPrestoBlue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          runtimeStore.currentLabel,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          runtimeStore.currentDetail,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (latestEntry != null)
                              _RuntimeChip(
                                label:
                                    'Tentative #${latestEntry.attemptNumber}',
                                color: Colors.teal,
                              ),
                            if (latestEntry != null)
                              _RuntimeChip(
                                label:
                                    'Flux: ${_flowDisplayLabel(latestEntry.flowKey)}',
                                color: _flowColor(latestEntry.flowKey),
                              ),
                            if (latestEntry != null)
                              _RuntimeChip(
                                label:
                                    'Statut: ${_statusDisplayLabel(latestEntry.status)}',
                                color: _statusColor(latestEntry.status),
                              ),
                            _RuntimeChip(
                              label:
                                  'Mode configuré: ${_modeDisplayLabel(runtimeStore.configuredMode)}',
                              color: _kPrestoBlue,
                            ),
                            _RuntimeChip(
                              label:
                                  'Source: ${_sourceDisplayLabel(runtimeStore.dataSource)}',
                              color: _sourceColor(runtimeStore.dataSource),
                            ),
                            _RuntimeChip(
                              label: runtimeStore.cloudSyncEnabled
                                  ? 'Sync cloud active'
                                  : 'Sync cloud inactive',
                              color: runtimeStore.cloudSyncEnabled
                                  ? const Color(0xFF2E7D32)
                                  : Colors.grey,
                            ),
                            if ((runtimeStore.backendModeUsed ?? '').isNotEmpty)
                              _RuntimeChip(
                                label:
                                    'Dernier backend: ${_modeDisplayLabel(runtimeStore.backendModeUsed!)}',
                                color: _kPrestoOrange,
                              ),
                            if (latestEntry?.transcriptLength != null)
                              _RuntimeChip(
                                label:
                                    'Transcript: ${latestEntry!.transcriptLength} car.',
                                color: Colors.purple,
                              ),
                            if (runtimeStore.lastUpdatedAt != null)
                              _RuntimeChip(
                                label:
                                    'Mis à jour ${_formatRuntimeTime(runtimeStore.lastUpdatedAt!)}',
                                color: Colors.teal,
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Historique récent',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: history.isEmpty
                                ? null
                                : () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (dialogContext) {
                                        return AlertDialog(
                                          title: const Text('Effacer l\'historique ?'),
                                          content: const Text(
                                            'Cette action vide l\'historique runtime audio admin sur cet appareil et dans le document partagé.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(dialogContext).pop(false),
                                              child: const Text('Annuler'),
                                            ),
                                            FilledButton(
                                              onPressed: () => Navigator.of(dialogContext).pop(true),
                                              child: const Text('Effacer'),
                                            ),
                                          ],
                                        );
                                      },
                                    );

                                    if (confirmed == true) {
                                      runtimeStore.clearHistory();
                                    }
                                  },
                            icon: const Icon(Icons.delete_outline_rounded, size: 16),
                            label: const Text('Vider l\'historique'),
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (history.isEmpty)
                          const Text(
                            'Aucune activité audio enregistrée pour le moment.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        else
                          ...history.map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _RuntimeHistoryRow(entry: entry),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
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
                      'Pipelines audio existants',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Colors.amber,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Inventaire des flux présents dans l\'app, avec ce qui est basculable ici et ce qui reste fixe dans le code.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _AudioPipelineRow(
                      icon: '📱',
                      label: 'Streaming mobile',
                      description:
                          'PCM16 16k mono en flux continu, transcription chunk par chunk.',
                      isActive: !kIsWeb,
                      status: !kIsWeb ? 'DISPO ICI' : 'MOBILE',
                      accentColor: const Color(0xFF1A73E8),
                    ),
                    const SizedBox(height: 8),
                    _AudioPipelineRow(
                      icon: '🌐',
                      label: 'Streaming web chunké',
                      description:
                          'Blob toutes ~2s puis reprise du micro pour un quasi temps réel.',
                      isActive: kIsWeb,
                      status: kIsWeb ? 'DISPO ICI' : 'WEB',
                      accentColor: const Color(0xFF00897B),
                    ),
                    const SizedBox(height: 8),
                    _AudioPipelineRow(
                      icon: '⏺️',
                      label: 'Micro classique',
                      description:
                          'Enregistrement complet puis transcription serveur selon le mode choisi ci-dessous.',
                      isActive: true,
                      status: 'BASCULABLE',
                      accentColor: _kPrestoOrange,
                    ),
                    const SizedBox(height: 8),
                    const _AudioPipelineRow(
                      icon: '☁️',
                      label: 'Chunks streaming -> Google STT',
                      description:
                          'Le streaming temps reel force GOOGLE_ONLY cote Functions pour chaque chunk.',
                      isActive: true,
                      status: 'FIXE',
                      accentColor: Color(0xFF3949AB),
                    ),
                    const SizedBox(height: 8),
                    const _AudioPipelineRow(
                      icon: '✨',
                      label: 'Premium Audio',
                      description:
                          'Flux separe sur la page premium: Chirp 3 EU + redaction Gemini.',
                      isActive: true,
                      status: 'SEPARE',
                      accentColor: Color(0xFF8E24AA),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              analyticsPanel,
              const SizedBox(height: 12),
              const Text(
                'Bascule du pipeline serveur',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: _kPrestoBlue,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                canEdit
                    ? 'Une seule option peut etre active. Cette bascule pilote le micro classique cote serveur.'
                    : 'Lecture seule. Appuie sur Modifier pour changer le pipeline serveur.',
                style: disabledHintStyle,
              ),
              const SizedBox(height: 10),
              ...modeOptions.expand(
                (option) => [
                  _AudioModeToggleCard(
                    label: option.label,
                    description: option.description,
                    routing: option.routing,
                    selected: normalizedMode == option.value,
                    enabled: canEdit,
                    onTap: () => onModeChanged(option.value),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueGrey.withOpacity(0.18)),
                ),
                padding: const EdgeInsets.all(12),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: Color(0xFF455A64),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Important: le mode choisi ici agit sur le micro classique et les traitements serveur non streaming. Le streaming temps reel reste route en GOOGLE_ONLY pour les chunks audio.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
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

String _modeDisplayLabel(String mode) {
  switch (mode.toUpperCase()) {
    case 'GOOGLE_ONLY':
      return 'Google STT';
    case 'WHISPER_ONLY':
      return 'Whisper';
    case 'HYBRID':
    default:
      return 'Hybride';
  }
}

String _formatRuntimeTime(DateTime value) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
}

String _flowDisplayLabel(String flowKey) {
  switch (flowKey) {
    case 'streaming_web':
      return 'Streaming web';
    case 'streaming_mobile':
      return 'Streaming mobile';
    case 'classic_web':
      return 'Micro classique web';
    case 'classic_mobile':
      return 'Micro classique mobile';
    default:
      return flowKey;
  }
}

String _statusDisplayLabel(String status) {
  switch (status) {
    case 'forced':
      return 'Forcé';
    case 'confirmed':
      return 'Confirmé';
    case 'pending':
    default:
      return 'En attente';
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'forced':
      return const Color(0xFF3949AB);
    case 'confirmed':
      return const Color(0xFF2E7D32);
    case 'pending':
    default:
      return const Color(0xFFF9A825);
  }
}

class _AudioPipelineRow extends StatelessWidget {
  final String icon;
  final String label;
  final String description;
  final bool isActive;
  final String status;
  final Color accentColor;

  const _AudioPipelineRow({
    required this.icon,
    required this.label,
    required this.description,
    required this.isActive,
    required this.status,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = isActive ? accentColor : Colors.grey;
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

class _RuntimeChip extends StatelessWidget {
  final String label;
  final Color color;

  const _RuntimeChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _RuntimeHistoryRow extends StatelessWidget {
  final AdminAudioRuntimeEntry entry;

  const _RuntimeHistoryRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final flowColor = _flowColor(entry.flowKey);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: flowColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: flowColor.withOpacity(0.18)),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
              ),
              Text(
                '#${entry.attemptNumber} · ${_formatRuntimeTime(entry.timestamp)}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.black45,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            entry.detail,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _RuntimeChip(
                label: 'Flux: ${_flowDisplayLabel(entry.flowKey)}',
                color: flowColor,
              ),
              _RuntimeChip(
                label: 'Statut: ${_statusDisplayLabel(entry.status)}',
                color: _statusColor(entry.status),
              ),
              _RuntimeChip(
                label: 'Config: ${_modeDisplayLabel(entry.configuredMode)}',
                color: AccountAdminMicroIaPanel._kPrestoBlue,
              ),
              if ((entry.backendModeUsed ?? '').isNotEmpty)
                _RuntimeChip(
                  label:
                      'Backend: ${_modeDisplayLabel(entry.backendModeUsed!)}',
                  color: AccountAdminMicroIaPanel._kPrestoOrange,
                ),
              if (entry.transcriptLength != null)
                _RuntimeChip(
                  label: 'Transcript: ${entry.transcriptLength} car.',
                  color: Colors.purple,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

String _sourceDisplayLabel(String source) {
  switch (source) {
    case 'cloud':
      return 'Cloud';
    case 'local':
    default:
      return 'Locale';
  }
}

Color _sourceColor(String source) {
  switch (source) {
    case 'cloud':
      return const Color(0xFF1565C0);
    case 'local':
    default:
      return const Color(0xFF6D4C41);
  }
}

Color _flowColor(String flowKey) {
  switch (flowKey) {
    case 'streaming_web':
      return const Color(0xFF00897B);
    case 'streaming_mobile':
      return const Color(0xFF1A73E8);
    case 'classic_web':
      return const Color(0xFFFF6600);
    case 'classic_mobile':
      return const Color(0xFFD84315);
    default:
      return const Color(0xFF455A64);
  }
}
class _AudioModeOption {
  final String value;
  final String label;
  final String description;
  final String routing;

  const _AudioModeOption({
    required this.value,
    required this.label,
    required this.description,
    required this.routing,
  });
}

class _AudioModeToggleCard extends StatelessWidget {
  final String label;
  final String description;
  final String routing;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _AudioModeToggleCard({
    required this.label,
    required this.description,
    required this.routing,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = selected
        ? AccountAdminMicroIaPanel._kPrestoOrange
        : AccountAdminMicroIaPanel._kPrestoBlue;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          decoration: BoxDecoration(
            color: selected
                ? accent.withOpacity(0.09)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? accent.withOpacity(0.85)
                  : Colors.black12,
              width: selected ? 1.8 : 1.0,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: accent.withOpacity(0.14),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? accent
                      : Colors.transparent,
                  border: Border.all(
                    color: selected ? accent : Colors.black26,
                    width: 2,
                  ),
                ),
                child: selected
                    ? const Icon(
                        Icons.check,
                        size: 14,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? accent.withOpacity(0.16)
                                : Colors.grey.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: selected
                                  ? accent.withOpacity(0.4)
                                  : Colors.black12,
                            ),
                          ),
                          child: Text(
                            selected ? 'ACTIF' : 'INACTIF',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: selected ? accent : Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      routing,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

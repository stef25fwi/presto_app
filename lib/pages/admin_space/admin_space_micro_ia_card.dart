// Carte de pilotage Micro IA de l'espace d'administration.
//
// Fragment de la bibliothèque `admin_space_page.dart` : le découpage
// réduit la taille des fichiers sans modifier la visibilité des types.
part of '../admin_space_page.dart';

class _MicroIaCard extends StatelessWidget {
  final Color prestoOrange;
  final Color prestoBlue;

  final MicroIaMode mode;
  final MicroIaAudioQuality audioQuality;
  final bool fallback;
  final double quality;
  final bool ultraFastEnabled;
  final List<String> languages;

  final ValueChanged<MicroIaMode> onModeChanged;
  final ValueChanged<bool> onUltraFastChanged;
  final ValueChanged<MicroIaAudioQuality> onAudioQualityChanged;
  final ValueChanged<bool> onFallbackChanged;
  final ValueChanged<double> onQualityChanged;
  final VoidCallback onAddLanguage;
  final ValueChanged<String> onRemoveLanguage;
  final VoidCallback? onSave;
  final bool saving;

  const _MicroIaCard({
    required this.prestoOrange,
    required this.prestoBlue,
    required this.mode,
    required this.audioQuality,
    required this.fallback,
    required this.quality,
    required this.ultraFastEnabled,
    required this.languages,
    required this.onModeChanged,
    required this.onUltraFastChanged,
    required this.onAudioQualityChanged,
    required this.onFallbackChanged,
    required this.onQualityChanged,
    required this.onAddLanguage,
    required this.onRemoveLanguage,
    required this.onSave,
    required this.saving,
  });

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Expanded(
                  child: Text(
                    'Micro-IA — Transcription',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Icon(Icons.more_horiz_rounded, color: Colors.black45),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (_, constraints) {
                final isWide = constraints.maxWidth >= 360;
                final padding = isWide ? 6.0 : 4.0;

                return Container(
                  padding: EdgeInsets.all(padding),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _SegButton(
                          label: 'Google STT',
                          selected: mode == MicroIaMode.google,
                          selectedColor: prestoOrange,
                          onTap: () => onModeChanged(MicroIaMode.google),
                        ),
                        const SizedBox(width: 6),
                        _SegButton(
                          label: 'Whisper',
                          selected: mode == MicroIaMode.whisper,
                          selectedColor: prestoOrange,
                          onTap: () => onModeChanged(MicroIaMode.whisper),
                        ),
                        const SizedBox(width: 6),
                        _SegButton(
                          label: 'Hybride',
                          selected: mode == MicroIaMode.hybride,
                          selectedColor: prestoOrange,
                          onTap: () => onModeChanged(MicroIaMode.hybride),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.bolt_rounded,
                                size: 18,
                                color: ultraFastEnabled
                                    ? prestoOrange
                                    : Colors.black54,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Ultra',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Transform.scale(
                                scale: 0.85,
                                child: Switch(
                                  value: ultraFastEnabled,
                                  activeThumbColor: prestoOrange,
                                  onChanged: onUltraFastChanged,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              "Qualité audio",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (_, constraints) {
                final isWide = constraints.maxWidth >= 360;
                final padding = isWide ? 6.0 : 4.0;

                return Container(
                  padding: EdgeInsets.all(padding),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Row(
                    children: [
                      _SegButton(
                        label: 'Basse',
                        selected: audioQuality == MicroIaAudioQuality.low,
                        selectedColor: prestoOrange,
                        onTap: () =>
                            onAudioQualityChanged(MicroIaAudioQuality.low),
                      ),
                      const SizedBox(width: 6),
                      _SegButton(
                        label: 'Moyenne',
                        selected: audioQuality == MicroIaAudioQuality.medium,
                        selectedColor: prestoOrange,
                        onTap: () =>
                            onAudioQualityChanged(MicroIaAudioQuality.medium),
                      ),
                      const SizedBox(width: 6),
                      _SegButton(
                        label: 'Haute',
                        selected: audioQuality == MicroIaAudioQuality.high,
                        selectedColor: prestoOrange,
                        onTap: () =>
                            onAudioQualityChanged(MicroIaAudioQuality.high),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: prestoBlue.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.autorenew_rounded,
                    color: prestoBlue,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fallback',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "Tente un autre provider si la qualité est faible",
                        style: TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: fallback,
                  onChanged: onFallbackChanged,
                  activeThumbColor: prestoOrange,
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Qualité minimum',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: quality.clamp(0.0, 1.0),
                    min: 0,
                    max: 1,
                    divisions: 100,
                    activeColor: prestoOrange,
                    onChanged: onQualityChanged,
                  ),
                ),
                SizedBox(
                  width: 56,
                  child: Text(
                    quality.toStringAsFixed(2),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final code in languages)
                  _LangChip(code: code, onRemove: () => onRemoveLanguage(code)),
                _AddChip(onTap: onAddLanguage),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: onSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: prestoOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text('Enregistrer les changements'),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.green.shade700),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Config publiée (Remote Config)',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              '• Prise en compte quasi immédiate côté Functions',
              style: TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

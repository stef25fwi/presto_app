part of 'payment_info_audio_admin_section.dart';

extension _PaymentInfoAudioAdminSectionView
    on _PaymentInfoAudioAdminSectionState {
  Widget _buildSection(BuildContext context) {
    return StreamBuilder<PaymentInfoAudioAdminSettings>(
      stream: _watchAdminSettings(),
      builder: (context, snapshot) {
        final settings = snapshot.data;
        if (settings != null) _hydrateTextFromSettings(settings);

        final draftAudioUrl = settings?.draftAudioUrl?.trim().isNotEmpty == true
            ? settings!.draftAudioUrl!.trim()
            : _lastPreviewedDraftUrl;
        final canPreview = draftAudioUrl != null && draftAudioUrl.isNotEmpty;
        final previewConfirmed =
            _hasPreviewedDraft && _lastPreviewedDraftUrl == draftAudioUrl;

        return Card(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.record_voice_over_rounded,
                      color: Color(0xFFFF6600),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Audio popup « Infos paiement »',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Le texte ci-dessous reprend le message du popup Infos paiement. Sauvegarde le texte, génère un MP3 brouillon, puis pré-écoute avant validation.',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _textController,
                  minLines: 8,
                  maxLines: 16,
                  decoration: const InputDecoration(
                    labelText: 'Texte qui servira de base à l’audio',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                    helperText:
                        'Toute modification annule la pré-écoute précédente.',
                  ),
                  onChanged: (_) {
                    if (_hasPreviewedDraft || _lastPreviewedDraftUrl != null) {
                      setState(() {
                        _hasPreviewedDraft = false;
                        _lastPreviewedDraftUrl = null;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isSavingText ? null : _saveText,
                      icon: _isSavingText
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _isSavingText ? 'Sauvegarde...' : 'Sauvegarder texte',
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _isGeneratingDraft ? null : _generateDraft,
                      icon: _isGeneratingDraft
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.graphic_eq_rounded),
                      label: Text(
                        _isGeneratingDraft
                            ? 'Génération MP3...'
                            : 'Générer le MP3 depuis ce texte',
                      ),
                    ),
                  ],
                ),
                if (_isGeneratingDraft) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(
                    backgroundColor: Color(0xFFE5E7EB),
                    color: Color(0xFF1A73E8),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Conversion du texte en MP3...',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (canPreview) ...[
                  const SizedBox(height: 16),
                  _buildPreviewPanel(
                    draftAudioUrl: draftAudioUrl,
                    previewConfirmed: previewConfirmed,
                  ),
                ],
                if (settings?.lastPublishedDate != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Dernière publication : ${settings!.lastPublishedDate}',
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

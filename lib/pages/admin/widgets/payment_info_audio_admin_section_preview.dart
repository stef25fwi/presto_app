part of 'payment_info_audio_admin_section.dart';

extension _PaymentInfoAudioAdminSectionPreview
    on _PaymentInfoAudioAdminSectionState {
  Widget _buildPreviewPlayer(String audioUrl) {
    final builder = widget.previewBuilder;
    if (builder != null) {
      return builder(
        audioUrl: audioUrl,
        onPlayed: () => _markDraftPreviewed(audioUrl),
      );
    }
    return PaymentInfoAudioPlayerButton(
      audioUrl: audioUrl,
      label: 'Pré-écouter le MP3',
      onPlayed: () => _markDraftPreviewed(audioUrl),
    );
  }

  Widget _buildPreviewPanel({
    required String draftAudioUrl,
    required bool previewConfirmed,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.headphones_rounded, color: Color(0xFF1A73E8)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pré-écoute du MP3 brouillon',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildPreviewPlayer(draftAudioUrl),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _markDraftPreviewed(draftAudioUrl),
            icon: Icon(
              previewConfirmed
                  ? Icons.check_circle_rounded
                  : Icons.hearing_rounded,
            ),
            label: Text(
              previewConfirmed
                  ? 'Pré-écoute confirmée'
                  : 'J’ai pré-écouté ce MP3',
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _isPublishingDraft ? null : _publishDraft,
            icon: _isPublishingDraft
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.cloud_done_rounded),
            label: Text(
              _isPublishingDraft
                  ? 'Publication...'
                  : 'Valider et publier le MP3',
            ),
          ),
          if (!previewConfirmed) ...[
            const SizedBox(height: 8),
            const Text(
              'Validation bloquée tant que la pré-écoute n’est pas confirmée.',
              style: TextStyle(
                color: Color(0xFFC47A00),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

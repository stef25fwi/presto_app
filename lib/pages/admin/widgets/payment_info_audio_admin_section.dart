import 'package:flutter/material.dart';

import 'package:presto_app/services/payment_info_audio_service.dart';
import 'package:presto_app/widgets/payment_info_audio_player_button.dart';

typedef PaymentInfoAudioAdminPlayerBuilder = Widget Function({
  required String audioUrl,
  required String label,
  required VoidCallback onPlayed,
});

const String _defaultPaymentInfoPopupAudioText = '''
Important : ilipresto.fr est un outil de communication et de petites annonces. La plateforme facilite la visibilité des offres et demandes, mais les relations, accords et prestations restent exclusivement conclus et gérés entre les utilisateurs.

Avant toute intervention, échangez clairement sur le prix, le mode de paiement, le délai, les frais éventuels et les conditions d’annulation.

Privilégiez un paiement traçable lorsque c’est possible. En cas de paiement en espèces, demandez ou remettez une preuve écrite simple indiquant la date, le montant et la prestation concernée.

Ne versez pas d’acompte important sans avoir vérifié l’identité du prestataire, les détails de l’intervention et les garanties proposées.

ilipresto.fr ne conserve pas les fonds, ne garantit pas la réalisation de la prestation et n’intervient pas dans les litiges de paiement entre utilisateurs.
''';

class PaymentInfoAudioAdminSection extends StatefulWidget {
  const PaymentInfoAudioAdminSection({
    super.key,
    this.service,
    this.playerBuilder,
  });

  final PaymentInfoAudioService? service;
  final PaymentInfoAudioAdminPlayerBuilder? playerBuilder;

  @override
  State<PaymentInfoAudioAdminSection> createState() =>
      _PaymentInfoAudioAdminSectionState();
}

class _PaymentInfoAudioAdminSectionState
    extends State<PaymentInfoAudioAdminSection> {
  late final PaymentInfoAudioService _service;
  late final TextEditingController _textController;

  bool _didHydrateText = false;
  bool _isSavingText = false;
  bool _isGeneratingDraft = false;
  bool _isPublishingDraft = false;
  bool _hasPreviewedDraft = false;
  String? _lastPreviewedDraftUrl;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? PaymentInfoAudioService();
    _textController = TextEditingController(
      text: _defaultPaymentInfoPopupAudioText.trim(),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _hydrateTextFromSettings(PaymentInfoAudioAdminSettings settings) {
    if (_didHydrateText) return;

    final savedText = settings.text.trim();

    if (savedText.isEmpty) {
      _didHydrateText = true;
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didHydrateText) return;

      _textController.text = savedText;

      setState(() {
        _didHydrateText = true;
      });
    });
  }

  String _cleanText() => _textController.text.trim();

  Future<void> _saveText() async {
    final text = _cleanText();

    if (text.isEmpty) {
      _showSnack('Le texte audio ne peut pas être vide.', isError: true);
      return;
    }

    setState(() => _isSavingText = true);

    try {
      await _service.saveAdminText(text);

      if (!mounted) return;

      _showSnack('Texte sauvegardé. Tu peux maintenant générer le MP3.');
    } catch (error) {
      if (!mounted) return;

      _showSnack(
        'Sauvegarde impossible : $error. Vérifie les règles Firestore admin_settings.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isSavingText = false);
    }
  }

  Future<void> _generateDraft() async {
    final text = _cleanText();

    if (text.isEmpty) {
      _showSnack('Le texte audio ne peut pas être vide.', isError: true);
      return;
    }

    setState(() {
      _isGeneratingDraft = true;
      _hasPreviewedDraft = false;
      _lastPreviewedDraftUrl = null;
    });

    try {
      await _service.saveAdminText(text);

      final settings = await _service.generatePaymentInfoAudioDraft(
        text: text,
      );

      if (!mounted) return;

      setState(() {
        _lastPreviewedDraftUrl = settings.draftAudioUrl;
        _hasPreviewedDraft = false;
      });

      _showSnack('MP3 brouillon généré. Pré-écoute-le avant validation.');
    } catch (error) {
      if (!mounted) return;

      _showSnack('Génération MP3 impossible : $error', isError: true);
    } finally {
      if (mounted) setState(() => _isGeneratingDraft = false);
    }
  }

  Future<void> _publishDraft() async {
    if (!_hasPreviewedDraft) {
      _showSnack(
        'Pré-écoute obligatoire : écoute le MP3 avant de le publier.',
        isError: true,
      );
      return;
    }

    setState(() => _isPublishingDraft = true);

    try {
      await _service.publishPaymentInfoAudioDraft();

      if (!mounted) return;

      _showSnack('MP3 Infos paiement validé et publié dans le popup.');
    } catch (error) {
      if (!mounted) return;

      _showSnack('Publication impossible : $error', isError: true);
    } finally {
      if (mounted) setState(() => _isPublishingDraft = false);
    }
  }

  void _markDraftPreviewed(String audioUrl) {
    setState(() {
      _hasPreviewedDraft = true;
      _lastPreviewedDraftUrl = audioUrl;
    });
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  Widget _buildPlayer({
    required String audioUrl,
    required VoidCallback onPlayed,
  }) {
    final builder = widget.playerBuilder;
    if (builder != null) {
      return builder(
        audioUrl: audioUrl,
        label: 'Pré-écouter le MP3',
        onPlayed: onPlayed,
      );
    }
    return PaymentInfoAudioPlayerButton(
      audioUrl: audioUrl,
      label: 'Pré-écouter le MP3',
      onPlayed: onPlayed,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PaymentInfoAudioAdminSettings>(
      stream: _service.watchAdminSettings(),
      builder: (context, snapshot) {
        final settings = snapshot.data;

        if (settings != null) {
          _hydrateTextFromSettings(settings);
        }

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
                  Container(
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
                            Icon(
                              Icons.headphones_rounded,
                              color: Color(0xFF1A73E8),
                            ),
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
                        _buildPlayer(
                          audioUrl: draftAudioUrl,
                          onPlayed: () => _markDraftPreviewed(draftAudioUrl),
                        ),
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

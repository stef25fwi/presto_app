import 'package:flutter/material.dart';

import '../services/payment_info_audio_service.dart';
import 'payment_info_audio_player_button.dart';

class PaymentInfoAudioAdminSectionProd extends StatefulWidget {
  const PaymentInfoAudioAdminSectionProd({super.key});

  @override
  State<PaymentInfoAudioAdminSectionProd> createState() =>
      _PaymentInfoAudioAdminSectionProdState();
}

class _PaymentInfoAudioAdminSectionProdState
    extends State<PaymentInfoAudioAdminSectionProd> {
  late final PaymentInfoAudioService _service;
  late final TextEditingController _textController;

  bool _isGeneratingDraft = false;
  bool _isPublishing = false;
  bool _didHydrateText = false;

  @override
  void initState() {
    super.initState();
    _service = PaymentInfoAudioService();
    _textController = TextEditingController();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _generateDraft() async {
    if (_isGeneratingDraft) return;

    final text = _textController.text.trim();

    if (text.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Ajoute un texte avant de générer le brouillon MP3.'),
        ),
      );
      return;
    }

    setState(() => _isGeneratingDraft = true);

    try {
      await _service.generatePaymentInfoAudioDraft(text: text);

      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(
            'Brouillon MP3 généré. Tu peux maintenant le pré-écouter.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Génération du brouillon MP3 impossible : $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isGeneratingDraft = false);
      }
    }
  }

  Future<void> _publishDraft() async {
    if (_isPublishing) return;

    setState(() => _isPublishing = true);

    try {
      await _service.publishPaymentInfoAudioDraft();

      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('MP3 publié dans le popup paiement avec succès.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Publication du MP3 impossible : $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isPublishing = false);
      }
    }
  }

  String _formatDate(DateTime? value, String emptyLabel, String prefix) {
    if (value == null) return emptyLabel;

    String two(int number) => number.toString().padLeft(2, '0');

    return '$prefix : ${two(value.day)}/${two(value.month)}/${value.year} '
        '${two(value.hour)}:${two(value.minute)}';
  }

  void _hydrateTextOnce(PaymentInfoAudioAdminSettings settings) {
    if (_didHydrateText) return;

    final savedText = settings.text.trim();
    if (savedText.isNotEmpty) {
      _textController.text = savedText;
    }

    _didHydrateText = true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<PaymentInfoAudioAdminSettings>(
          stream: _service.watchAdminSettings(),
          builder: (context, settingsSnapshot) {
            final settings = settingsSnapshot.data ??
                PaymentInfoAudioAdminSettings.fromMap(null);

            _hydrateTextOnce(settings);

            return StreamBuilder<PaymentInfoAudioConfig?>(
              stream: _service.watchConfig(),
              builder: (context, configSnapshot) {
                final config = configSnapshot.data;
                final canPlayPublished = config?.canPlay == true;
                final canPreviewDraft = settings.canPreviewDraft;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFFF6600).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.graphic_eq_rounded,
                            color: Color(0xFFFF6600),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Audio paiement MP3',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (canPlayPublished)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Colors.green,
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Édite le texte qui sert de base à l’audio, génère un '
                      'brouillon MP3, pré-écoute-le, puis publie seulement '
                      'quand le rendu est validé.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _textController,
                      minLines: 5,
                      maxLines: 9,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        labelText: 'Texte utilisé pour générer l’audio',
                        hintText:
                            'Explique ici le fonctionnement du paiement...',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _formatDate(
                        settings.draftGeneratedDate,
                        'Aucun brouillon MP3 généré pour le moment.',
                        'Dernier brouillon',
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(
                        config?.generatedDate,
                        'Aucun MP3 publié pour le moment.',
                        'Dernière publication',
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: _isGeneratingDraft ? null : _generateDraft,
                          icon: _isGeneratingDraft
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.auto_awesome_rounded),
                          label: Text(
                            _isGeneratingDraft
                                ? 'Génération du brouillon...'
                                : canPreviewDraft
                                    ? 'Regénérer le brouillon MP3'
                                    : 'Générer un brouillon MP3',
                          ),
                        ),
                        if (canPreviewDraft)
                          PaymentInfoAudioPlayerButton(
                            audioUrl: settings.draftAudioUrl!,
                            label: 'Pré-écouter le brouillon',
                          ),
                        if (canPreviewDraft)
                          OutlinedButton.icon(
                            onPressed: _isPublishing ? null : _publishDraft,
                            icon: _isPublishing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.publish_rounded),
                            label: Text(
                              _isPublishing
                                  ? 'Publication...'
                                  : 'Publier ce MP3',
                            ),
                          ),
                        if (canPlayPublished)
                          PaymentInfoAudioPlayerButton(
                            audioUrl: config!.audioUrl!,
                            label: 'Tester l’audio publié',
                          ),
                      ],
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

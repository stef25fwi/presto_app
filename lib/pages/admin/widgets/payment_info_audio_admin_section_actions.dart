part of 'payment_info_audio_admin_section.dart';

extension _PaymentInfoAudioAdminSectionActions
    on _PaymentInfoAudioAdminSectionState {
  Stream<PaymentInfoAudioAdminSettings> _watchAdminSettings() {
    return widget.settingsStream ?? _service!.watchAdminSettings();
  }

  Future<void> _saveAdminText(String text) async {
    final action = widget.saveAdminText;
    if (action != null) {
      await action(text);
      return;
    }
    await _service!.saveAdminText(text);
  }

  Future<PaymentInfoAudioAdminSettings> _generateAudioDraft(String text) async {
    final action = widget.generateDraft;
    if (action != null) return action(text: text);
    return _service!.generatePaymentInfoAudioDraft(text: text);
  }

  Future<void> _publishAudioDraft() async {
    final action = widget.publishDraft;
    if (action != null) {
      await action();
      return;
    }
    await _service!.publishPaymentInfoAudioDraft();
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
      _update(() => _didHydrateText = true);
    });
  }

  String _cleanText() => _textController.text.trim();

  Future<void> _saveText() async {
    final text = _cleanText();
    if (text.isEmpty) {
      _showSnack('Le texte audio ne peut pas être vide.', isError: true);
      return;
    }
    _update(() => _isSavingText = true);
    try {
      await _saveAdminText(text);
      if (!mounted) return;
      _showSnack('Texte sauvegardé. Tu peux maintenant générer le MP3.');
    } catch (error) {
      if (!mounted) return;
      _showSnack(
        'Sauvegarde impossible : $error. Vérifie les règles Firestore admin_settings.',
        isError: true,
      );
    } finally {
      if (mounted) _update(() => _isSavingText = false);
    }
  }

  Future<void> _generateDraft() async {
    final text = _cleanText();
    if (text.isEmpty) {
      _showSnack('Le texte audio ne peut pas être vide.', isError: true);
      return;
    }
    _update(() {
      _isGeneratingDraft = true;
      _hasPreviewedDraft = false;
      _lastPreviewedDraftUrl = null;
    });
    try {
      await _saveAdminText(text);
      final settings = await _generateAudioDraft(text);
      if (!mounted) return;
      _update(() {
        _lastPreviewedDraftUrl = settings.draftAudioUrl;
        _hasPreviewedDraft = false;
      });
      _showSnack('MP3 brouillon généré. Pré-écoute-le avant validation.');
    } catch (error) {
      if (!mounted) return;
      _showSnack('Génération MP3 impossible : $error', isError: true);
    } finally {
      if (mounted) _update(() => _isGeneratingDraft = false);
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
    _update(() => _isPublishingDraft = true);
    try {
      await _publishAudioDraft();
      if (!mounted) return;
      _showSnack('MP3 Infos paiement validé et publié dans le popup.');
    } catch (error) {
      if (!mounted) return;
      _showSnack('Publication impossible : $error', isError: true);
    } finally {
      if (mounted) _update(() => _isPublishingDraft = false);
    }
  }

  void _markDraftPreviewed(String audioUrl) {
    _update(() {
      _hasPreviewedDraft = true;
      _lastPreviewedDraftUrl = audioUrl;
    });
  }

  void _showSnack(String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : null,
        ),
      );
  }
}

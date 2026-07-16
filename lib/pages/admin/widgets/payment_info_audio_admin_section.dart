import 'package:flutter/material.dart';

import 'package:presto_app/services/payment_info_audio_service.dart';
import 'package:presto_app/widgets/payment_info_audio_player_button.dart';

part 'payment_info_audio_admin_section_actions.dart';
part 'payment_info_audio_admin_section_preview.dart';
part 'payment_info_audio_admin_section_view.dart';

typedef PaymentInfoAudioAdminTextSaver = Future<void> Function(String text);
typedef PaymentInfoAudioDraftGenerator =
    Future<PaymentInfoAudioAdminSettings> Function({required String text});
typedef PaymentInfoAudioDraftPublisher = Future<void> Function();
typedef PaymentInfoAudioPreviewBuilder = Widget Function({
  required String audioUrl,
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
    this.settingsStream,
    this.saveAdminText,
    this.generateDraft,
    this.publishDraft,
    this.previewBuilder,
  });

  final Stream<PaymentInfoAudioAdminSettings>? settingsStream;
  final PaymentInfoAudioAdminTextSaver? saveAdminText;
  final PaymentInfoAudioDraftGenerator? generateDraft;
  final PaymentInfoAudioDraftPublisher? publishDraft;
  final PaymentInfoAudioPreviewBuilder? previewBuilder;

  @override
  State<PaymentInfoAudioAdminSection> createState() =>
      _PaymentInfoAudioAdminSectionState();
}

class _PaymentInfoAudioAdminSectionState
    extends State<PaymentInfoAudioAdminSection> {
  PaymentInfoAudioService? _service;
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
    final needsService = widget.settingsStream == null ||
        widget.saveAdminText == null ||
        widget.generateDraft == null ||
        widget.publishDraft == null;
    if (needsService) _service = PaymentInfoAudioService();
    _textController = TextEditingController(
      text: _defaultPaymentInfoPopupAudioText.trim(),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _buildSection(context);
}

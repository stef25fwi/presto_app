import 'package:flutter/material.dart';

import '../../app/presto_overlay_theme.dart';
import '../../constants.dart';
import '../../data/marketplace/report_repository.dart';
import '../../models/marketplace_enums.dart';
import '../../models/marketplace_report.dart';
import '../../services/marketplace_human_verification.dart';
import '../../utils/friendly_snackbar.dart';

final ReportRepository _reportRepository = ReportRepository();
const MarketplaceHumanVerification _verification =
    MarketplaceHumanVerification();

@visibleForTesting
String messageReportReasonLabel(MessageReportReasonCode reason) {
  return switch (reason) {
    MessageReportReasonCode.spam => 'Spam',
    MessageReportReasonCode.fraud => 'Fraude / arnaque',
    MessageReportReasonCode.harassment => 'Harcèlement',
    MessageReportReasonCode.inappropriate => 'Contenu inapproprié',
    MessageReportReasonCode.other => 'Autre motif',
  };
}

Future<MessageReportReasonCode?> _pickReason(BuildContext context) {
  final overlayTheme = context.prestoOverlayTheme;
  return showModalBottomSheet<MessageReportReasonCode>(
    context: context,
    backgroundColor: overlayTheme.surfaceColor,
    shape: overlayTheme.sheetShape,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(6, 16, 6, 8),
            child: Text(
              'Signaler cette conversation',
              textAlign: TextAlign.center,
              style: kPrestoSectionTitleStyle,
            ),
          ),
          ...MessageReportReasonCode.values.map(
            (entry) => ListTile(
              tileColor: overlayTheme.surfaceColor,
              leading: const Icon(Icons.flag_outlined),
              title: Text(messageReportReasonLabel(entry)),
              onTap: () => Navigator.of(sheetContext).pop(entry),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

Future<String?> _askReasonText(BuildContext context) async {
  final controller = TextEditingController();
  try {
    return await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final overlayTheme = dialogContext.prestoOverlayTheme;
        return AlertDialog(
          backgroundColor: overlayTheme.surfaceColor,
          surfaceTintColor: overlayTheme.surfaceTintColor,
          shape: overlayTheme.dialogShape,
          title: const Text('Précisez le motif'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Décrivez brièvement le problème',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('Envoyer'),
            ),
          ],
        );
      },
    );
  } finally {
    controller.dispose();
  }
}

/// Demande le motif puis envoie le signalement de la conversation.
///
/// L'utilisateur signalé et le contrôle d'appartenance à la conversation sont
/// résolus côté serveur : le client n'envoie que l'identifiant de
/// conversation et le motif.
Future<void> showConversationReportSheet(
  BuildContext context, {
  required String conversationId,
}) async {
  final reason = await _pickReason(context);
  if (reason == null || !context.mounted) return;

  String? reasonText;
  if (reason == MessageReportReasonCode.other) {
    reasonText = await _askReasonText(context);
    if (!context.mounted) return;
  }

  try {
    final recaptchaToken = await _verification.obtainToken(
      MarketplaceHumanVerificationAction.messageReport,
    );
    final ok = await _reportRepository.reportConversation(
      ConversationReportDraft(
        conversationId: conversationId,
        reasonCode: reason,
        reasonText:
            (reasonText ?? '').trim().isEmpty ? null : reasonText!.trim(),
      ),
      recaptchaToken: recaptchaToken,
    );
    if (!context.mounted) return;
    if (ok) {
      showSuccessSnackBar(
          context, 'Signalement envoyé. Merci pour votre retour.');
    } else {
      showErrorSnackBar(context, 'Le signalement n\'a pas pu être envoyé.');
    }
  } catch (error) {
    debugPrint('[ConversationThread] report error: $error');
    if (!context.mounted) return;
    showErrorSnackBar(context, 'Erreur lors du signalement.');
  }
}

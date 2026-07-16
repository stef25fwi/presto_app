import 'dart:typed_data';

import '../features/subscriptions/subscription_credit_service.dart';
import 'journey_pdf_download_io.dart'
    if (dart.library.html) 'journey_pdf_download_web.dart' as platform;

final SubscriptionCreditService _journeyPdfCredits =
    SubscriptionCreditService();

/// Sauvegarde le PDF uniquement après réservation atomique d'un crédit serveur.
/// La réservation est remboursée si le téléchargement est annulé ou échoue.
Future<bool> saveJourneyPdfBytes({
  required Uint8List bytes,
  required String fileName,
}) async {
  final operationId = SubscriptionCreditService.newOperationId('journey_pdf');
  await _journeyPdfCredits.consume(
    kind: SubscriptionCreditKind.pdf,
    operationId: operationId,
  );

  try {
    final saved = await platform.saveJourneyPdfBytes(
      bytes: bytes,
      fileName: fileName,
    );
    if (!saved) {
      await _journeyPdfCredits.refund(
        kind: SubscriptionCreditKind.pdf,
        operationId: operationId,
      );
    }
    return saved;
  } catch (_) {
    await _journeyPdfCredits.refund(
      kind: SubscriptionCreditKind.pdf,
      operationId: operationId,
    );
    rethrow;
  }
}

import 'dart:typed_data';

import '../features/subscriptions/subscription_credit_service.dart';
import 'journey_pdf_download_io.dart'
    if (dart.library.html) 'journey_pdf_download_web.dart' as platform;

typedef JourneyPdfCreditAction = Future<void> Function({
  required SubscriptionCreditKind kind,
  required String operationId,
});
typedef JourneyPdfSaver = Future<bool> Function({
  required Uint8List bytes,
  required String fileName,
});

final SubscriptionCreditService _journeyPdfCredits =
    SubscriptionCreditService();

/// Sauvegarde le PDF uniquement après réservation atomique d'un crédit serveur.
/// La réservation est remboursée si le téléchargement est annulé ou échoue.
Future<bool> saveJourneyPdfBytes({
  required Uint8List bytes,
  required String fileName,
  JourneyPdfCreditAction? consumeCredit,
  JourneyPdfCreditAction? refundCredit,
  JourneyPdfSaver? saveBytes,
}) async {
  final consume = consumeCredit ?? _journeyPdfCredits.consume;
  final refund = refundCredit ?? _journeyPdfCredits.refund;
  final save = saveBytes ?? platform.saveJourneyPdfBytes;
  final operationId = SubscriptionCreditService.newOperationId('journey_pdf');
  await consume(
    kind: SubscriptionCreditKind.pdf,
    operationId: operationId,
  );

  try {
    final saved = await save(
      bytes: bytes,
      fileName: fileName,
    );
    if (!saved) {
      await refund(
        kind: SubscriptionCreditKind.pdf,
        operationId: operationId,
      );
    }
    return saved;
  } catch (_) {
    await refund(
      kind: SubscriptionCreditKind.pdf,
      operationId: operationId,
    );
    rethrow;
  }
}

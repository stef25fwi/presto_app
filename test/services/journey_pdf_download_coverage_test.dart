import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/subscriptions/subscription_credit_service.dart';
import 'package:presto_app/services/journey_pdf_download.dart';

void main() {
  test('consomme un crédit et conserve la sauvegarde réussie', () async {
    final actions = <String>[];
    final bytes = Uint8List.fromList(<int>[1, 2, 3]);

    final saved = await saveJourneyPdfBytes(
      bytes: bytes,
      fileName: 'parcours.pdf',
      consumeCredit: ({required kind, required operationId}) async {
        expect(kind, SubscriptionCreditKind.pdf);
        expect(operationId, startsWith('journey_pdf_'));
        actions.add('consume:$operationId');
      },
      refundCredit: ({required kind, required operationId}) async {
        actions.add('refund:$operationId');
      },
      saveBytes: ({required bytes, required fileName}) async {
        expect(bytes, <int>[1, 2, 3]);
        expect(fileName, 'parcours.pdf');
        actions.add('save');
        return true;
      },
    );

    expect(saved, isTrue);
    expect(actions, hasLength(2));
    expect(actions.first, startsWith('consume:journey_pdf_'));
    expect(actions.last, 'save');
  });

  test('rembourse le même crédit lorsque la sauvegarde est annulée', () async {
    String? consumedOperation;
    String? refundedOperation;

    final saved = await saveJourneyPdfBytes(
      bytes: Uint8List(0),
      fileName: 'annule.pdf',
      consumeCredit: ({required kind, required operationId}) async {
        consumedOperation = operationId;
      },
      refundCredit: ({required kind, required operationId}) async {
        refundedOperation = operationId;
      },
      saveBytes: ({required bytes, required fileName}) async => false,
    );

    expect(saved, isFalse);
    expect(refundedOperation, consumedOperation);
  });

  test('rembourse puis propage une erreur de sauvegarde', () async {
    String? consumedOperation;
    String? refundedOperation;

    await expectLater(
      saveJourneyPdfBytes(
        bytes: Uint8List.fromList(<int>[9]),
        fileName: 'erreur.pdf',
        consumeCredit: ({required kind, required operationId}) async {
          consumedOperation = operationId;
        },
        refundCredit: ({required kind, required operationId}) async {
          refundedOperation = operationId;
        },
        saveBytes: ({required bytes, required fileName}) async {
          throw StateError('stockage indisponible');
        },
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'stockage indisponible',
        ),
      ),
    );

    expect(refundedOperation, consumedOperation);
  });
}

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/offers/widgets/payment_info_popup.dart';
import 'package:presto_app/services/payment_info_audio_service.dart';

typedef _PopupHandle = ({Future<bool?> result});

Future<_PopupHandle> _openPopup(
  WidgetTester tester,
  FakeFirebaseFirestore firestore,
) async {
  PaymentInfoAudioService.setFirestoreForTesting(firestore);
  Future<bool?>? result;

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () {
                result = showPaymentInfoPopup(context);
              },
              child: const Text('Ouvrir les informations paiement'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Ouvrir les informations paiement'));
  await tester.pumpAndSettle();
  return (result: result!);
}

void main() {
  setUp(() {
    PaymentInfoAudioService.setFirestoreForTesting(null);
  });

  tearDown(() {
    PaymentInfoAudioService.setFirestoreForTesting(null);
  });

  testWidgets(
    'affiche les règles principales et ferme avec false',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final firestore = FakeFirebaseFirestore();
      await firestore.collection('public_config').doc('payment_info_audio').set(
        <String, dynamic>{
          'enabled': false,
          'audioUrl': '',
        },
      );

      final handle = await _openPopup(tester, firestore);

      expect(find.text('Avant de payer une prestation'), findsOneWidget);
      expect(find.textContaining('Prestation avec'), findsOneWidget);
      expect(
        find.textContaining('Prestation\nentre particuliers'),
        findsOneWidget,
      );
      expect(find.textContaining('Services à la personne'), findsOneWidget);
      expect(find.textContaining('Pour plus\nde sécurité'), findsOneWidget);
      expect(find.textContaining('Important :'), findsOneWidget);
      expect(find.text("Écouter l'explication"), findsNothing);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(await handle.result, isFalse);
    },
  );

  testWidgets('valide le dialogue avec le bouton compris', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final handle = await _openPopup(tester, FakeFirebaseFirestore());
    final understood = find.text("J'ai compris");

    await tester.ensureVisible(understood);
    await tester.pumpAndSettle();
    await tester.tap(understood);
    await tester.pumpAndSettle();

    expect(await handle.result, isTrue);
  });

  testWidgets(
    'un tap sur la barrière ferme le dialogue sans décision',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final handle = await _openPopup(tester, FakeFirebaseFirestore());

      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();

      expect(await handle.result, isNull);
    },
  );
}

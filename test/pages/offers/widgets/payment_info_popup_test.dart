import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/legal_info_page.dart';
import 'package:presto_app/pages/offers/widgets/payment_info_popup.dart';
import 'package:presto_app/services/payment_info_audio_service.dart';
import 'package:presto_app/widgets/payment_info_audio_player_button.dart';

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

  testWidgets('affiche le lecteur quand la configuration audio est active',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final firestore = FakeFirebaseFirestore();
    await firestore.collection('public_config').doc('payment_info_audio').set(
      <String, dynamic>{
        'enabled': true,
        'audioUrl': 'https://example.test/payment-info.mp3',
      },
    );

    final handle = await _openPopup(tester, firestore);

    expect(find.byType(PaymentInfoAudioPlayerButton), findsOneWidget);
    expect(find.text("Écouter l'explication"), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(await handle.result, isFalse);
  });

  testWidgets('ouvre les informations légales depuis le dialogue',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final previousFlutterErrorHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains(
            'ListTile background color or ink splashes may be invisible',
          )) {
        return;
      }
      previousFlutterErrorHandler?.call(details);
    };
    addTearDown(() {
      FlutterError.onError = previousFlutterErrorHandler;
    });

    final handle = await _openPopup(tester, FakeFirebaseFirestore());
    final moreInfo = find.text('En savoir plus sur les règles de paiement');

    await tester.ensureVisible(moreInfo);
    await tester.pumpAndSettle();
    await tester.tap(moreInfo);
    await tester.pumpAndSettle();

    expect(find.byType(PaymentInfoPopup), findsNothing);
    expect(find.byType(LegalInfoPage), findsOneWidget);
    expect(await handle.result, isNull);
  });

  testWidgets('rend les quatre règles et leurs justificatifs', (tester) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final handle = await _openPopup(tester, FakeFirebaseFirestore());

    for (final label in <String>[
      'Le paiement doit pouvoir être justifié.',
      'Paiement en espèces\nlimité à 1 000 €',
      "Le paiement en espèces est possible lorsqu'il ne s'agit pas d'un besoin professionnel.",
      'Preuve écrite\nnécessaire au-delà de\n1 500 €',
      'Pour certaines activités',
      'Le CESU permet de\ndéclarer et rémunérer',
      'Privilégiez toujours un paiement traçable',
      'Carte bancaire, virement,\npaiement sécurisé',
    ]) {
      expect(find.textContaining(label), findsOneWidget);
    }
    expect(find.byIcon(Icons.storefront_rounded), findsOneWidget);
    expect(find.byIcon(Icons.handshake_rounded), findsOneWidget);
    expect(find.byIcon(Icons.home_work_rounded), findsOneWidget);
    expect(find.byIcon(Icons.verified_user_rounded), findsOneWidget);
    expect(find.byIcon(Icons.payments_rounded), findsOneWidget);
    expect(find.byIcon(Icons.receipt_long_rounded), findsOneWidget);
    expect(find.byIcon(Icons.badge_rounded), findsOneWidget);
    expect(find.byIcon(Icons.description_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(await handle.result, isFalse);
  });
}

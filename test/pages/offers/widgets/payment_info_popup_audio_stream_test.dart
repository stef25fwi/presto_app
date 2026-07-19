import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/offers/widgets/payment_info_popup.dart';
import 'package:presto_app/services/payment_info_audio_service.dart';
import 'package:presto_app/widgets/payment_info_audio_player_button.dart';

void main() {
  setUp(() {
    PaymentInfoAudioService.setFirestoreForTesting(null);
  });

  tearDown(() {
    PaymentInfoAudioService.setFirestoreForTesting(null);
  });

  testWidgets('réagit aux changements de configuration audio en direct',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final firestore = FakeFirebaseFirestore();
    final config =
        firestore.collection('public_config').doc('payment_info_audio');
    await config.set(<String, dynamic>{
      'enabled': false,
      'audioUrl': '',
    });
    PaymentInfoAudioService.setFirestoreForTesting(firestore);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PaymentInfoPopup())),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PaymentInfoAudioPlayerButton), findsNothing);

    await config.set(<String, dynamic>{
      'enabled': true,
      'audioUrl': 'https://example.test/payment-info-live.mp3',
    });
    await tester.pumpAndSettle();

    expect(find.byType(PaymentInfoAudioPlayerButton), findsOneWidget);
    expect(find.text("Écouter l'explication"), findsOneWidget);

    await config.update(<String, dynamic>{'enabled': false});
    await tester.pumpAndSettle();

    expect(find.byType(PaymentInfoAudioPlayerButton), findsNothing);
  });
}

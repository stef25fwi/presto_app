import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/payment_info_audio_service.dart';

void main() {
  test('watchConfig suit création, désactivation et suppression du document', () async {
    final firestore = FakeFirebaseFirestore();
    final service = PaymentInfoAudioService(firestore: firestore);
    final ref = firestore.collection('public_config').doc('payment_info_audio');
    final values = <PaymentInfoAudioConfig?>[];
    final subscription = service.watchConfig().listen(values.add);

    await Future<void>.delayed(Duration.zero);
    await ref.set(<String, dynamic>{
      'enabled': true,
      'audioUrl': 'https://cdn.test/live.mp3',
      'version': 1,
    });
    await Future<void>.delayed(Duration.zero);
    await ref.set(<String, dynamic>{
      'enabled': false,
      'audioUrl': 'https://cdn.test/live.mp3',
      'version': 2,
    });
    await Future<void>.delayed(Duration.zero);
    await ref.delete();
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();

    expect(values, hasLength(4));
    expect(values[0], isNull);
    expect(values[1]?.canPlay, isTrue);
    expect(values[1]?.version, 1);
    expect(values[2]?.canPlay, isFalse);
    expect(values[2]?.version, 2);
    expect(values[3], isNull);
  });

  test('watchAdminSettings suit les mises à jour fusionnées du brouillon', () async {
    final firestore = FakeFirebaseFirestore();
    final service = PaymentInfoAudioService(firestore: firestore);
    final ref = firestore.collection('admin_settings').doc('payment_info_audio');
    final values = <PaymentInfoAudioAdminSettings>[];
    final subscription = service.watchAdminSettings().listen(values.add);

    await Future<void>.delayed(Duration.zero);
    await ref.set(<String, dynamic>{
      'paymentText': 'Paiement après prestation',
    });
    await Future<void>.delayed(Duration.zero);
    await ref.set(<String, dynamic>{
      'draftAudioUrl': 'https://cdn.test/draft.mp3',
      'draftVersion': 3,
    }, SetOptions(merge: true));
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();

    expect(values, hasLength(3));
    expect(values[0].text, isEmpty);
    expect(values[0].canPreviewDraft, isFalse);
    expect(values[1].text, 'Paiement après prestation');
    expect(values[1].canPreviewDraft, isFalse);
    expect(values[2].text, 'Paiement après prestation');
    expect(values[2].canPreviewDraft, isTrue);
    expect(values[2].draftVersion, 3);
  });

  test('les erreurs injectées arrêtent génération et publication', () async {
    final firestore = FakeFirebaseFirestore();
    final expected = StateError('functions indisponibles');
    final calls = <String>[];
    final service = PaymentInfoAudioService(
      firestore: firestore,
      callable: (name, parameters) async {
        calls.add(name);
        throw expected;
      },
    );

    await expectLater(
      service.generatePaymentInfoAudio(text: '  Paiement sécurisé  '),
      throwsA(same(expected)),
    );
    await expectLater(
      service.generatePaymentInfoAudioDraft(text: '  Brouillon  '),
      throwsA(same(expected)),
    );
    await expectLater(
      service.publishPaymentInfoAudioDraft(),
      throwsA(same(expected)),
    );

    expect(calls, <String>[
      'generatePaymentInfoAudio',
      'generatePaymentInfoAudioDraft',
      'publishPaymentInfoAudioDraft',
    ]);
    expect(await service.getConfig(), isNull);
    expect((await service.getAdminSettings()).text, isEmpty);
  });
}

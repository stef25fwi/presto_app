import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/payment_info_audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'test-api-key',
        appId: '1:123456789:web:test',
        messagingSenderId: '123456789',
        projectId: 'presto-audio-test',
        storageBucket: 'presto-audio-test.appspot.com',
      ),
    );
  });

  tearDown(() {
    PaymentInfoAudioService.setFirestoreForTesting(null);
    PaymentInfoAudioService.setCallableForTesting(null);
    PaymentInfoAudioService.setTextSaverForTesting(null);
  });

  test('utilise les dépendances statiques quand le constructeur est vide',
      () async {
    final firestore = FakeFirebaseFirestore();
    final calls = <String>[];
    final savedTexts = <String>[];

    PaymentInfoAudioService.setFirestoreForTesting(firestore);
    PaymentInfoAudioService.setCallableForTesting((name, parameters) async {
      calls.add(name);
    });
    PaymentInfoAudioService.setTextSaverForTesting((text) async {
      savedTexts.add(text);
    });

    final service = PaymentInfoAudioService();
    await service.saveAdminText('  Règles de paiement  ');
    final config = await service.generatePaymentInfoAudio();

    expect(savedTexts, <String>['Règles de paiement']);
    expect(calls, <String>['generatePaymentInfoAudio']);
    expect(config, isNull);
  });

  test('propage l indisponibilité de la plateforme Functions par défaut',
      () async {
    final firestore = FakeFirebaseFirestore();
    final service = PaymentInfoAudioService(firestore: firestore);

    await expectLater(
      service.generatePaymentInfoAudio(text: 'Paiement sécurisé'),
      throwsA(
        anyOf(
          isA<MissingPluginException>(),
          isA<FirebaseException>(),
        ),
      ),
    );

    final config = await firestore
        .collection('public_config')
        .doc('payment_info_audio')
        .get();
    expect(config.exists, isFalse);
  });

  test('propage l indisponibilité de la plateforme Storage par défaut',
      () async {
    final firestore = FakeFirebaseFirestore();
    final service = PaymentInfoAudioService(
      firestore: firestore,
      callable: (_, __) async {},
    );

    await expectLater(
      service.uploadAudio(Uint8List.fromList(<int>[1, 2, 3]), 'voice.mp3'),
      throwsA(
        anyOf(
          isA<MissingPluginException>(),
          isA<FirebaseException>(),
        ),
      ),
    );

    final config = await firestore
        .collection('public_config')
        .doc('payment_info_audio')
        .get();
    expect(config.exists, isFalse);
  });
}

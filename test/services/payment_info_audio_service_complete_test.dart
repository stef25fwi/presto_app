import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/payment_info_audio_service.dart';

typedef _CallableRecord = ({
  String name,
  Map<String, dynamic> parameters,
});

void main() {
  test('normalise la configuration audio et expose sa date de génération', () {
    final timestamp = Timestamp.fromMillisecondsSinceEpoch(1700000000000);
    final config = PaymentInfoAudioConfig.fromMap(<String, dynamic>{
      'enabled': true,
      'audioUrl': ' https://cdn.test/payment.mp3 ',
      'storagePath': 'payment_info_audio/payment.mp3',
      'contentType': 'audio/mpeg',
      'version': 7,
      'generatedAt': timestamp,
      'generatedBy': 'admin-1',
      'voice': 'alloy',
      'textHash': 'hash-1',
    });

    expect(config.canPlay, isTrue);
    expect(config.generatedDate, timestamp.toDate());
    expect(config.version, 7);
    expect(config.generatedBy, 'admin-1');

    final disabled = PaymentInfoAudioConfig.fromMap(<String, dynamic>{
      'enabled': true,
      'audioUrl': '   ',
      'version': '7',
      'generatedAt': 'invalid',
    });
    expect(disabled.canPlay, isFalse);
    expect(disabled.version, isNull);
    expect(disabled.generatedDate, isNull);
  });

  test('normalise les réglages administrateur et leurs dates', () {
    final generatedAt = Timestamp.fromMillisecondsSinceEpoch(1700000001000);
    final publishedAt = Timestamp.fromMillisecondsSinceEpoch(1700000002000);
    final settings = PaymentInfoAudioAdminSettings.fromMap(<String, dynamic>{
      'paymentText': 'Texte de paiement',
      'draftAudioUrl': 'https://cdn.test/draft.mp3',
      'draftStoragePath': 'drafts/payment.mp3',
      'draftContentType': 'audio/mpeg',
      'draftVersion': 3,
      'draftGeneratedAt': generatedAt,
      'draftGeneratedBy': 'admin-2',
      'draftVoice': 'nova',
      'draftTextHash': 'hash-2',
      'lastPublishedAt': publishedAt,
    });

    expect(settings.text, 'Texte de paiement');
    expect(settings.canPreviewDraft, isTrue);
    expect(settings.draftGeneratedDate, generatedAt.toDate());
    expect(settings.lastPublishedDate, publishedAt.toDate());

    final empty = PaymentInfoAudioAdminSettings.fromMap(<String, dynamic>{
      'audioText': 'Texte historique',
      'draftAudioUrl': ' ',
      'draftVersion': '3',
      'draftGeneratedAt': 'invalid',
      'lastPublishedAt': 'invalid',
    });
    expect(empty.text, 'Texte historique');
    expect(empty.canPreviewDraft, isFalse);
    expect(empty.draftVersion, isNull);
    expect(empty.draftGeneratedDate, isNull);
    expect(empty.lastPublishedDate, isNull);
  });

  test('lit, observe et enregistre les documents Firestore', () async {
    final firestore = FakeFirebaseFirestore();
    final service = PaymentInfoAudioService(firestore: firestore);

    expect(await service.getConfig(), isNull);
    expect(await service.watchConfig().first, isNull);

    await firestore.collection('public_config').doc('payment_info_audio').set(
      <String, dynamic>{
        'enabled': true,
        'audioUrl': 'https://cdn.test/live.mp3',
      },
    );
    await firestore.collection('admin_settings').doc('payment_info_audio').set(
      <String, dynamic>{
        'text': 'Réglez après la prestation',
        'draftAudioUrl': 'https://cdn.test/draft.mp3',
      },
    );

    expect((await service.getConfig())?.audioUrl, 'https://cdn.test/live.mp3');
    expect(
      (await service.watchConfig().first)?.canPlay,
      isTrue,
    );
    expect(
      (await service.getAdminSettings()).text,
      'Réglez après la prestation',
    );
    expect(
      (await service.watchAdminSettings().first).canPreviewDraft,
      isTrue,
    );
    expect(await service.watchAudioUrl().first, 'https://cdn.test/live.mp3');

    await service.saveAdminText('  Nouveau texte sécurisé  ');
    final saved = await firestore
        .collection('admin_settings')
        .doc('payment_info_audio')
        .get();
    expect(saved.data()?['text'], 'Nouveau texte sécurisé');
    expect(saved.data()?['paymentText'], 'Nouveau texte sécurisé');
    expect(saved.data()?['audioText'], 'Nouveau texte sécurisé');
  });

  test('route génération, brouillon et publication avec les bons payloads', () async {
    final firestore = FakeFirebaseFirestore();
    final calls = <_CallableRecord>[];
    final service = PaymentInfoAudioService(
      firestore: firestore,
      callable: (name, parameters) async {
        calls.add((
          name: name,
          parameters: Map<String, dynamic>.from(parameters),
        ));
      },
    );

    await firestore.collection('public_config').doc('payment_info_audio').set(
      <String, dynamic>{
        'enabled': true,
        'audioUrl': 'https://cdn.test/generated.mp3',
      },
    );
    await firestore.collection('admin_settings').doc('payment_info_audio').set(
      <String, dynamic>{
        'text': 'Texte brouillon',
        'draftAudioUrl': 'https://cdn.test/draft.mp3',
      },
    );

    final generated = await service.generatePaymentInfoAudio(
      text: '  Paiement après service  ',
      voice: 'nova',
      locale: 'fr-GP',
    );
    expect(generated?.canPlay, isTrue);

    await service.generatePaymentInfoAudio(text: '   ');

    final draft = await service.generatePaymentInfoAudioDraft(
      text: '  Brouillon validé  ',
      voice: 'echo',
      locale: 'fr-FR',
    );
    expect(draft.canPreviewDraft, isTrue);

    final published = await service.publishPaymentInfoAudioDraft();
    expect(published?.audioUrl, 'https://cdn.test/generated.mp3');

    expect(calls, hasLength(4));
    expect(calls[0].name, 'generatePaymentInfoAudio');
    expect(calls[0].parameters, <String, dynamic>{
      'text': 'Paiement après service',
      'voice': 'nova',
      'locale': 'fr-GP',
      'format': 'mp3',
    });
    expect(calls[1].parameters.containsKey('text'), isFalse);
    expect(calls[2].name, 'generatePaymentInfoAudioDraft');
    expect(calls[2].parameters, <String, dynamic>{
      'text': 'Brouillon validé',
      'voice': 'echo',
      'locale': 'fr-FR',
      'format': 'mp3',
    });
    expect(calls[3], (
      name: 'publishPaymentInfoAudioDraft',
      parameters: <String, dynamic>{},
    ));
  });

  test('refuse un texte de brouillon vide avant tout appel distant', () async {
    var called = false;
    final service = PaymentInfoAudioService(
      firestore: FakeFirebaseFirestore(),
      callable: (name, parameters) async {
        called = true;
      },
    );

    await expectLater(
      service.generatePaymentInfoAudioDraft(text: '   '),
      throwsA(isA<ArgumentError>()),
    );
    expect(called, isFalse);
  });

  test('publie une URL audio manuelle et valide les entrées', () async {
    final firestore = FakeFirebaseFirestore();
    final service = PaymentInfoAudioService(firestore: firestore);

    await expectLater(
      service.uploadAudioUrl('   '),
      throwsA(isA<ArgumentError>()),
    );

    await service.uploadAudioUrl('  https://cdn.test/manual.mp3  ');
    final snapshot = await firestore
        .collection('public_config')
        .doc('payment_info_audio')
        .get();
    expect(snapshot.data()?['enabled'], isTrue);
    expect(snapshot.data()?['audioUrl'], 'https://cdn.test/manual.mp3');
    expect(snapshot.data()?['contentType'], 'audio/mpeg');
    expect(snapshot.data()?['provider'], 'manual_url');
    expect(snapshot.data()?['version'], isA<int>());
  });

  test('upload un MP3 via la frontière de stockage puis publie sa config', () async {
    final firestore = FakeFirebaseFirestore();
    Uint8List? uploadedBytes;
    String? uploadedPath;
    String? uploadedContentType;
    final service = PaymentInfoAudioService(
      firestore: firestore,
      uploader: ({
        required Uint8List bytes,
        required String path,
        required String contentType,
      }) async {
        uploadedBytes = bytes;
        uploadedPath = path;
        uploadedContentType = contentType;
        return 'https://cdn.test/uploaded.mp3';
      },
    );

    final bytes = Uint8List.fromList(<int>[1, 2, 3, 4]);
    await service.uploadAudio(bytes, 'explication.mp3');

    expect(uploadedBytes, bytes);
    expect(uploadedPath, startsWith('payment_info_audio/'));
    expect(uploadedPath, endsWith('_explication.mp3'));
    expect(uploadedContentType, 'audio/mpeg');

    final snapshot = await firestore
        .collection('public_config')
        .doc('payment_info_audio')
        .get();
    expect(snapshot.data()?['audioUrl'], 'https://cdn.test/uploaded.mp3');
    expect(snapshot.data()?['storagePath'], uploadedPath);
    expect(snapshot.data()?['provider'], 'manual_upload');
    expect(snapshot.data()?['version'], isA<int>());
  });
}

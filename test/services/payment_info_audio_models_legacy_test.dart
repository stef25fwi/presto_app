import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/payment_info_audio_service.dart';

void main() {
  test('PaymentInfoAudioConfig parse les champs valides et ignore les types invalides', () {
    final generatedAt = Timestamp.fromDate(DateTime.utc(2026, 7, 20));
    final config = PaymentInfoAudioConfig.fromMap(<String, dynamic>{
      'enabled': true,
      'audioUrl': ' https://cdn.test/audio.mp3 ',
      'storagePath': 'payment/audio.mp3',
      'contentType': 'audio/mpeg',
      'version': 7,
      'generatedAt': generatedAt,
      'generatedBy': 'admin',
      'voice': 'alloy',
      'textHash': 'abc',
    });

    expect(config.canPlay, isTrue);
    expect(config.generatedDate, generatedAt.toDate());
    expect(config.version, 7);
    expect(config.generatedBy, 'admin');

    final fallback = PaymentInfoAudioConfig.fromMap(<String, dynamic>{
      'enabled': 'true',
      'audioUrl': '   ',
      'version': '7',
      'generatedAt': 'invalid',
    });
    expect(fallback.enabled, isFalse);
    expect(fallback.canPlay, isFalse);
    expect(fallback.version, isNull);
    expect(fallback.generatedDate, isNull);
  });

  test('PaymentInfoAudioAdminSettings applique les alias et dates', () {
    final draftAt = Timestamp.fromDate(DateTime.utc(2026, 7, 19));
    final publishedAt = Timestamp.fromDate(DateTime.utc(2026, 7, 20));
    final settings = PaymentInfoAudioAdminSettings.fromMap(<String, dynamic>{
      'paymentText': 'Paiement sécurisé',
      'draftAudioUrl': 'https://cdn.test/draft.mp3',
      'draftVersion': 4,
      'draftGeneratedAt': draftAt,
      'lastPublishedAt': publishedAt,
    });

    expect(settings.text, 'Paiement sécurisé');
    expect(settings.canPreviewDraft, isTrue);
    expect(settings.draftVersion, 4);
    expect(settings.draftGeneratedDate, draftAt.toDate());
    expect(settings.lastPublishedDate, publishedAt.toDate());

    final empty = PaymentInfoAudioAdminSettings.fromMap(null);
    expect(empty.text, isEmpty);
    expect(empty.canPreviewDraft, isFalse);
  });

  test('uploadAudio utilise l uploader injecté puis publie la configuration', () async {
    final firestore = FakeFirebaseFirestore();
    late String uploadedPath;
    late String uploadedContentType;
    late Uint8List uploadedBytes;
    final service = PaymentInfoAudioService(
      firestore: firestore,
      uploader: ({required bytes, required path, required contentType}) async {
        uploadedBytes = bytes;
        uploadedPath = path;
        uploadedContentType = contentType;
        return 'https://cdn.test/manual.mp3';
      },
    );

    final bytes = Uint8List.fromList(<int>[1, 2, 3]);
    await service.uploadAudio(bytes, 'preuve.mp3');

    expect(uploadedBytes, bytes);
    expect(uploadedPath, endsWith('_preuve.mp3'));
    expect(uploadedContentType, 'audio/mpeg');

    final config = await service.getConfig();
    expect(config?.canPlay, isTrue);
    expect(config?.audioUrl, 'https://cdn.test/manual.mp3');
    expect(config?.storagePath, uploadedPath);
    expect(config?.contentType, 'audio/mpeg');
  });

  test('uploadAudioUrl normalise l URL et refuse une valeur vide', () async {
    final firestore = FakeFirebaseFirestore();
    final service = PaymentInfoAudioService(firestore: firestore);

    await expectLater(
      service.uploadAudioUrl('   '),
      throwsA(isA<ArgumentError>()),
    );

    await service.uploadAudioUrl('  https://cdn.test/direct.mp3  ');
    final config = await service.getConfig();
    expect(config?.canPlay, isTrue);
    expect(config?.audioUrl, 'https://cdn.test/direct.mp3');
    expect(config?.contentType, 'audio/mpeg');
  });
}

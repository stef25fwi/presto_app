import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/payment_info_audio_service.dart';

void main() {
  group('PaymentInfoAudioConfig', () {
    test('fromMap normalise les données absentes et désactive la lecture', () {
      final config = PaymentInfoAudioConfig.fromMap(null);

      expect(config.enabled, isFalse);
      expect(config.audioUrl, isNull);
      expect(config.storagePath, isNull);
      expect(config.contentType, isNull);
      expect(config.version, isNull);
      expect(config.generatedAt, isNull);
      expect(config.generatedBy, isNull);
      expect(config.voice, isNull);
      expect(config.textHash, isNull);
      expect(config.canPlay, isFalse);
      expect(config.generatedDate, isNull);
    });

    test('fromMap expose les métadonnées valides et autorise la lecture', () {
      final generatedAt = Timestamp.fromDate(DateTime.utc(2026, 7, 14, 9));

      final config = PaymentInfoAudioConfig.fromMap({
        'enabled': true,
        'audioUrl': 'https://cdn.example/audio.mp3',
        'storagePath': 'payment_info_audio/file.mp3',
        'contentType': 'audio/mpeg',
        'version': 7,
        'generatedAt': generatedAt,
        'generatedBy': 'admin-1',
        'voice': 'alloy',
        'textHash': 'hash-1',
      });

      expect(config.enabled, isTrue);
      expect(config.audioUrl, 'https://cdn.example/audio.mp3');
      expect(config.storagePath, 'payment_info_audio/file.mp3');
      expect(config.contentType, 'audio/mpeg');
      expect(config.version, 7);
      expect(config.generatedAt, generatedAt);
      expect(config.generatedBy, 'admin-1');
      expect(config.voice, 'alloy');
      expect(config.textHash, 'hash-1');
      expect(config.canPlay, isTrue);
      expect(config.generatedDate, DateTime.utc(2026, 7, 14, 9));
    });

    test('fromMap ignore les types non attendus et les URL vides', () {
      final config = PaymentInfoAudioConfig.fromMap({
        'enabled': true,
        'audioUrl': '   ',
        'version': '8',
        'generatedAt': 'hier',
      });

      expect(config.version, isNull);
      expect(config.generatedAt, isNull);
      expect(config.canPlay, isFalse);
    });
  });

  group('PaymentInfoAudioAdminSettings', () {
    test('fromMap utilise des valeurs par défaut sans données', () {
      final settings = PaymentInfoAudioAdminSettings.fromMap(null);

      expect(settings.text, isEmpty);
      expect(settings.draftAudioUrl, isNull);
      expect(settings.draftStoragePath, isNull);
      expect(settings.draftContentType, isNull);
      expect(settings.draftVersion, isNull);
      expect(settings.draftGeneratedAt, isNull);
      expect(settings.draftGeneratedBy, isNull);
      expect(settings.draftVoice, isNull);
      expect(settings.draftTextHash, isNull);
      expect(settings.lastGeneratedAt, isNull);
      expect(settings.lastPublishedAt, isNull);
      expect(settings.canPreviewDraft, isFalse);
      expect(settings.draftGeneratedDate, isNull);
      expect(settings.lastPublishedDate, isNull);
    });

    test('fromMap lit les alias de texte et les dates du brouillon', () {
      final draftGeneratedAt = Timestamp.fromDate(DateTime.utc(2026, 7, 14));
      final lastPublishedAt = Timestamp.fromDate(DateTime.utc(2026, 7, 15));
      final lastGeneratedAt = Timestamp.fromDate(DateTime.utc(2026, 7, 13));

      final settings = PaymentInfoAudioAdminSettings.fromMap({
        'paymentText': 'Texte paiement',
        'draftAudioUrl': 'https://cdn.example/draft.mp3',
        'draftStoragePath': 'drafts/audio.mp3',
        'draftContentType': 'audio/mpeg',
        'draftVersion': 3,
        'draftGeneratedAt': draftGeneratedAt,
        'draftGeneratedBy': 'admin-2',
        'draftVoice': 'nova',
        'draftTextHash': 'hash-2',
        'lastGeneratedAt': lastGeneratedAt,
        'lastPublishedAt': lastPublishedAt,
      });

      expect(settings.text, 'Texte paiement');
      expect(settings.draftAudioUrl, 'https://cdn.example/draft.mp3');
      expect(settings.draftStoragePath, 'drafts/audio.mp3');
      expect(settings.draftContentType, 'audio/mpeg');
      expect(settings.draftVersion, 3);
      expect(settings.draftGeneratedAt, draftGeneratedAt);
      expect(settings.draftGeneratedBy, 'admin-2');
      expect(settings.draftVoice, 'nova');
      expect(settings.draftTextHash, 'hash-2');
      expect(settings.lastGeneratedAt, lastGeneratedAt);
      expect(settings.lastPublishedAt, lastPublishedAt);
      expect(settings.canPreviewDraft, isTrue);
      expect(settings.draftGeneratedDate, DateTime.utc(2026, 7, 14));
      expect(settings.lastPublishedDate, DateTime.utc(2026, 7, 15));
    });

    test('fromMap préfère text à paymentText puis audioText', () {
      expect(
        PaymentInfoAudioAdminSettings.fromMap({'audioText': 'Audio'}).text,
        'Audio',
      );
      expect(
        PaymentInfoAudioAdminSettings.fromMap({
          'paymentText': 'Paiement',
          'audioText': 'Audio',
        }).text,
        'Paiement',
      );
      expect(
        PaymentInfoAudioAdminSettings.fromMap({
          'text': 'Principal',
          'paymentText': 'Paiement',
          'audioText': 'Audio',
        }).text,
        'Principal',
      );
    });

    test('fromMap ignore les mauvais types et les brouillons vides', () {
      final settings = PaymentInfoAudioAdminSettings.fromMap({
        'text': 42,
        'draftAudioUrl': '  ',
        'draftVersion': '4',
        'draftGeneratedAt': 'demain',
        'lastGeneratedAt': 'hier',
        'lastPublishedAt': 'aujourd hui',
      });

      expect(settings.text, '42');
      expect(settings.draftVersion, isNull);
      expect(settings.draftGeneratedAt, isNull);
      expect(settings.lastGeneratedAt, isNull);
      expect(settings.lastPublishedAt, isNull);
      expect(settings.canPreviewDraft, isFalse);
    });
  });

  group('PaymentInfoAudioService avec Firestore', () {
    late FakeFirebaseFirestore firestore;
    late PaymentInfoAudioService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = PaymentInfoAudioService(firestore: firestore);
    });

    test('getConfig retourne null sans configuration publiée', () async {
      expect(await service.getConfig(), isNull);
    });

    test('watchConfig émet null puis la configuration publiée', () async {
      final stream = service.watchConfig();
      expect(await stream.first, isNull);

      await firestore.collection('public_config').doc('payment_info_audio').set({
        'enabled': true,
        'audioUrl': 'https://cdn.example/published.mp3',
      });

      final config = await stream.firstWhere((value) => value?.canPlay ?? false);
      expect(config!.audioUrl, 'https://cdn.example/published.mp3');
    });

    test('getAdminSettings retourne des réglages vides sans document', () async {
      final settings = await service.getAdminSettings();

      expect(settings.text, isEmpty);
      expect(settings.canPreviewDraft, isFalse);
    });

    test('watchAdminSettings émet les réglages mis à jour', () async {
      final stream = service.watchAdminSettings();
      expect((await stream.first).text, isEmpty);

      await firestore.collection('admin_settings').doc('payment_info_audio').set({
        'text': 'Informations audio',
        'draftAudioUrl': 'https://cdn.example/draft.mp3',
      });

      final settings = await stream.firstWhere(
        (value) => value.text == 'Informations audio',
      );
      expect(settings.canPreviewDraft, isTrue);
    });

    test('saveAdminText enregistre le texte nettoyé sur tous les alias', () async {
      await service.saveAdminText('  Consignes de paiement  ');

      final snapshot = await firestore
          .collection('admin_settings')
          .doc('payment_info_audio')
          .get();
      final data = snapshot.data()!;

      expect(data['text'], 'Consignes de paiement');
      expect(data['paymentText'], 'Consignes de paiement');
      expect(data['audioText'], 'Consignes de paiement');
      expect(data['updatedAt'], isA<Timestamp>());
    });

    test('watchAudioUrl expose seulement l URL publiée', () async {
      final stream = service.watchAudioUrl();
      expect(await stream.first, isNull);

      await firestore.collection('public_config').doc('payment_info_audio').set({
        'enabled': true,
        'audioUrl': 'https://cdn.example/audio.mp3',
      });

      expect(
        await stream.firstWhere((value) => value != null),
        'https://cdn.example/audio.mp3',
      );
    });

    test('uploadAudioUrl refuse une URL vide', () async {
      expect(
        () => service.uploadAudioUrl('   '),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('uploadAudioUrl publie une URL nettoyée', () async {
      await service.uploadAudioUrl('  https://cdn.example/manual.mp3  ');

      final snapshot = await firestore
          .collection('public_config')
          .doc('payment_info_audio')
          .get();
      final data = snapshot.data()!;

      expect(data['enabled'], isTrue);
      expect(data['audioUrl'], 'https://cdn.example/manual.mp3');
      expect(data['contentType'], 'audio/mpeg');
      expect(data['version'], isA<int>());
      expect(data['generatedAt'], isA<Timestamp>());
      expect(data['provider'], 'manual_url');
    });
  });
}

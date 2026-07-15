import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/payment_info_audio_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late PaymentInfoAudioService service;

  Timestamp timestamp(int day, int hour) =>
      Timestamp.fromDate(DateTime.utc(2026, 7, day, hour));

  setUp(() async {
    firestore = FakeFirebaseFirestore();

    await firestore.collection('public_config').doc('payment_info_audio').set({
      'enabled': true,
      'audioUrl': 'https://cdn.example.com/payment-info.mp3',
      'storagePath': 'payment_info_audio/current.mp3',
      'contentType': 'audio/mpeg',
      'version': 7,
      'generatedAt': timestamp(14, 10),
      'generatedBy': 'admin-current',
      'voice': 'alloy',
      'textHash': 'config-hash',
    });

    await firestore.collection('admin_settings').doc('payment_info_audio').set({
      'text': 'Texte de paiement validé',
      'draftAudioUrl': 'https://cdn.example.com/draft.mp3',
      'draftStoragePath': 'payment_info_audio/draft.mp3',
      'draftContentType': 'audio/mpeg',
      'draftVersion': 8,
      'draftGeneratedAt': timestamp(15, 9),
      'draftGeneratedBy': 'admin-draft',
      'draftVoice': 'nova',
      'draftTextHash': 'draft-hash',
      'lastGeneratedAt': timestamp(15, 9),
      'lastPublishedAt': timestamp(14, 11),
    });

    service = PaymentInfoAudioService(firestore: firestore);
  });

  test('watchConfig émet une configuration bornée et correctement mappée',
      () async {
    final configs = await service.watchConfig().take(1).toList();

    expect(configs, hasLength(1));
    final config = configs.single;
    expect(config, isNotNull);
    expect(config!.enabled, isTrue);
    expect(config.audioUrl, 'https://cdn.example.com/payment-info.mp3');
    expect(config.storagePath, 'payment_info_audio/current.mp3');
    expect(config.contentType, 'audio/mpeg');
    expect(config.version, 7);
    expect(config.generatedAt, timestamp(14, 10));
    expect(config.generatedBy, 'admin-current');
    expect(config.voice, 'alloy');
    expect(config.textHash, 'config-hash');
    expect(config.canPlay, isTrue);
    expect(
      config.generatedDate,
      isA<DateTime>().having(
        (value) => value.isAtSameMomentAs(DateTime.utc(2026, 7, 14, 10)),
        'instant',
        isTrue,
      ),
    );
  });

  test('watchAudioUrl émet une URL bornée depuis la configuration', () async {
    final urls = await service.watchAudioUrl().take(1).toList();

    expect(urls, ['https://cdn.example.com/payment-info.mp3']);
  });

  test('watchAdminSettings émet des paramètres bornés et correctement mappés',
      () async {
    final settingsEvents = await service.watchAdminSettings().take(1).toList();

    expect(settingsEvents, hasLength(1));
    final settings = settingsEvents.single;
    expect(settings.text, 'Texte de paiement validé');
    expect(settings.draftAudioUrl, 'https://cdn.example.com/draft.mp3');
    expect(settings.draftStoragePath, 'payment_info_audio/draft.mp3');
    expect(settings.draftContentType, 'audio/mpeg');
    expect(settings.draftVersion, 8);
    expect(settings.draftGeneratedAt, timestamp(15, 9));
    expect(settings.draftGeneratedBy, 'admin-draft');
    expect(settings.draftVoice, 'nova');
    expect(settings.draftTextHash, 'draft-hash');
    expect(settings.lastGeneratedAt, timestamp(15, 9));
    expect(settings.lastPublishedAt, timestamp(14, 11));
    expect(settings.canPreviewDraft, isTrue);
    expect(
      settings.draftGeneratedDate,
      isA<DateTime>().having(
        (value) => value.isAtSameMomentAs(DateTime.utc(2026, 7, 15, 9)),
        'instant',
        isTrue,
      ),
    );
    expect(
      settings.lastPublishedDate,
      isA<DateTime>().having(
        (value) => value.isAtSameMomentAs(DateTime.utc(2026, 7, 14, 11)),
        'instant',
        isTrue,
      ),
    );
  });

  test('watchConfig émet null quand le document public est absent', () async {
    await firestore.collection('public_config').doc('payment_info_audio').delete();

    final configs = await service.watchConfig().take(1).toList();

    expect(configs, [isNull]);
  });

  test('watchAdminSettings utilise les valeurs par défaut sans document',
      () async {
    await firestore
        .collection('admin_settings')
        .doc('payment_info_audio')
        .delete();

    final settingsEvents = await service.watchAdminSettings().take(1).toList();

    expect(settingsEvents, hasLength(1));
    final settings = settingsEvents.single;
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
}

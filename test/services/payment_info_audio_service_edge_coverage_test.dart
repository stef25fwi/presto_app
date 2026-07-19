import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/payment_info_audio_service.dart';

void main() {
  test('configuration vide reste désactivée et sans métadonnées', () {
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

  test('configuration complète conserve toutes les métadonnées', () {
    final generatedAt = Timestamp.fromMillisecondsSinceEpoch(1700000000000);
    final config = PaymentInfoAudioConfig.fromMap(<String, dynamic>{
      'enabled': true,
      'audioUrl': 'https://cdn.test/payment.mp3',
      'storagePath': 'payment_info_audio/payment.mp3',
      'contentType': 'audio/mpeg',
      'version': 12,
      'generatedAt': generatedAt,
      'generatedBy': 'admin-42',
      'voice': 'nova',
      'textHash': 'sha256-payment',
    });

    expect(config.enabled, isTrue);
    expect(config.audioUrl, 'https://cdn.test/payment.mp3');
    expect(config.storagePath, 'payment_info_audio/payment.mp3');
    expect(config.contentType, 'audio/mpeg');
    expect(config.version, 12);
    expect(config.generatedAt, generatedAt);
    expect(config.generatedBy, 'admin-42');
    expect(config.voice, 'nova');
    expect(config.textHash, 'sha256-payment');
    expect(config.canPlay, isTrue);
    expect(config.generatedDate, generatedAt.toDate());
  });

  test('réglages vides appliquent les valeurs sûres', () {
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

  test('réglages complets conservent brouillon, auteur et dates', () {
    final draftGeneratedAt =
        Timestamp.fromMillisecondsSinceEpoch(1700000001000);
    final lastGeneratedAt =
        Timestamp.fromMillisecondsSinceEpoch(1700000002000);
    final lastPublishedAt =
        Timestamp.fromMillisecondsSinceEpoch(1700000003000);
    final settings = PaymentInfoAudioAdminSettings.fromMap(<String, dynamic>{
      'text': 'Texte prioritaire',
      'paymentText': 'Texte historique ignoré',
      'audioText': 'Autre texte ignoré',
      'draftAudioUrl': 'https://cdn.test/draft.mp3',
      'draftStoragePath': 'payment_info_audio/draft.mp3',
      'draftContentType': 'audio/mpeg',
      'draftVersion': 8,
      'draftGeneratedAt': draftGeneratedAt,
      'draftGeneratedBy': 'admin-7',
      'draftVoice': 'alloy',
      'draftTextHash': 'draft-hash',
      'lastGeneratedAt': lastGeneratedAt,
      'lastPublishedAt': lastPublishedAt,
    });

    expect(settings.text, 'Texte prioritaire');
    expect(settings.draftAudioUrl, 'https://cdn.test/draft.mp3');
    expect(settings.draftStoragePath, 'payment_info_audio/draft.mp3');
    expect(settings.draftContentType, 'audio/mpeg');
    expect(settings.draftVersion, 8);
    expect(settings.draftGeneratedAt, draftGeneratedAt);
    expect(settings.draftGeneratedBy, 'admin-7');
    expect(settings.draftVoice, 'alloy');
    expect(settings.draftTextHash, 'draft-hash');
    expect(settings.lastGeneratedAt, lastGeneratedAt);
    expect(settings.lastPublishedAt, lastPublishedAt);
    expect(settings.canPreviewDraft, isTrue);
    expect(settings.draftGeneratedDate, draftGeneratedAt.toDate());
    expect(settings.lastPublishedDate, lastPublishedAt.toDate());
  });

  test('document administrateur absent est lu et observé sans erreur', () async {
    final firestore = FakeFirebaseFirestore();
    final service = PaymentInfoAudioService(firestore: firestore);

    final direct = await service.getAdminSettings();
    final streamed = await service.watchAdminSettings().first;

    expect(direct.text, isEmpty);
    expect(direct.canPreviewDraft, isFalse);
    expect(streamed.text, isEmpty);
    expect(streamed.canPreviewDraft, isFalse);
  });

  test('sauvegarde injectée reçoit le texte normalisé et propage son erreur',
      () async {
    final saved = <String>[];
    final expectedError = StateError('écriture refusée');
    final service = PaymentInfoAudioService(
      firestore: FakeFirebaseFirestore(),
      textSaver: (text) async {
        saved.add(text);
        throw expectedError;
      },
    );

    await expectLater(
      service.saveAdminText('  Paiement sécurisé  '),
      throwsA(same(expectedError)),
    );
    expect(saved, <String>['Paiement sécurisé']);
  });
}

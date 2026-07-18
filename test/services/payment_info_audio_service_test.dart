import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/payment_info_audio_service.dart';

void main() {
  group('PaymentInfoAudioConfig', () {
    test('parses complete data and derived values', () {
      final generatedAt = Timestamp.fromDate(DateTime.utc(2026, 7, 17, 12));
      final config = PaymentInfoAudioConfig.fromMap(<String, dynamic>{
        'enabled': true,
        'audioUrl': ' https://cdn.example.test/payment.mp3 ',
        'storagePath': 'payment_info_audio/payment.mp3',
        'contentType': 'audio/mpeg',
        'version': 7,
        'generatedAt': generatedAt,
        'generatedBy': 'admin-1',
        'voice': 'alloy',
        'textHash': 'hash-1',
      });

      expect(config.enabled, isTrue);
      expect(config.canPlay, isTrue);
      expect(config.generatedDate, DateTime.utc(2026, 7, 17, 12));
      expect(config.storagePath, 'payment_info_audio/payment.mp3');
      expect(config.contentType, 'audio/mpeg');
      expect(config.version, 7);
      expect(config.generatedBy, 'admin-1');
      expect(config.voice, 'alloy');
      expect(config.textHash, 'hash-1');
    });

    test('uses safe defaults for null and malformed values', () {
      final empty = PaymentInfoAudioConfig.fromMap(null);
      final malformed = PaymentInfoAudioConfig.fromMap(<String, dynamic>{
        'enabled': 'yes',
        'audioUrl': '   ',
        'version': 1.5,
        'generatedAt': 'today',
      });

      expect(empty.enabled, isFalse);
      expect(empty.canPlay, isFalse);
      expect(empty.generatedDate, isNull);
      expect(malformed.enabled, isFalse);
      expect(malformed.canPlay, isFalse);
      expect(malformed.version, isNull);
      expect(malformed.generatedAt, isNull);
    });
  });

  group('PaymentInfoAudioAdminSettings', () {
    test('parses canonical fields and dates', () {
      final generatedAt = Timestamp.fromDate(DateTime.utc(2026, 7, 16));
      final publishedAt = Timestamp.fromDate(DateTime.utc(2026, 7, 17));
      final settings = PaymentInfoAudioAdminSettings.fromMap(<String, dynamic>{
        'text': 'Texte paiement',
        'draftAudioUrl': 'https://cdn.example.test/draft.mp3',
        'draftStoragePath': 'drafts/draft.mp3',
        'draftContentType': 'audio/mpeg',
        'draftVersion': 3,
        'draftGeneratedAt': generatedAt,
        'draftGeneratedBy': 'admin-2',
        'draftVoice': 'nova',
        'draftTextHash': 'hash-2',
        'lastGeneratedAt': generatedAt,
        'lastPublishedAt': publishedAt,
      });

      expect(settings.text, 'Texte paiement');
      expect(settings.canPreviewDraft, isTrue);
      expect(settings.draftGeneratedDate, DateTime.utc(2026, 7, 16));
      expect(settings.lastPublishedDate, DateTime.utc(2026, 7, 17));
      expect(settings.draftVersion, 3);
      expect(settings.draftGeneratedBy, 'admin-2');
      expect(settings.draftVoice, 'nova');
      expect(settings.draftTextHash, 'hash-2');
    });

    test('supports historical text aliases and safe defaults', () {
      final paymentText = PaymentInfoAudioAdminSettings.fromMap(
        <String, dynamic>{'paymentText': 'Ancien texte'},
      );
      final audioText = PaymentInfoAudioAdminSettings.fromMap(
        <String, dynamic>{'audioText': 42, 'draftAudioUrl': '   '},
      );
      final empty = PaymentInfoAudioAdminSettings.fromMap(null);

      expect(paymentText.text, 'Ancien texte');
      expect(audioText.text, '42');
      expect(audioText.canPreviewDraft, isFalse);
      expect(empty.text, isEmpty);
      expect(empty.draftGeneratedDate, isNull);
      expect(empty.lastPublishedDate, isNull);
    });
  });

  group('PaymentInfoAudioService', () {
    late FakeFirebaseFirestore firestore;
    late List<(String, Map<String, dynamic>)> calls;
    late List<String> savedTexts;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      calls = <(String, Map<String, dynamic>)>[];
      savedTexts = <String>[];
    });

    PaymentInfoAudioService buildService({PaymentInfoAudioUploader? uploader}) {
      return PaymentInfoAudioService(
        firestore: firestore,
        callable: (name, parameters) async {
          calls.add((name, Map<String, dynamic>.from(parameters)));
        },
        uploader: uploader,
        textSaver: (text) async => savedTexts.add(text),
      );
    }

    test('reads null config then parses an existing config', () async {
      final service = buildService();
      expect(await service.getConfig(), isNull);

      await firestore.collection('public_config').doc('payment_info_audio').set(
        <String, dynamic>{
          'enabled': true,
          'audioUrl': 'https://cdn.example.test/live.mp3',
        },
      );

      final config = await service.getConfig();
      expect(config, isNotNull);
      expect(config!.canPlay, isTrue);
    });

    test('watches config creation and admin settings updates', () async {
      final service = buildService();
      final configFuture = service.watchConfig().firstWhere((value) => value != null);
      final settingsFuture = service
          .watchAdminSettings()
          .firstWhere((value) => value.text == 'Nouveau texte');

      await firestore.collection('public_config').doc('payment_info_audio').set(
        <String, dynamic>{
          'enabled': true,
          'audioUrl': 'https://cdn.example.test/live.mp3',
        },
      );
      await firestore.collection('admin_settings').doc('payment_info_audio').set(
        <String, dynamic>{'text': 'Nouveau texte'},
      );

      expect((await configFuture)!.audioUrl, contains('live.mp3'));
      expect((await settingsFuture).text, 'Nouveau texte');
    });

    test('trims admin text before using the injected saver', () async {
      final service = buildService();
      await service.saveAdminText('  Informations de paiement  ');
      expect(savedTexts, <String>['Informations de paiement']);
    });

    test('generates legacy audio with normalized optional text', () async {
      await firestore.collection('public_config').doc('payment_info_audio').set(
        <String, dynamic>{
          'enabled': true,
          'audioUrl': 'https://cdn.example.test/generated.mp3',
        },
      );
      final service = buildService();

      final config = await service.generatePaymentInfoAudio(
        text: '  Paiement sécurisé  ',
        voice: 'nova',
        locale: 'fr-GP',
      );

      expect(calls.single.$1, 'generatePaymentInfoAudio');
      expect(calls.single.$2, <String, dynamic>{
        'text': 'Paiement sécurisé',
        'voice': 'nova',
        'locale': 'fr-GP',
        'format': 'mp3',
      });
      expect(config!.audioUrl, contains('generated.mp3'));
    });

    test('omits blank optional text from legacy generation', () async {
      final service = buildService();
      await service.generatePaymentInfoAudio(text: '   ');

      expect(calls.single.$2.containsKey('text'), isFalse);
      expect(calls.single.$2['voice'], 'alloy');
      expect(calls.single.$2['locale'], 'fr-FR');
    });

    test('rejects an empty draft before invoking the callable', () async {
      final service = buildService();
      await expectLater(
        service.generatePaymentInfoAudioDraft(text: '   '),
        throwsA(isA<ArgumentError>()),
      );
      expect(calls, isEmpty);
    });

    test('generates a draft then returns refreshed admin settings', () async {
      await firestore.collection('admin_settings').doc('payment_info_audio').set(
        <String, dynamic>{
          'text': 'Texte',
          'draftAudioUrl': 'https://cdn.example.test/draft.mp3',
        },
      );
      final service = buildService();

      final settings = await service.generatePaymentInfoAudioDraft(
        text: '  Texte du brouillon  ',
        voice: 'echo',
        locale: 'fr-FR',
      );

      expect(calls.single.$1, 'generatePaymentInfoAudioDraft');
      expect(calls.single.$2['text'], 'Texte du brouillon');
      expect(calls.single.$2['voice'], 'echo');
      expect(calls.single.$2['format'], 'mp3');
      expect(settings.canPreviewDraft, isTrue);
    });

    test('publishes a draft and returns the public configuration', () async {
      await firestore.collection('public_config').doc('payment_info_audio').set(
        <String, dynamic>{
          'enabled': true,
          'audioUrl': 'https://cdn.example.test/published.mp3',
        },
      );
      final service = buildService();

      final config = await service.publishPaymentInfoAudioDraft();

      expect(calls.single.$1, 'publishPaymentInfoAudioDraft');
      expect(calls.single.$2, isEmpty);
      expect(config!.audioUrl, contains('published.mp3'));
    });

    test('legacy URL upload trims and persists the public config', () async {
      final service = buildService();
      await service.uploadAudioUrl('  https://cdn.example.test/manual.mp3  ');

      final data = (await firestore
              .collection('public_config')
              .doc('payment_info_audio')
              .get())
          .data()!;
      expect(data['enabled'], isTrue);
      expect(data['audioUrl'], 'https://cdn.example.test/manual.mp3');
      expect(data['contentType'], 'audio/mpeg');
      expect(data['provider'], 'manual_url');
      expect(data['version'], isA<int>());
      expect(data['generatedAt'], isA<Timestamp>());
    });

    test('legacy URL upload rejects blank URLs', () async {
      final service = buildService();
      await expectLater(
        service.uploadAudioUrl('   '),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('legacy byte upload uses injected storage and persists metadata', () async {
      String? uploadedPath;
      String? uploadedContentType;
      Uint8List? uploadedBytes;
      final service = buildService(
        uploader: ({required bytes, required path, required contentType}) async {
          uploadedBytes = bytes;
          uploadedPath = path;
          uploadedContentType = contentType;
          return 'https://cdn.example.test/uploaded.mp3';
        },
      );

      await service.uploadAudio(Uint8List.fromList(<int>[1, 2, 3]), 'voice.mp3');

      expect(uploadedBytes, Uint8List.fromList(<int>[1, 2, 3]));
      expect(uploadedPath, startsWith('payment_info_audio/'));
      expect(uploadedPath, endsWith('_voice.mp3'));
      expect(uploadedContentType, 'audio/mpeg');

      final data = (await firestore
              .collection('public_config')
              .doc('payment_info_audio')
              .get())
          .data()!;
      expect(data['audioUrl'], 'https://cdn.example.test/uploaded.mp3');
      expect(data['storagePath'], uploadedPath);
      expect(data['provider'], 'manual_upload');
    });

    test('legacy watchAudioUrl projects the configured URL', () async {
      final service = buildService();
      final urlFuture = service.watchAudioUrl().firstWhere((value) => value != null);

      await firestore.collection('public_config').doc('payment_info_audio').set(
        <String, dynamic>{
          'enabled': true,
          'audioUrl': 'https://cdn.example.test/watch.mp3',
        },
      );

      expect(await urlFuture, 'https://cdn.example.test/watch.mp3');
    });
  });
}

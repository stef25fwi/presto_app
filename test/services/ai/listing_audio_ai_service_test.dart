import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/config/env/openai_config.dart';
import 'package:presto_app/models/ai/listing_ai_request.dart';
import 'package:presto_app/services/ai/listing_audio_ai_service.dart';

void main() {
  group('ListingAudioAiService helpers', () {
    test('normalise les maps et refuse les payloads invalides', () {
      expect(
        ListingAudioAiService.asMapForTest(<String, dynamic>{'value': 1}),
        {'value': 1},
      );
      expect(
        ListingAudioAiService.asMapForTest(<Object?, Object?>{'value': 2}),
        {'value': 2},
      );
      expect(
        () => ListingAudioAiService.asMapForTest('payload invalide'),
        throwsA(isA<FormatException>()),
      );
    });

    test('classe les erreurs callable temporaires', () {
      expect(
        ListingAudioAiService.shouldRetryCallableForTest(
          TimeoutException('timeout'),
        ),
        isTrue,
      );

      for (final code in <String>[
        'unavailable',
        'deadline-exceeded',
        'internal',
        'resource-exhausted',
      ]) {
        expect(
          ListingAudioAiService.shouldRetryCallableForTest(
            FirebaseFunctionsException(code: code, message: 'temporaire'),
          ),
          isTrue,
          reason: code,
        );
      }

      expect(
        ListingAudioAiService.shouldRetryCallableForTest(
          FirebaseFunctionsException(
            code: 'permission-denied',
            message: 'refusé',
          ),
        ),
        isFalse,
      );
      expect(
        ListingAudioAiService.shouldRetryCallableForTest(
          StateError('définitif'),
        ),
        isFalse,
      );
    });

    test('classe les erreurs Storage transitoires et d authentification', () {
      expect(
        ListingAudioAiService.isRetryableStorageWriteErrorForTest(
          TimeoutException('timeout'),
        ),
        isTrue,
      );

      for (final code in <String>[
        'network-error',
        'retry-limit-exceeded',
        'unknown',
      ]) {
        expect(
          ListingAudioAiService.isRetryableStorageWriteErrorForTest(
            FirebaseException(
              plugin: 'firebase_storage',
              code: code,
              message: 'temporaire',
            ),
          ),
          isTrue,
          reason: code,
        );
      }

      for (final code in <String>[
        'unauthorized',
        'permission-denied',
        'unauthenticated',
      ]) {
        expect(
          ListingAudioAiService.isStorageAuthErrorForTest(
            FirebaseException(
              plugin: 'firebase_storage',
              code: code,
              message: 'auth',
            ),
          ),
          isTrue,
          reason: code,
        );
      }

      expect(
        ListingAudioAiService.isRetryableStorageWriteErrorForTest(
          FirebaseException(
            plugin: 'firebase_storage',
            code: 'object-not-found',
          ),
        ),
        isFalse,
      );
      expect(
        ListingAudioAiService.isStorageAuthErrorForTest(
          StateError('hors Firebase'),
        ),
        isFalse,
      );
    });
  });

  group('ListingAudioAiService upload', () {
    test('normalise et écrit un audio standard', () async {
      final preparations = <Map<String, bool>>[];
      final writes = <Map<String, Object>>[];
      final bytes = Uint8List.fromList(<int>[1, 2, 3]);
      final service = ListingAudioAiService(
        secureUploadPreparer: ({
          required bool forceRefreshToken,
          required bool forceRefreshAppCheckToken,
        }) async {
          preparations.add(<String, bool>{
            'token': forceRefreshToken,
            'appCheck': forceRefreshAppCheckToken,
          });
        },
        storageWriter: ({
          required String storagePath,
          required Uint8List audioBytes,
          required String contentType,
        }) async {
          writes.add(<String, Object>{
            'path': storagePath,
            'bytes': audioBytes,
            'contentType': contentType,
          });
        },
      );

      final path = await service.uploadAudioBytes(
        ownerUid: 'user-1',
        audioBytes: bytes,
        contentType: ' AUDIO/WEBM ',
        extension: '.WEBM',
      );

      expect(path, startsWith('stt/user-1_'));
      expect(path, endsWith('.webm'));
      expect(preparations, <Map<String, bool>>[
        <String, bool>{'token': false, 'appCheck': false},
      ]);
      expect(writes, hasLength(1));
      expect(writes.single['path'], path);
      expect(writes.single['bytes'], same(bytes));
      expect(writes.single['contentType'], 'audio/webm');
    });

    test('rafraîchit la sécurité après une erreur Storage d authentification',
        () async {
      final preparations = <Map<String, bool>>[];
      var writes = 0;
      final service = ListingAudioAiService(
        secureUploadPreparer: ({
          required bool forceRefreshToken,
          required bool forceRefreshAppCheckToken,
        }) async {
          preparations.add(<String, bool>{
            'token': forceRefreshToken,
            'appCheck': forceRefreshAppCheckToken,
          });
        },
        storageWriter: ({
          required String storagePath,
          required Uint8List audioBytes,
          required String contentType,
        }) async {
          writes += 1;
          if (writes == 1) {
            throw FirebaseException(
              plugin: 'firebase_storage',
              code: 'unauthorized',
              message: 'jeton expiré',
            );
          }
        },
      );

      final path = await service.uploadAudioBytes(
        ownerUid: 'user-2',
        audioBytes: Uint8List.fromList(<int>[4, 5]),
        contentType: 'audio/aac',
        extension: 'aac',
        storagePrefix: 'stt_streaming',
      );

      expect(path, startsWith('stt_streaming/user-2/'));
      expect(path, contains('_chunk.aac'));
      expect(writes, 2);
      expect(preparations, <Map<String, bool>>[
        <String, bool>{'token': false, 'appCheck': false},
        <String, bool>{'token': true, 'appCheck': true},
      ]);
    });

    test('refuse un type audio non autorisé avant toute écriture', () async {
      var preparations = 0;
      var writes = 0;
      final service = ListingAudioAiService(
        secureUploadPreparer: ({
          required bool forceRefreshToken,
          required bool forceRefreshAppCheckToken,
        }) async {
          preparations += 1;
        },
        storageWriter: ({
          required String storagePath,
          required Uint8List audioBytes,
          required String contentType,
        }) async {
          writes += 1;
        },
      );

      await expectLater(
        service.uploadAudioBytes(
          ownerUid: 'user-3',
          audioBytes: Uint8List(1),
          contentType: 'audio/mpeg',
          extension: 'mp3',
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(preparations, 0);
      expect(writes, 0);
    });
  });

  group('ListingAudioAiService callables', () {
    test('transcrit un audio envoyé et transmet la langue', () async {
      final calls = <Map<String, Object>>[];
      final service = ListingAudioAiService(
        callableInvoker: ({
          required String name,
          required Duration timeout,
          required Map<String, dynamic> parameters,
        }) async {
          calls.add(<String, Object>{
            'name': name,
            'timeout': timeout,
            'parameters': parameters,
          });
          return <String, dynamic>{
            'transcription': <String, dynamic>{
              'text': 'Je cherche une personne pour mon jardin.',
              'provider': 'openai',
              'languageCode': 'fr-FR',
              'storagePath': parameters['storagePath'],
              'confidence': 0.91,
            },
          };
        },
      );

      final result = await service.transcribeUploadedAudio(
        storagePath: 'stt/user/audio.webm',
        languageCode: 'fr-FR',
      );

      expect(result.text, 'Je cherche une personne pour mon jardin.');
      expect(result.confidence, 0.91);
      expect(calls.single['name'], OpenAiConfig.transcribeListingAudioCallable);
      expect(calls.single['timeout'], OpenAiConfig.audioTimeout);
      expect(calls.single['parameters'], <String, dynamic>{
        'storagePath': 'stt/user/audio.webm',
        'languageCode': 'fr-FR',
      });
    });

    test('extrait les champs et la transcription d une annonce', () async {
      final service = ListingAudioAiService(
        callableInvoker: ({
          required String name,
          required Duration timeout,
          required Map<String, dynamic> parameters,
        }) async {
          expect(name, OpenAiConfig.extractListingFieldsFromAudioCallable);
          expect(timeout, OpenAiConfig.audioTimeout);
          expect(parameters, containsPair('storagePath', 'stt/audio.aac'));
          expect(parameters, containsPair('city', 'Baie-Mahault'));
          return <String, dynamic>{
            'result': <String, dynamic>{
              'title': 'Tonte de jardin',
              'description': 'Recherche une personne pour tondre le jardin.',
              'category': 'Jardinage',
              'price': 45,
            },
            'transcription': <String, dynamic>{
              'text': 'Je cherche quelqu un pour tondre mon jardin.',
              'provider': 'openai',
              'languageCode': 'fr-FR',
            },
          };
        },
      );

      final result = await service.extractListingFieldsFromUploadedAudio(
        storagePath: 'stt/audio.aac',
        request: const ListingAiRequest(
          input: 'audio',
          city: 'Baie-Mahault',
          category: 'Jardinage',
        ),
      );

      expect(result.title, 'Tonte de jardin');
      expect(result.price, 45);
      expect(result.transcriptText, contains('tondre mon jardin'));
    });

    test('enchaîne upload et extraction depuis les octets', () async {
      String? uploadedPath;
      Map<String, dynamic>? callableParameters;
      final service = ListingAudioAiService(
        secureUploadPreparer: ({
          required bool forceRefreshToken,
          required bool forceRefreshAppCheckToken,
        }) async {},
        storageWriter: ({
          required String storagePath,
          required Uint8List audioBytes,
          required String contentType,
        }) async {
          uploadedPath = storagePath;
        },
        callableInvoker: ({
          required String name,
          required Duration timeout,
          required Map<String, dynamic> parameters,
        }) async {
          callableParameters = parameters;
          return <String, dynamic>{
            'result': <String, dynamic>{
              'title': 'Aide au déménagement',
              'description': 'Besoin d aide pour déplacer des cartons.',
            },
          };
        },
      );

      final result = await service.extractListingFieldsFromAudioBytes(
        ownerUid: 'user-4',
        audioBytes: Uint8List.fromList(<int>[7, 8, 9]),
        contentType: 'audio/x-m4a',
        extension: '.m4a',
        request: const ListingAiRequest(input: 'audio'),
      );

      expect(uploadedPath, isNotNull);
      expect(callableParameters?['storagePath'], uploadedPath);
      expect(result.title, 'Aide au déménagement');
    });

    test('refuse une réponse callable qui n est pas une map', () async {
      final service = ListingAudioAiService(
        callableInvoker: ({
          required String name,
          required Duration timeout,
          required Map<String, dynamic> parameters,
        }) async => 'réponse invalide',
      );

      await expectLater(
        service.transcribeUploadedAudio(storagePath: 'stt/invalide.webm'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

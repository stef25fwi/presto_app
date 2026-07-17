import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/marketplace_publish_service.dart';

void main() {
  group('métadonnées processOfferPhoto', () {
    test('convertit et normalise un payload complet', () {
      final media = MarketplacePublishService.parseProcessedOfferPhotoForTest(
        <String, dynamic>{
          'storagePath': ' processed/photo.webp ',
          'downloadUrl': ' https://cdn.example/photo.webp ',
          'thumbnailUrl': ' https://cdn.example/thumb.webp ',
          'width': 1280.9,
          'height': 720,
          'mimeType': ' image/webp ',
          'sizeBytes': 456789.8,
        },
      );

      expect(media.storagePath, 'processed/photo.webp');
      expect(media.downloadUrl, 'https://cdn.example/photo.webp');
      expect(media.thumbnailUrl, 'https://cdn.example/thumb.webp');
      expect(media.width, 1280);
      expect(media.height, 720);
      expect(media.mimeType, 'image/webp');
      expect(media.sizeBytes, 456789);
    });

    test('utilise downloadUrl quand thumbnailUrl est absent ou nul', () {
      for (final payload in <Map<String, dynamic>>[
        <String, dynamic>{
          'storagePath': 'processed/photo.jpg',
          'downloadUrl': 'https://cdn.example/photo.jpg',
        },
        <String, dynamic>{
          'storagePath': 'processed/photo.jpg',
          'downloadUrl': 'https://cdn.example/photo.jpg',
          'thumbnailUrl': null,
        },
      ]) {
        final media = MarketplacePublishService.parseProcessedOfferPhotoForTest(
          payload,
        );
        expect(media.thumbnailUrl, 'https://cdn.example/photo.jpg');
      }
    });

    test('ignore les dimensions, tailles et mime non exploitables', () {
      final media = MarketplacePublishService.parseProcessedOfferPhotoForTest(
        <String, dynamic>{
          'storagePath': 'processed/photo.jpg',
          'downloadUrl': 'https://cdn.example/photo.jpg',
          'thumbnailUrl': 'https://cdn.example/thumb.jpg',
          'width': '1280',
          'height': <String, dynamic>{'value': 720},
          'mimeType': '   ',
          'sizeBytes': '456789',
        },
      );

      expect(media.width, isNull);
      expect(media.height, isNull);
      expect(media.mimeType, isNull);
      expect(media.sizeBytes, isNull);
    });

    test('refuse les payloads incomplets ou vides', () {
      final invalidPayloads = <Map<String, dynamic>>[
        <String, dynamic>{
          'downloadUrl': 'https://cdn.example/photo.jpg',
          'thumbnailUrl': 'https://cdn.example/thumb.jpg',
        },
        <String, dynamic>{
          'storagePath': 'processed/photo.jpg',
          'thumbnailUrl': 'https://cdn.example/thumb.jpg',
        },
        <String, dynamic>{
          'storagePath': 'processed/photo.jpg',
          'downloadUrl': 'https://cdn.example/photo.jpg',
          'thumbnailUrl': '   ',
        },
        <String, dynamic>{
          'storagePath': '   ',
          'downloadUrl': '   ',
        },
      ];

      for (final payload in invalidPayloads) {
        expect(
          () => MarketplacePublishService.parseProcessedOfferPhotoForTest(
            payload,
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('métadonnées attendues'),
            ),
          ),
        );
      }
    });
  });

  group('formats de stockage photo', () {
    test('résout l extension depuis tous les MIME image supportés', () {
      const expected = <String, String>{
        'image/webp': 'webp',
        'image/avif': 'avif',
        'image/png': 'png',
        'image/heic': 'heic',
        'image/heif': 'heic',
        'image/gif': 'gif',
        'image/bmp': 'bmp',
        'image/tiff': 'tiff',
        'image/jpeg': 'jpg',
        'image/jpg': 'jpg',
      };

      for (final entry in expected.entries) {
        expect(
          MarketplacePublishService.resolveStorageExtensionForTest(
            path: '/tmp/photo.unknown',
            mimeType: ' ${entry.key.toUpperCase()} ',
          ),
          entry.value,
          reason: entry.key,
        );
      }
    });

    test('résout l extension depuis le chemin quand le MIME est absent', () {
      const expected = <String, String>{
        '/tmp/photo.WEBP': 'webp',
        '/tmp/photo.avif': 'avif',
        '/tmp/photo.png': 'png',
        '/tmp/photo.heic': 'heic',
        '/tmp/photo.heif': 'heic',
        '/tmp/photo.gif': 'gif',
        '/tmp/photo.bmp': 'bmp',
        '/tmp/photo.tif': 'tiff',
        '/tmp/photo.tiff': 'tiff',
        '/tmp/photo.jpeg': 'jpg',
        '/tmp/photo.jpg': 'jpg',
      };

      for (final entry in expected.entries) {
        expect(
          MarketplacePublishService.resolveStorageExtensionForTest(
            path: entry.key,
          ),
          entry.value,
          reason: entry.key,
        );
      }
    });

    test('utilise jpg pour un format inconnu', () {
      expect(
        MarketplacePublishService.resolveStorageExtensionForTest(
          path: '/tmp/photo.binary',
          mimeType: 'application/octet-stream',
        ),
        'jpg',
      );
    });

    test('conserve un MIME image valide après normalisation', () {
      expect(
        MarketplacePublishService.resolveStorageContentTypeForTest(
          path: '/tmp/photo.unknown',
          mimeType: ' IMAGE/WEBP ',
        ),
        'image/webp',
      );
    });

    test('déduit le type de contenu du chemin et replie vers JPEG', () {
      const expected = <String, String>{
        '/tmp/photo.webp': 'image/webp',
        '/tmp/photo.avif': 'image/avif',
        '/tmp/photo.png': 'image/png',
        '/tmp/photo.heif': 'image/heic',
        '/tmp/photo.gif': 'image/gif',
        '/tmp/photo.bmp': 'image/bmp',
        '/tmp/photo.tiff': 'image/tiff',
        '/tmp/photo.jpg': 'image/jpeg',
        '/tmp/photo.unknown': 'image/jpeg',
      };

      for (final entry in expected.entries) {
        expect(
          MarketplacePublishService.resolveStorageContentTypeForTest(
            path: entry.key,
            mimeType: 'application/octet-stream',
          ),
          entry.value,
          reason: entry.key,
        );
      }
    });
  });
}

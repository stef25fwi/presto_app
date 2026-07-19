import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/marketplace_publish_service.dart';

void main() {
  group('MarketplacePublishService media helpers', () {
    test('construit un chemin brut déterministe et sûr', () {
      final path = MarketplacePublishService.buildRawPhotoStoragePathForTest(
        uid: 'user-42',
        draftId: 'draft-7',
        index: 3,
        extension: 'png',
        timestampMs: 123456,
      );

      expect(path, contains('user-42'));
      expect(path, contains('draft-7'));
      expect(path, endsWith('123456_3.png'));
    });

    test('normalise toutes les métadonnées de photo traitée', () {
      final media = MarketplacePublishService.parseProcessedOfferPhotoForTest(
        <String, dynamic>{
          'storagePath': 'offers/user/photo.webp',
          'downloadUrl': 'https://cdn.test/photo.webp',
          'thumbnailUrl': 'https://cdn.test/thumb.webp',
          'width': 1200.8,
          'height': 800,
          'mimeType': ' image/webp ',
          'sizeBytes': 4567.9,
        },
      );

      expect(media.storagePath, 'offers/user/photo.webp');
      expect(media.downloadUrl, 'https://cdn.test/photo.webp');
      expect(media.thumbnailUrl, 'https://cdn.test/thumb.webp');
      expect(media.width, 1200);
      expect(media.height, 800);
      expect(media.mimeType, 'image/webp');
      expect(media.sizeBytes, 4567);
    });

    test('utilise l URL complète comme miniature et accepte les options absentes',
        () {
      final media = MarketplacePublishService.parseProcessedOfferPhotoForTest(
        <String, dynamic>{
          'storagePath': 'offers/user/photo.jpg',
          'downloadUrl': 'https://cdn.test/photo.jpg',
          'mimeType': '   ',
          'width': 'invalide',
          'height': null,
          'sizeBytes': false,
        },
      );

      expect(media.thumbnailUrl, media.downloadUrl);
      expect(media.width, isNull);
      expect(media.height, isNull);
      expect(media.mimeType, isNull);
      expect(media.sizeBytes, isNull);
    });

    test('refuse les réponses de traitement photo incomplètes', () {
      for (final payload in <Map<String, dynamic>>[
        <String, dynamic>{
          'downloadUrl': 'https://cdn.test/photo.jpg',
          'thumbnailUrl': 'https://cdn.test/thumb.jpg',
        },
        <String, dynamic>{
          'storagePath': 'offers/photo.jpg',
          'thumbnailUrl': 'https://cdn.test/thumb.jpg',
        },
        <String, dynamic>{
          'storagePath': 'offers/photo.jpg',
          'downloadUrl': '   ',
        },
      ]) {
        expect(
          () => MarketplacePublishService.parseProcessedOfferPhotoForTest(
            payload,
          ),
          throwsA(isA<StateError>()),
        );
      }
    });

    test('déduit les extensions depuis chaque type MIME image supporté', () {
      const cases = <String, String>{
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

      for (final entry in cases.entries) {
        expect(
          MarketplacePublishService.resolveStorageExtensionForTest(
            path: 'photo.bin',
            mimeType: ' ${entry.key.toUpperCase()} ',
          ),
          entry.value,
        );
      }
    });

    test('déduit les extensions depuis les noms de fichiers et replie sur jpg',
        () {
      const cases = <String, String>{
        'photo.WEBP': 'webp',
        'photo.AVIF': 'avif',
        'photo.PNG': 'png',
        'photo.HEIC': 'heic',
        'photo.HEIF': 'heic',
        'photo.GIF': 'gif',
        'photo.BMP': 'bmp',
        'photo.TIF': 'tiff',
        'photo.TIFF': 'tiff',
        'photo.JPEG': 'jpg',
        'photo.JPG': 'jpg',
        'photo.sans-extension': 'jpg',
      };

      for (final entry in cases.entries) {
        expect(
          MarketplacePublishService.resolveStorageExtensionForTest(
            path: entry.key,
          ),
          entry.value,
        );
      }
    });

    test('conserve un MIME image explicite', () {
      expect(
        MarketplacePublishService.resolveStorageContentTypeForTest(
          path: 'photo.bin',
          mimeType: ' IMAGE/WEBP ',
        ),
        'image/webp',
      );
    });

    test('déduit chaque content type depuis l extension', () {
      const cases = <String, String>{
        'photo.webp': 'image/webp',
        'photo.avif': 'image/avif',
        'photo.png': 'image/png',
        'photo.heic': 'image/heic',
        'photo.gif': 'image/gif',
        'photo.bmp': 'image/bmp',
        'photo.tiff': 'image/tiff',
        'photo.jpg': 'image/jpeg',
        'photo.unknown': 'image/jpeg',
      };

      for (final entry in cases.entries) {
        expect(
          MarketplacePublishService.resolveStorageContentTypeForTest(
            path: entry.key,
            mimeType: 'application/octet-stream',
          ),
          entry.value,
        );
      }
    });
  });
}

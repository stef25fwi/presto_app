import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/marketplace_publish_service.dart';

void main() {
  group('MarketplacePublishService formats photo', () {
    const mimeCases = <String, String>{
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

    for (final entry in mimeCases.entries) {
      test('déduit ${entry.value} depuis ${entry.key}', () {
        expect(
          MarketplacePublishService.resolveStorageExtensionForTest(
            path: '/tmp/photo.bin',
            mimeType: entry.key,
          ),
          entry.value,
        );
        expect(
          MarketplacePublishService.resolveStorageContentTypeForTest(
            path: '/tmp/photo.bin',
            mimeType: entry.key,
          ),
          entry.key.toLowerCase(),
        );
      });
    }

    const pathCases = <String, String>{
      'photo.webp': 'webp',
      'photo.avif': 'avif',
      'photo.png': 'png',
      'photo.heic': 'heic',
      'photo.heif': 'heic',
      'photo.gif': 'gif',
      'photo.bmp': 'bmp',
      'photo.tif': 'tiff',
      'photo.tiff': 'tiff',
      'photo.jpeg': 'jpg',
      'photo.jpg': 'jpg',
      'photo.sans-extension': 'jpg',
    };

    for (final entry in pathCases.entries) {
      test('déduit ${entry.value} depuis ${entry.key}', () {
        expect(
          MarketplacePublishService.resolveStorageExtensionForTest(
            path: '/tmp/${entry.key}',
          ),
          entry.value,
        );
      });
    }

    test('normalise le type MIME avant de le conserver', () {
      expect(
        MarketplacePublishService.resolveStorageContentTypeForTest(
          path: '/tmp/photo.bin',
          mimeType: ' IMAGE/PNG ',
        ),
        'image/png',
      );
    });

    test('déduit le type MIME depuis le chemin sans MIME image', () {
      const cases = <String, String>{
        'photo.webp': 'image/webp',
        'photo.avif': 'image/avif',
        'photo.png': 'image/png',
        'photo.heic': 'image/heic',
        'photo.gif': 'image/gif',
        'photo.bmp': 'image/bmp',
        'photo.tiff': 'image/tiff',
        'photo.jpg': 'image/jpeg',
      };

      for (final entry in cases.entries) {
        expect(
          MarketplacePublishService.resolveStorageContentTypeForTest(
            path: '/tmp/${entry.key}',
            mimeType: 'application/octet-stream',
          ),
          entry.value,
        );
      }
    });
  });

  group('MarketplacePublishService métadonnées photo traitée', () {
    test('refuse les métadonnées obligatoires absentes', () {
      expect(
        () => MarketplacePublishService.parseProcessedOfferPhotoForTest(
          const <String, dynamic>{},
        ),
        throwsStateError,
      );
      expect(
        () => MarketplacePublishService.parseProcessedOfferPhotoForTest(
          const <String, dynamic>{
            'storagePath': 'listings/raw/photo.jpg',
            'downloadUrl': 'https://example.test/photo.jpg',
            'thumbnailUrl': '',
          },
        ),
        throwsStateError,
      );
    });

    test('accepte le téléchargement comme miniature de secours', () {
      final media = MarketplacePublishService.parseProcessedOfferPhotoForTest(
        const <String, dynamic>{
          'storagePath': 'listings/processed/photo.webp',
          'downloadUrl': 'https://example.test/photo.webp',
          'width': 1200.9,
          'height': 800,
          'mimeType': 'image/webp',
          'sizeBytes': 2048.7,
        },
      );

      expect(media.storagePath, 'listings/processed/photo.webp');
      expect(media.downloadUrl, 'https://example.test/photo.webp');
      expect(media.thumbnailUrl, 'https://example.test/photo.webp');
      expect(media.width, 1200);
      expect(media.height, 800);
      expect(media.mimeType, 'image/webp');
      expect(media.sizeBytes, 2048);
    });

    test('normalise les métadonnées optionnelles invalides', () {
      final media = MarketplacePublishService.parseProcessedOfferPhotoForTest(
        const <String, dynamic>{
          'storagePath': ' listings/processed/photo.jpg ',
          'downloadUrl': ' https://example.test/photo.jpg ',
          'thumbnailUrl': ' https://example.test/thumb.jpg ',
          'width': '1200',
          'height': null,
          'mimeType': '   ',
          'sizeBytes': '2048',
        },
      );

      expect(media.storagePath, 'listings/processed/photo.jpg');
      expect(media.downloadUrl, 'https://example.test/photo.jpg');
      expect(media.thumbnailUrl, 'https://example.test/thumb.jpg');
      expect(media.width, isNull);
      expect(media.height, isNull);
      expect(media.mimeType, isNull);
      expect(media.sizeBytes, isNull);
    });
  });

  test('construit un chemin raw canonique et déterministe', () {
    expect(
      MarketplacePublishService.buildRawPhotoStoragePathForTest(
        uid: 'user-1',
        draftId: 'draft-1',
        index: 2,
        extension: 'webp',
        timestampMs: 123456,
      ),
      'listingDrafts/user-1/draft-1/123456_2.webp',
    );
  });
}

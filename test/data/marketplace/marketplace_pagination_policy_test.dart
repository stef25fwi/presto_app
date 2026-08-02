import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/data/marketplace/favorite_repository.dart';
import 'package:presto_app/data/marketplace/listing_repository.dart';

void main() {
  group('marketplace pagination budgets', () {
    test('listing pages remain between 1 and 100', () {
      expect(normalizePublicListingsPageSize(-1), 1);
      expect(normalizePublicListingsPageSize(20), 20);
      expect(normalizePublicListingsPageSize(500), 100);
    });
    test('favorite pages remain between 1 and 50', () {
      expect(normalizeFavoritePageSize(0), 1);
      expect(normalizeFavoritePageSize(20), 20);
      expect(normalizeFavoritePageSize(500), 50);
    });
    test('first public page cache key is normalized and stable', () {
      expect(
        publicListingsFirstPageCacheKey(
          categoryId: ' Jardinage ',
          cityId: '97122_Baie-Mahault',
          limit: 500,
        ),
        'jardinage|97122_baie-mahault|100',
      );
    });
  });
}

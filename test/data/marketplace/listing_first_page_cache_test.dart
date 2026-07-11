import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/data/marketplace/listing_repository.dart';

void main() {
  test('la clé du cache normalise filtres et taille de page', () {
    expect(
      publicListingsFirstPageCacheKey(
        categoryId: '  JARDINAGE ',
        cityId: ' 971_LES_ABYMES ',
        limit: 500,
      ),
      'jardinage|971_les_abymes|100',
    );
    expect(
      publicListingsFirstPageCacheKey(
        categoryId: 'jardinage',
        cityId: '971_les_abymes',
        limit: 100,
      ),
      'jardinage|971_les_abymes|100',
    );
  });

  test('la clé distingue les filtres et les tailles de page', () {
    final base = publicListingsFirstPageCacheKey(
      categoryId: 'bricolage',
      cityId: '971_baie_mahaut',
      limit: 20,
    );
    expect(
      publicListingsFirstPageCacheKey(
        categoryId: 'jardinage',
        cityId: '971_baie_mahaut',
        limit: 20,
      ),
      isNot(base),
    );
    expect(
      publicListingsFirstPageCacheKey(
        categoryId: 'bricolage',
        cityId: '971_baie_mahaut',
        limit: 40,
      ),
      isNot(base),
    );
  });
}

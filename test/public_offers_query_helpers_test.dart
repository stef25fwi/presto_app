import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/public_offers_query_helpers.dart';

void main() {
  group('pickPublicListingsBrowseFilterField', () {
    test('prefers cityCategoryKey when both city and category are available',
        () {
      expect(
        pickPublicListingsBrowseFilterField(
          categoryId: 'bricolage-travaux',
          cityId: '97139_les-abymes',
        ),
        PublicListingsBrowseFilterField.cityCategoryKey,
      );
    });

    test('prefers city filter when both city and category are available', () {
      expect(
        pickPublicListingsBrowseFilterField(
          cityId: '97139_les-abymes',
        ),
        PublicListingsBrowseFilterField.cityId,
      );
    });

    test('uses category filter when only category is available', () {
      expect(
        pickPublicListingsBrowseFilterField(categoryId: 'jardinage'),
        PublicListingsBrowseFilterField.categoryId,
      );
    });

    test('returns none when no usable server-side filter exists', () {
      expect(
        pickPublicListingsBrowseFilterField(categoryId: '  ', cityId: null),
        PublicListingsBrowseFilterField.none,
      );
    });
  });
}

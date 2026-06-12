import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/location_text_normalizer.dart';

void main() {
  group('normalizeLocationLookupKey', () {
    test('normalise Petit-Bourg écrit de plusieurs façons', () {
      const expected = 'petitbourg';

      expect(normalizeLocationLookupKey('Petit-Bourg'), expected);
      expect(normalizeLocationLookupKey('petit-bourg'), expected);
      expect(normalizeLocationLookupKey('Petit Bourg'), expected);
      expect(normalizeLocationLookupKey('Petitbourg'), expected);
      expect(normalizeLocationLookupKey('petitbourg'), expected);
      expect(normalizeLocationLookupKey('PETIT-BOURG'), expected);
    });

    test('normalise accents et apostrophes', () {
      expect(normalizeLocationLookupKey("L'Étang-Salé"), 'letangsale');
      expect(normalizeLocationLookupKey('Saint-François'), 'saintfrancois');
      expect(normalizeLocationLookupKey('Capesterre-Belle-Eau'),
          'capesterrebelleeau');
    });
  });

  group('normalizeLocationSearchText', () {
    test('garde un texte lisible pour recherche', () {
      expect(normalizeLocationSearchText('Petit-Bourg'), 'petit bourg');
      expect(normalizeLocationSearchText("L'Étang-Salé"), 'l etang sale');
    });
  });
}

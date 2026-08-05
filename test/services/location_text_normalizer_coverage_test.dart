import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/location_text_normalizer.dart';

void main() {
  group('normalizeLocationLookupKey', () {
    test('normalise accents, ligatures, apostrophes, tirets et espaces', () {
      expect(
        normalizeLocationLookupKey("  L’Haÿ-les-Roses  "),
        'lhaylesroses',
      );
      expect(normalizeLocationLookupKey('Cœur-de-Ville'), 'coeurdeville');
      expect(normalizeLocationLookupKey('Ærø 123'), 'aer123');
    });

    test('couvre toutes les familles de caractères accentués', () {
      expect(
        normalizeLocationLookupKey(
          'ÀÂÄÁÃÅ Ç ÉÈÊË ÍÌÎÏ Ñ ÓÒÔÖÕ ÚÙÛÜ ÝŸ',
        ),
        'aaaaaaceeeeiiiinooooouuuuyy',
      );
    });

    test('supprime les caractères non alphanumériques', () {
      expect(normalizeLocationLookupKey('Pointe-à-Pitre #97110!'), 'pointeapitre97110');
      expect(normalizeLocationLookupKey(''), isEmpty);
      expect(normalizeLocationLookupKey('   '), isEmpty);
    });
  });

  group('normalizeLocationSearchText', () {
    test('préserve les mots et consolide les séparateurs', () {
      expect(
        normalizeLocationSearchText("  L’Haÿ-les_Roses  "),
        'l hay les roses',
      );
      expect(
        normalizeLocationSearchText('Saint---François___Guadeloupe'),
        'saint francois guadeloupe',
      );
    });

    test('normalise accents et ligatures en texte de recherche', () {
      expect(
        normalizeLocationSearchText('Cœur d’Ærø à Noël'),
        'coeur d aero a noel',
      );
      expect(
        normalizeLocationSearchText(
          'ÀÂÄÁÃÅ Ç ÉÈÊË ÍÌÎÏ Ñ ÓÒÔÖÕ ÚÙÛÜ ÝŸ',
        ),
        'aaaaaa c eeee iiii n ooooo uuuu yy',
      );
    });

    test('remplace ponctuation et symboles par des espaces simples', () {
      expect(
        normalizeLocationSearchText('Baie-Mahault, Guadeloupe / France!'),
        'baie mahault guadeloupe france',
      );
      expect(normalizeLocationSearchText('  '), isEmpty);
    });
  });
}

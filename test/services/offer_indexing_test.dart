import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/offer_indexing.dart';

void main() {
  group('offerSlugify et normalizeOfferText', () {
    test('normalisent accents, apostrophes et espaces', () {
      expect(offerSlugify("  Main-d'œuvre / Été  "), 'main-d-oeuvre-ete');
      expect(normalizeOfferText("  Aide à  domicile  "), 'aide a domicile');
    });
  });

  group('canonicalizeOfferCategory', () {
    test('gère valeurs vides, alias et correspondances partielles', () {
      expect(canonicalizeOfferCategory(null), isNull);
      expect(canonicalizeOfferCategory('   '), isNull);
      expect(canonicalizeOfferCategory('ménage'), 'Aide à domicile');
      expect(canonicalizeOfferCategory('DJ'), 'Événementiel / DJ');
      expect(canonicalizeOfferCategory('jardin'), 'Jardinage');
      expect(canonicalizeOfferCategory('catégorie inconnue'), 'catégorie inconnue');
    });

    test('privilégie une catégorie dont le libellé contient la saisie', () {
      expect(canonicalizeOfferCategory('peint'), 'Peinture');
      expect(canonicalizeOfferCategory('cours & soutien scolaire'), 'Cours & soutien');
    });
  });

  group('resolveOfferCategoryId', () {
    test('résout les ids connus et génère un slug de secours', () {
      expect(resolveOfferCategoryId(null), isNull);
      expect(resolveOfferCategoryId('bricolage'), 'bricolage-travaux');
      expect(resolveOfferCategoryId("Main-d'œuvre"), 'main-d-oeuvre');
      expect(resolveOfferCategoryId('Service très spécial'), 'service-tres-special');
    });
  });

  group('departmentFromPostalCode', () {
    test('gère métropole, DOM, collectivités et valeurs courtes', () {
      expect(departmentFromPostalCode(null), isNull);
      expect(departmentFromPostalCode('7'), isNull);
      expect(departmentFromPostalCode('75001'), '75');
      expect(departmentFromPostalCode('97122'), '971');
      expect(departmentFromPostalCode('98800'), '988');
    });
  });

  group('budgetValueFromDynamic', () {
    test('convertit nombres et textes monétaires', () {
      expect(budgetValueFromDynamic(null), isNull);
      expect(budgetValueFromDynamic(25), 25.0);
      expect(budgetValueFromDynamic(' 1 234,50 € '), 1234.5);
      expect(budgetValueFromDynamic('   '), isNull);
      expect(budgetValueFromDynamic('indéfini'), isNull);
    });
  });

  group('buildOfferIndexFields', () {
    test('construit les champs actifs et les clés de recherche', () {
      final fields = buildOfferIndexFields(
        category: 'ménage',
        city: ' Baie-Mahault ',
        postalCode: '97122',
        budget: '45,50 €',
        status: 'active',
      );

      expect(fields['category'], 'Aide à domicile');
      expect(fields['categoryId'], 'aide-a-domicile');
      expect(fields['city'], 'Baie-Mahault');
      expect(fields['location'], 'Baie-Mahault');
      expect(fields['cp'], '97122');
      expect(fields['postalCode'], '97122');
      expect(fields['cityId'], '97122_baie-mahault');
      expect(
        fields['cityCategoryKey'],
        '97122_baie-mahault_aide-a-domicile',
      );
      expect(fields['dept'], '971');
      expect(fields['budgetValue'], 45.5);
      expect(fields['isActive'], isTrue);
      expect(fields['isPublished'], isTrue);
      expect(fields['status'], 'active');
      expect(fields['visibility'], <String, bool>{'isPublic': true});
    });

    test('applique les fallbacks et respecte isActive explicite', () {
      final fields = buildOfferIndexFields(
        category: null,
        city: ' ',
        postalCode: ' ',
        budget: 'inconnu',
        status: 'draft',
        isActive: false,
      );

      expect(fields['category'], 'Autre');
      expect(fields['categoryId'], 'autre');
      expect(fields['city'], isEmpty);
      expect(fields['cp'], isNull);
      expect(fields['postalCode'], isNull);
      expect(fields['cityId'], isNull);
      expect(fields['cityCategoryKey'], isNull);
      expect(fields['dept'], isNull);
      expect(fields['budgetValue'], isNull);
      expect(fields['isActive'], isFalse);
      expect(fields['isPublished'], isFalse);
      expect(fields['status'], 'draft');
      expect(fields['visibility'], <String, bool>{'isPublic': false});
    });
  });
}

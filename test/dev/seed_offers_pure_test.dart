import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/dev/seed_offers.dart';

void main() {
  test('la collection cible reste offers', () {
    expect(kOffersCollection, 'offers');
  });

  group('normalize', () {
    test('normalise casse, ponctuation et séparateurs', () {
      expect(
        normalize("  Baie-Mahault / L’Habitation 97122! "),
        'baiemahaultlhabitation97122',
      );
    });

    test('préserve les lettres Unicode et supprime les apostrophes', () {
      expect(normalize("École d'été à Sainte-Anne"), 'écoledétéàsainteanne');
    });

    test('gère une valeur vide', () {
      expect(normalize(''), isEmpty);
    });
  });

  group('deptFromCp', () {
    test('déduit les départements ultramarins sur trois chiffres', () {
      expect(deptFromCp('97122'), '971');
      expect(deptFromCp('98714'), '987');
    });

    test('applique le repli Corse documenté', () {
      expect(deptFromCp('20000'), '2A');
    });

    test('déduit les départements métropolitains sur deux chiffres', () {
      expect(deptFromCp('75015'), '75');
      expect(deptFromCp('69008'), '69');
    });
  });

  test('seedMessagingOffers refuse un identifiant utilisateur vide', () async {
    await expectLater(
      seedMessagingOffers(userId: '   '),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.message,
          'message',
          'userId ne doit pas être vide',
        ),
      ),
    );
  });
}

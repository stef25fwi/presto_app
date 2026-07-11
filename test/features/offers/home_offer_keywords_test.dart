import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/offers/home_offer_keywords.dart';

void main() {
  test('dérive, déduplique et trie les mots-clés des offres', () {
    final keywords = buildHomeOfferKeywords(<Map<String, dynamic>>[
      <String, dynamic>{
        'title': 'Jardinage urgent',
        'description': 'Besoin jardinage et débroussaillage.',
      },
      <String, dynamic>{
        'title': 'Peinture maison',
        'description': 'Peinture intérieure urgente',
      },
    ]);

    expect(
      keywords,
      <String>[
        'besoin',
        'débroussaillage',
        'intérieure',
        'jardinage',
        'maison',
        'peinture',
        'urgent',
        'urgente',
      ],
    );
  });

  test('ignore les mots courts et les valeurs numériques', () {
    expect(
      buildHomeOfferKeywords(<Map<String, dynamic>>[
        <String, dynamic>{
          'title': 'DJ 2026',
          'description': 'job 24h serveur',
        },
      ]),
      <String>['serveur'],
    );
  });

  test('borne le nombre de suggestions', () {
    expect(
      buildHomeOfferKeywords(
        <Map<String, dynamic>>[
          <String, dynamic>{'title': 'alpha bravo charlie delta echo'},
        ],
        maximumKeywords: 3,
      ),
      <String>['alpha', 'bravo', 'charlie'],
    );
  });

  test('refuse des limites invalides', () {
    expect(
      () => buildHomeOfferKeywords(const <Map<String, dynamic>>[], minimumLength: 0),
      throwsArgumentError,
    );
    expect(
      () => buildHomeOfferKeywords(const <Map<String, dynamic>>[], maximumKeywords: 0),
      throwsArgumentError,
    );
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('OfferDetailsPage n ecrit plus dans la sous-collection legacy favoriteOffers', () async {
    final source = await File(
      'lib/pages/offers/offer_details_page.dart',
    ).readAsString();

    expect(source.contains("collection('favoriteOffers')"), isFalse);
    expect(source.contains('collection("favoriteOffers")'), isFalse);
  });

  test('UserOffersSection ne lit plus directement la sous-collection legacy favoriteOffers', () async {
    final source = await File(
      'lib/pages/user_offers_section.dart',
    ).readAsString();

    expect(source.contains("collection('favoriteOffers')"), isFalse);
    expect(source.contains('collection("favoriteOffers")'), isFalse);
  });
}
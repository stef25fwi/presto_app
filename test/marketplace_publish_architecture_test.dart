import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/marketplace_publish_service.dart';

void main() {
  test(
      'MarketplacePublishService construit le path raw canonique listingDrafts',
      () {
    final path = MarketplacePublishService.buildRawPhotoStoragePathForTest(
      uid: 'user_1',
      draftId: 'draft_42',
      index: 1,
      extension: 'jpg',
      timestampMs: 1234567890,
    );

    expect(path, 'listingDrafts/user_1/draft_42/1234567890_1.jpg');
  });

  test('PublishOfferPage ne contient plus les anciens symboles upload legacy',
      () async {
    final source = await File(
      'lib/pages/publish_offer_page.dart',
    ).readAsString();

    expect(source.contains('_uploadedPhotoUrls'), isFalse);
    expect(source.contains('Future<List<Map<String, dynamic>>> _uploadPhotos'),
        isFalse);
  });

  test('ConsultOffersPage n ecrit plus directement dans listings ou offers',
      () async {
    final source = await File(
      'lib/pages/consult_offers_page.dart',
    ).readAsString();

    expect(source.contains('await targetRef.update({'), isFalse);
    expect(
      source.contains(
          ".collection(kOffersCollection)\n            .doc(offerId)\n            .delete();"),
      isFalse,
    );
  });

  test('Les pages compte et consultation ne lisent plus offers directement',
      () async {
    final consultSource = await File(
      'lib/pages/consult_offers_page.dart',
    ).readAsString();
    final accountSource = await File(
      'lib/pages/user_offers_section.dart',
    ).readAsString();

    expect(consultSource.contains('.collection(kOffersCollection)'), isFalse);
    expect(accountSource.contains('.collection(kOffersCollection)'), isFalse);
  });
}

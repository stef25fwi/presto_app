import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/core/firebase_contract.dart';

void main() {
  test('construit les chemins Storage canoniques', () {
    expect(
      StoragePaths.listingDraftRaw(
        uid: 'user-1',
        draftId: 'draft-2',
        fileName: 'photo.jpg',
      ),
      'listingDrafts/user-1/draft-2/photo.jpg',
    );
    expect(
      StoragePaths.listingFinal(
        uid: 'user-1',
        listingId: 'listing-3',
        fileName: 'final.webp',
      ),
      'listings/user-1/listing-3/final.webp',
    );
  });
}

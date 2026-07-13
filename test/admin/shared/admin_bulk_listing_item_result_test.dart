import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/admin/shared/admin_bulk_listing_service.dart';

void main() {
  test('conserve le message détaillé d un échec de suppression', () {
    final result = AdminBulkListingDeleteItemResult.fromData(
      <String, Object?>{
        'listingId': 'listing-1',
        'ok': false,
        'errorCode': 'permission-denied',
        'errorMessage': 'Suppression refusée',
      },
    );

    expect(result.listingId, 'listing-1');
    expect(result.ok, isFalse);
    expect(result.errorCode, 'permission-denied');
    expect(result.errorMessage, 'Suppression refusée');
  });
}

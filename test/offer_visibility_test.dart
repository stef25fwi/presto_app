import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/utils/offer_helpers.dart';

void main() {
  group('isPublishedOfferData', () {
    test('active + public string visibility → true', () {
      expect(
        isPublishedOfferData({'status': 'active', 'visibility': 'public'}),
        isTrue,
      );
    });

    test('published status → true', () {
      expect(isPublishedOfferData({'status': 'published'}), isTrue);
    });

    test('isPublished flag → true', () {
      expect(isPublishedOfferData({'isPublished': true}), isTrue);
    });

    test('isActive flag → true', () {
      expect(isPublishedOfferData({'isActive': true}), isTrue);
    });

    test('visibility.isPublic map → true', () {
      expect(
        isPublishedOfferData({
          'visibility': {'isPublic': true},
        }),
        isTrue,
      );
    });

    test('active status alone → true', () {
      expect(isPublishedOfferData({'status': 'active'}), isTrue);
    });

    test('draft status → false', () {
      expect(isPublishedOfferData({'status': 'draft'}), isFalse);
    });

    test('pending status → false', () {
      expect(isPublishedOfferData({'status': 'pending'}), isFalse);
    });

    test('empty data → false', () {
      expect(isPublishedOfferData({}), isFalse);
    });

    test('archived status → false even with isPublished', () {
      expect(
        isPublishedOfferData({'status': 'archived', 'isPublished': true}),
        isFalse,
      );
    });

    test('deleted status → false even with isActive', () {
      expect(
        isPublishedOfferData({'status': 'deleted', 'isActive': true}),
        isFalse,
      );
    });

    test('sold status → false', () {
      expect(isPublishedOfferData({'status': 'sold'}), isFalse);
    });

    test('deletedAt present → false even with active status', () {
      expect(
        isPublishedOfferData({
          'status': 'active',
          'visibility': 'public',
          'deletedAt': '2026-01-01',
        }),
        isFalse,
      );
    });

    test('archivedAt present → false', () {
      expect(
        isPublishedOfferData({
          'status': 'published',
          'archivedAt': '2026-01-01',
        }),
        isFalse,
      );
    });
  });

  group('isOfferArchivedLike', () {
    test('archived status → true', () {
      expect(isOfferArchivedLike({'status': 'archived'}), isTrue);
    });

    test('archivé status (accented) → true', () {
      expect(isOfferArchivedLike({'status': 'archivé'}), isTrue);
    });

    test('deleted status → true', () {
      expect(isOfferArchivedLike({'status': 'deleted'}), isTrue);
    });

    test('removed status → true', () {
      expect(isOfferArchivedLike({'status': 'removed'}), isTrue);
    });

    test('sold status → true', () {
      expect(isOfferArchivedLike({'status': 'sold'}), isTrue);
    });

    test('archivedAt field → true', () {
      expect(isOfferArchivedLike({'archivedAt': '2026-01-01'}), isTrue);
    });

    test('deletedAt field → true', () {
      expect(isOfferArchivedLike({'deletedAt': '2026-01-01'}), isTrue);
    });

    test('active status → false', () {
      expect(isOfferArchivedLike({'status': 'active'}), isFalse);
    });

    test('empty data → false', () {
      expect(isOfferArchivedLike({}), isFalse);
    });
  });
}

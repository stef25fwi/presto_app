import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/admin/shared/admin_bulk_listing_service.dart';

void main() {
  test('normalise la sélection et parse un succès partiel', () async {
    Map<String, Object?>? sentPayload;
    final service = AdminBulkListingService(
      caller: (payload) async {
        sentPayload = payload;
        return <String, Object?>{
          'ok': false,
          'adminActionId': 'action-1',
          'requestedCount': 2,
          'succeededCount': 1,
          'failedCount': 1,
          'results': <Object?>[
            <String, Object?>{'listingId': 'a', 'ok': true},
            <String, Object?>{
              'listingId': 'b',
              'ok': false,
              'errorCode': 'not-found',
              'errorMessage': 'Listing not found',
            },
          ],
        };
      },
    );

    final summary = await service.deleteListings(
      listingIds: <String>[' a ', 'b', 'a', ''],
      reason: ' contenu interdit ',
    );

    expect(sentPayload, <String, Object?>{
      'listingIds': <String>['a', 'b'],
      'reason': 'contenu interdit',
    });
    expect(summary.ok, isFalse);
    expect(summary.adminActionId, 'action-1');
    expect(summary.succeededIds, <String>['a']);
    expect(summary.failures.single.listingId, 'b');
    expect(summary.failures.single.errorCode, 'not-found');
  });

  test('calcule les compteurs absents à partir des résultats', () {
    final summary = AdminBulkListingDeleteSummary.fromData(
      <String, Object?>{
        'ok': true,
        'adminActionId': 'action-2',
        'results': <Object?>[
          <String, Object?>{'listingId': 'a', 'ok': true},
          <String, Object?>{'listingId': 'b', 'ok': true},
        ],
      },
    );

    expect(summary.requestedCount, 2);
    expect(summary.succeededCount, 2);
    expect(summary.failedCount, 0);
  });

  test('refuse une sélection vide, trop grande ou sans motif', () async {
    final service = AdminBulkListingService(
      caller: (_) async => throw StateError('ne doit pas être appelé'),
    );

    await expectLater(
      service.deleteListings(listingIds: const <String>[], reason: 'motif'),
      throwsArgumentError,
    );
    await expectLater(
      service.deleteListings(
        listingIds: List<String>.generate(51, (index) => 'id-$index'),
        reason: 'motif',
      ),
      throwsArgumentError,
    );
    await expectLater(
      service.deleteListings(listingIds: const <String>['a'], reason: '  '),
      throwsArgumentError,
    );
  });

  test('refuse une réponse backend incohérente', () {
    expect(
      () => AdminBulkListingDeleteSummary.fromData(
        <String, Object?>{
          'ok': true,
          'requestedCount': 2,
          'succeededCount': 2,
          'failedCount': 0,
          'results': <Object?>[
            <String, Object?>{'listingId': 'a', 'ok': true},
          ],
        },
      ),
      throwsFormatException,
    );
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/admin/listings/admin_listing_record.dart';
import 'package:presto_app/admin/listings/admin_listings_management_page.dart';
import 'package:presto_app/admin/listings/admin_listings_repository.dart';
import 'package:presto_app/admin/shared/admin_bulk_listing_service.dart';

class _FakeAdminListingsRepository implements AdminListingsRepository {
  _FakeAdminListingsRepository(this.items);

  final List<AdminListingRecord> items;

  @override
  Future<AdminListingsPageResult> fetchPage({
    Object? startAfter,
    int pageSize = 30,
  }) async {
    return AdminListingsPageResult(
      items: items,
      cursor: null,
      hasMore: false,
    );
  }
}

void main() {
  testWidgets('conserve les échecs sélectionnés après une suppression partielle',
      (tester) async {
    Map<String, Object?>? sentPayload;
    final repository = _FakeAdminListingsRepository(
      <AdminListingRecord>[
        const AdminListingRecord(
          id: 'listing-a',
          title: 'Peinture salon',
          ownerId: 'user-a',
          status: 'active',
          city: 'Baie-Mahault',
          createdAt: null,
        ),
        const AdminListingRecord(
          id: 'listing-b',
          title: 'Jardinage',
          ownerId: 'user-b',
          status: 'active',
          city: 'Petit-Bourg',
          createdAt: null,
        ),
      ],
    );
    final deletionService = AdminBulkListingService(
      caller: (payload) async {
        sentPayload = payload;
        return <String, Object?>{
          'ok': false,
          'adminActionId': 'action-1',
          'requestedCount': 2,
          'succeededCount': 1,
          'failedCount': 1,
          'results': <Object?>[
            <String, Object?>{'listingId': 'listing-a', 'ok': true},
            <String, Object?>{
              'listingId': 'listing-b',
              'ok': false,
              'errorCode': 'not-found',
              'errorMessage': 'Listing not found',
            },
          ],
        };
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AdminListingsManagementPage(
          repository: repository,
          deletionService: deletionService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Peinture salon'), findsOneWidget);
    expect(find.text('Jardinage'), findsOneWidget);

    await tester.tap(find.byTooltip('Sélectionner toutes les annonces visibles'));
    await tester.pump();
    expect(find.text('Supprimer 2 sélectionnée(s)'), findsOneWidget);

    await tester.tap(find.text('Supprimer 2 sélectionnée(s)'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'contenu interdit');
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmer'));
    await tester.pumpAndSettle();

    expect(sentPayload, <String, Object?>{
      'listingIds': <String>['listing-a', 'listing-b'],
      'reason': 'contenu interdit',
    });
    expect(find.text('Peinture salon'), findsNothing);
    expect(find.text('Jardinage'), findsOneWidget);
    expect(find.text('Supprimer 1 sélectionnée(s)'), findsOneWidget);
    expect(
      find.textContaining('1 suppression(s) réussie(s), 1 échec(s)'),
      findsOneWidget,
    );
  });
}

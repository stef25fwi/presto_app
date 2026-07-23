import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/admin/listings/admin_listings_repository.dart';

void main() {
  test('pagine, filtre les annonces supprimées et reprend après le curseur',
      () async {
    final firestore = FakeFirebaseFirestore();
    final listings = firestore.collection('listings');

    Future<void> add(
      String id, {
      required String title,
      required String status,
      required int day,
    }) {
      return listings.doc(id).set(<String, Object?>{
        'title': title,
        'ownerId': 'owner-$id',
        'status': status,
        'city': 'Baie-Mahault',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 7, day)),
      });
    }

    await add('active-new', title: 'Annonce récente', status: 'active', day: 4);
    await add('deleted', title: 'Annonce supprimée', status: 'deleted', day: 3);
    await add('active-old', title: 'Annonce ancienne', status: 'active', day: 2);
    await add('archived', title: 'Annonce archivée', status: 'archived', day: 1);

    final repository = FirestoreAdminListingsRepository(firestore: firestore);
    final first = await repository.fetchPage(pageSize: 2);

    expect(first.hasMore, isTrue);
    expect(first.items.map((item) => item.id), <String>['active-new']);
    expect(first.cursor, isA<DocumentSnapshot<Map<String, dynamic>>>());

    final second = await repository.fetchPage(
      startAfter: first.cursor,
      pageSize: 100,
    );

    expect(second.hasMore, isFalse);
    expect(
      second.items.map((item) => item.id),
      <String>['active-old', 'archived'],
    );
    expect(second.cursor, isA<DocumentSnapshot<Map<String, dynamic>>>());
  });

  test('borne la taille minimale et conserve le curseur sur une page vide',
      () async {
    final firestore = FakeFirebaseFirestore();
    final repository = FirestoreAdminListingsRepository(firestore: firestore);
    final marker = Object();

    final result = await repository.fetchPage(
      startAfter: marker,
      pageSize: 0,
    );

    expect(result.items, isEmpty);
    expect(result.hasMore, isFalse);
    expect(result.cursor, same(marker));
  });
}

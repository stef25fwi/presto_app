import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/admin/listings/admin_listing_record.dart';

void main() {
  test('normalise les champs canoniques et leurs alias', () {
    final record = AdminListingRecord.fromData(
      id: ' listing-1 ',
      data: <String, dynamic>{
        'name': ' Peinture salon ',
        'userId': ' user-1 ',
        'status': ' ACTIVE ',
        'location': 'Baie-Mahault',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 7, 11, 14)),
      },
    );

    expect(record.id, 'listing-1');
    expect(record.title, 'Peinture salon');
    expect(record.ownerId, 'user-1');
    expect(record.status, 'active');
    expect(record.city, 'Baie-Mahault');
    expect(record.createdAt, DateTime.utc(2026, 7, 11, 14));
    expect(record.isActiveForStatistics, isTrue);
  });

  test('applique les valeurs de repli et exclut les archives', () {
    final record = AdminListingRecord.fromData(
      id: 'listing-2',
      data: <String, dynamic>{'status': 'archived'},
    );

    expect(record.title, 'Annonce sans titre');
    expect(record.ownerId, isEmpty);
    expect(record.createdAt, isNull);
    expect(record.isActiveForStatistics, isFalse);
  });

  test('convertit directement un DateTime local en UTC', () {
    final source = DateTime(2026, 7, 24, 8, 30);
    final record = AdminListingRecord.fromData(
      id: 'listing-datetime',
      data: <String, dynamic>{
        'title': 'Annonce datée',
        'createdAt': source,
      },
    );

    expect(record.createdAt, source.toUtc());
  });
}

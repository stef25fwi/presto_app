import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('les lectures publiques marketplace sont explicitement bornées',
      () async {
    final source = await File(
      'lib/data/marketplace/listing_repository.dart',
    ).readAsString();

    expect(
      source.contains('Stream<List<MarketplaceListing>> watchPublicListings'),
      isTrue,
    );
    expect(
      source.contains(".limit(pageSize)\n        .webSafeSnapshots"),
      isTrue,
    );
    expect(
      source.contains('query.limit(pageSize + 1).get()'),
      isTrue,
    );
    expect(
      source.contains('query = query.startAfterDocument(startAfter)'),
      isTrue,
    );
    expect(
      source.contains('if (value > 100) return 100'),
      isTrue,
    );
  });

  test('le catalogue Firestore ignore les sauvegardes et artefacts', () async {
    final source = await File(
      'tools/quality/audit_firestore_queries.py',
    ).readAsString();

    expect(source.contains("'.backups'"), isTrue);
    expect(source.contains("'backups'"), isTrue);
    expect(source.contains("'docs'"), isTrue);
    expect(source.contains("'test'"), isTrue);
  });
}

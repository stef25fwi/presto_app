import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/data/marketplace/listing_repository.dart';

void main() {
  test('borne la taille des pages publiques entre 1 et 100', () {
    expect(normalizePublicListingsPageSize(-5), 1);
    expect(normalizePublicListingsPageSize(0), 1);
    expect(normalizePublicListingsPageSize(1), 1);
    expect(normalizePublicListingsPageSize(50), 50);
    expect(normalizePublicListingsPageSize(100), 100);
    expect(normalizePublicListingsPageSize(500), 100);
  });
}

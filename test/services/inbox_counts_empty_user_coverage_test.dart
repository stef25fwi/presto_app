import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/inbox_counts.dart';

void main() {
  test('retourne zéro pour un identifiant utilisateur vide sans Firestore', () async {
    final values = await streamInboxCount(userId: '   ').toList();

    expect(values, <int>[0]);
  });
}

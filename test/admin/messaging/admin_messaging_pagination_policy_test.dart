import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/admin/messaging/admin_messaging_pagination_policy.dart';

void main() {
  const policy = AdminMessagingPaginationPolicy();

  test('normalise la taille de page et réserve un document témoin', () {
    expect(policy.normalizePageSize(-1), 40);
    expect(policy.normalizePageSize(0), 40);
    expect(policy.normalizePageSize(25), 25);
    expect(policy.normalizePageSize(140), 100);
    expect(policy.queryLimit(40), 41);
    expect(policy.queryLimit(140), 101);
  });

  test('détecte hasMore uniquement avec un document supplémentaire', () {
    expect(policy.hasMore(receivedCount: 39, requestedPageSize: 40), isFalse);
    expect(policy.hasMore(receivedCount: 40, requestedPageSize: 40), isFalse);
    expect(policy.hasMore(receivedCount: 41, requestedPageSize: 40), isTrue);
  });

  test('masque le document témoin dans les éléments visibles', () {
    expect(
      policy.visibleItems<int>(
        List<int>.generate(41, (index) => index),
        requestedPageSize: 40,
      ),
      List<int>.generate(40, (index) => index),
    );
  });
}

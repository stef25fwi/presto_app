import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/inbox_counts.dart';

void main() {
  test('lit le bon compteur selon le type demande', () {
    final inboxCounts = <String, dynamic>{
      'totalUnread': 9,
      'unreadMessages': 6,
      'unreadNotifications': 3,
    };

    expect(readInboxCount(inboxCounts), 9);
    expect(
      readInboxCount(inboxCounts, type: InboxCountType.unreadMessages),
      6,
    );
    expect(
      readInboxCount(inboxCounts, type: InboxCountType.unreadNotifications),
      3,
    );
  });

  test('retombe a zero si les valeurs sont absentes ou invalides', () {
    expect(readInboxCount(null), 0);
    expect(
      readInboxCount(
        <String, dynamic>{'unreadMessages': 'oops'},
        type: InboxCountType.unreadMessages,
      ),
      0,
    );
  });
}
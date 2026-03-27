import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/conversation_state.dart';

void main() {
  test('detecte une conversation archivee pour un utilisateur', () {
    final data = <String, dynamic>{
      'archivedBy': <String, dynamic>{
        'alice': true,
        'bob': false,
      },
    };

    expect(isConversationArchivedForUser(data, 'alice'), isTrue);
    expect(isConversationArchivedForUser(data, 'bob'), isFalse);
  });

  test('detecte une conversation bloquee via blockedBy ou status', () {
    final blocked = <String, dynamic>{
      'blockedBy': <String, dynamic>{
        'alice': false,
        'bob': true,
      },
    };

    expect(isConversationBlocked(blocked), isTrue);
    expect(isConversationBlockedForUser(blocked, 'bob'), isTrue);
    expect(isConversationBlocked(<String, dynamic>{'status': 'closed'}), isTrue);
  });

  test('filtre la visibilite archivee ou principale', () {
    final archivedData = <String, dynamic>{
      'archivedBy': <String, dynamic>{'alice': true},
    };
    final activeData = <String, dynamic>{
      'archivedBy': <String, dynamic>{'alice': false},
    };

    expect(
      shouldShowConversation(
        data: archivedData,
        userId: 'alice',
        showArchivedOnly: true,
      ),
      isTrue,
    );
    expect(
      shouldShowConversation(
        data: archivedData,
        userId: 'alice',
        showArchivedOnly: false,
      ),
      isFalse,
    );
    expect(
      shouldShowConversation(
        data: activeData,
        userId: 'alice',
        showArchivedOnly: false,
      ),
      isTrue,
    );
  });
}
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/conversation_state.dart';

void main() {
  test('detecte une conversation archivee pour un utilisateur', () {
    final data = <String, dynamic>{
      'archivedBy': <String, dynamic>{'alice': true, 'bob': false},
    };

    expect(isConversationArchivedForUser(data, 'alice'), isTrue);
    expect(isConversationArchivedForUser(data, 'bob'), isFalse);
  });

  test('detecte une conversation bloquee via blockedBy uniquement', () {
    final blocked = <String, dynamic>{
      'blockedBy': <String, dynamic>{'alice': false, 'bob': true},
    };

    expect(isConversationBlocked(blocked), isTrue);
    expect(isConversationBlockedForUser(blocked, 'bob'), isTrue);
    expect(
      isConversationBlocked(<String, dynamic>{'status': 'closed'}),
      isFalse,
    );
    expect(
      isConversationBlocked(<String, dynamic>{
        'status': 'closed',
        'blockedBy': <String, dynamic>{'alice': true},
      }),
      isTrue,
    );
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

  test('retourne false lorsque les champs de drapeau ne sont pas des maps', () {
    final data = <String, dynamic>{
      'archivedBy': true,
      'deletedBy': <String>['alice'],
      'blockedBy': 'alice',
    };

    expect(readConversationFlagForUser(data, 'archivedBy', 'alice'), isFalse);
    expect(isConversationArchivedForUser(data, 'alice'), isFalse);
    expect(isConversationDeletedForUser(data, 'alice'), isFalse);
    expect(isConversationBlocked(data), isFalse);
    expect(isConversationBlockedForUser(data, 'alice'), isFalse);
    expect(isConversationBlockedByOtherUser(data, 'alice'), isFalse);
  });

  test('distingue le blocage courant du blocage par un autre participant', () {
    final data = <String, dynamic>{
      'blockedBy': <String, dynamic>{
        'alice': true,
        'bob': false,
        'charlie': true,
      },
    };

    expect(isConversationBlockedForUser(data, 'alice'), isTrue);
    expect(isConversationBlockedByOtherUser(data, 'alice'), isTrue);
    expect(isConversationBlockedByOtherUser(data, 'bob'), isTrue);
    expect(isConversationBlockedByOtherUser(data, 'charlie'), isTrue);
    expect(
      isConversationBlockedByOtherUser(<String, dynamic>{
        'blockedBy': <String, dynamic>{'alice': true, 'bob': false},
      }, 'alice'),
      isFalse,
    );
  });

  test('masque toujours une conversation supprimee pour l utilisateur', () {
    final deleted = <String, dynamic>{
      'deletedBy': <String, dynamic>{'alice': true},
      'archivedBy': <String, dynamic>{'alice': true},
    };

    expect(isConversationDeletedForUser(deleted, 'alice'), isTrue);
    expect(
      shouldShowConversation(
        data: deleted,
        userId: 'alice',
        showArchivedOnly: false,
      ),
      isFalse,
    );
    expect(
      shouldShowConversation(
        data: deleted,
        userId: 'alice',
        showArchivedOnly: true,
      ),
      isFalse,
    );
  });

  test('exclut les conversations actives du filtre archives uniquement', () {
    final active = <String, dynamic>{
      'archivedBy': <String, dynamic>{'alice': false},
    };

    expect(
      shouldShowConversation(
        data: active,
        userId: 'alice',
        showArchivedOnly: true,
      ),
      isFalse,
    );
  });
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/models/conversation_summary.dart';

ConversationSummary _summary({
  String id = 'conversation-1',
  List<String> participants = const <String>[],
  Map<String, String> participantNames = const <String, String>{},
  String otherUserName = '',
  String offerId = '',
  String offerTitle = '',
  String lastMessage = '',
  String lastSenderId = '',
  String lastSenderName = '',
  Map<String, int> unreadCount = const <String, int>{},
  int messageCount = 0,
  DateTime? createdAt,
  DateTime? updatedAt,
  DateTime? lastMessageAt,
  String status = '',
  Map<String, bool> archivedBy = const <String, bool>{},
  Map<String, bool> deletedBy = const <String, bool>{},
  Map<String, bool> blockedBy = const <String, bool>{},
}) {
  return ConversationSummary(
    id: id,
    participants: participants,
    participantNames: participantNames,
    otherUserName: otherUserName,
    offerId: offerId,
    offerTitle: offerTitle,
    lastMessage: lastMessage,
    lastSenderId: lastSenderId,
    lastSenderName: lastSenderName,
    unreadCount: unreadCount,
    messageCount: messageCount,
    createdAt: createdAt,
    updatedAt: updatedAt,
    lastMessageAt: lastMessageAt,
    status: status,
    archivedBy: archivedBy,
    deletedBy: deletedBy,
    blockedBy: blockedBy,
  );
}

void main() {
  test('fromFirestore lit le document et fusionne les participants supposés',
      () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('conversations').doc('thread-firestore').set(
      <String, dynamic>{
        'participants': <String>['user-a'],
        'participant_names': <String, dynamic>{
          'user-a': 'Alice',
          'user-b': 'Bob',
        },
        'offer_id': 'offer-7',
        'offer_title': 'Aide au jardin',
        'last_message': 'Bonjour',
        'last_sender_id': 'user-a',
        'last_sender_name': 'Alice',
        'unread_count': <String, dynamic>{'user-b': '2'},
        'message_count': '4',
        'created_at': Timestamp.fromMillisecondsSinceEpoch(1000),
        'updated_at': Timestamp.fromMillisecondsSinceEpoch(2000),
        'last_message_at': Timestamp.fromMillisecondsSinceEpoch(3000),
        'status': 'active',
      },
    );

    final snapshot = (await firestore.collection('conversations').get())
        .docs
        .single;
    final summary = ConversationSummary.fromFirestore(
      snapshot,
      assumedParticipants: const <String>[' user-b ', 'user-a'],
    );

    expect(summary.id, 'thread-firestore');
    expect(summary.participants, <String>['user-a', 'user-b']);
    expect(summary.participantNames, <String, String>{
      'user-a': 'Alice',
      'user-b': 'Bob',
    });
    expect(summary.offerId, 'offer-7');
    expect(summary.offerTitle, 'Aide au jardin');
    expect(summary.lastMessage, 'Bonjour');
    expect(summary.lastSenderId, 'user-a');
    expect(summary.lastSenderName, 'Alice');
    expect(summary.unreadForUser(' user-b '), 2);
    expect(summary.messageCount, 4);
    expect(summary.status, 'active');
  });

  test('mergeWith refuse deux identifiants de conversation différents', () {
    expect(
      () => _summary(id: 'conversation-a').mergeWith(
        _summary(id: 'conversation-b'),
      ),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.invalidValue,
          'invalidValue',
          'conversation-b',
        ),
      ),
    );
  });

  test('expose les états utilisateur et le blocage global', () {
    final summary = _summary(
      participants: const <String>['user-a', 'user-b'],
      unreadCount: const <String, int>{'user-a': 3},
      archivedBy: const <String, bool>{'user-a': true},
      deletedBy: const <String, bool>{'user-b': true},
      blockedBy: const <String, bool>{
        'user-a': false,
        'user-b': true,
      },
    );

    expect(summary.includesUser(' user-a '), isTrue);
    expect(summary.includesUser('   '), isFalse);
    expect(summary.includesUser('user-c'), isFalse);
    expect(summary.unreadForUser(' user-a '), 3);
    expect(summary.unreadForUser('user-c'), 0);
    expect(summary.isArchivedForUser(' user-a '), isTrue);
    expect(summary.isArchivedForUser('user-b'), isFalse);
    expect(summary.isDeletedForUser(' user-b '), isTrue);
    expect(summary.isDeletedForUser('user-a'), isFalse);
    expect(summary.isBlockedForUser(' user-b '), isTrue);
    expect(summary.isBlockedForUser('user-a'), isFalse);
    expect(summary.isBlocked, isTrue);
    expect(_summary().isBlocked, isFalse);
  });

  test('hasRenderableContent accepte chaque source et refuse un résumé vide', () {
    expect(_summary(messageCount: 1).hasRenderableContent, isTrue);
    expect(_summary(lastMessage: 'Message').hasRenderableContent, isTrue);
    expect(
      _summary(lastMessageAt: DateTime.utc(2026)).hasRenderableContent,
      isTrue,
    );
    expect(_summary(offerTitle: 'Offre').hasRenderableContent, isTrue);
    expect(_summary(otherUserName: 'Alice').hasRenderableContent, isTrue);
    expect(
      _summary(participants: const <String>['user-a']).hasRenderableContent,
      isTrue,
    );
    expect(_summary(id: 'conversation-id').hasRenderableContent, isTrue);
    expect(_summary(id: '   ').hasRenderableContent, isFalse);
  });

  group('titres et aperçus', () {
    test('titleFor suit tous les replis disponibles', () {
      expect(
        _summary(
          participantNames: const <String, String>{
            'current': 'Moi',
            'other': '  Alice  ',
          },
        ).titleFor('current'),
        'Alice',
      );
      expect(
        _summary(
          participantNames: const <String, String>{
            'current': 'Moi',
            'other': '   ',
          },
          otherUserName: '  Bob  ',
        ).titleFor('current'),
        'Bob',
      );
      expect(
        _summary(offerTitle: '  Mission jardin  ').titleFor('current'),
        'Mission jardin',
      );
      expect(
        _summary(participants: const <String>['current', 'other'])
            .titleFor(' current '),
        'Conversation en cours',
      );
      expect(
        _summary(participants: const <String>['current']).titleFor('current'),
        'Conversation',
      );
    });

    test('previewFor suit tous les replis disponibles', () {
      expect(
        _summary(lastMessage: 'Bonjour', lastSenderId: 'current')
            .previewFor('current'),
        'Vous : Bonjour',
      );
      expect(
        _summary(lastMessage: 'Bonjour', lastSenderId: 'other')
            .previewFor('current'),
        'Bonjour',
      );
      expect(
        _summary(messageCount: 2).previewFor('current'),
        'Messages sans apercu',
      );
      expect(
        _summary(offerTitle: 'Mission jardin').previewFor('current'),
        'Mission jardin',
      );
      expect(
        _summary(participants: const <String>['current']).previewFor('current'),
        'Touchez pour ouvrir cette conversation',
      );
      expect(
        _summary(id: 'conversation-id').previewFor('current'),
        'Touchez pour ouvrir cette conversation',
      );
      expect(
        _summary(id: '   ').previewFor('current'),
        'Conversation en attente de synchronisation',
      );
    });

    test('matchesQuery cherche dans le titre, l aperçu et les métadonnées', () {
      final summary = _summary(
        participantNames: const <String, String>{'other': 'Alice Martin'},
        offerTitle: 'Mission jardin',
        lastMessage: 'Disponible demain',
        lastSenderId: 'other',
        lastSenderName: 'Professionnelle locale',
      );

      expect(summary.matchesQuery('current', '   '), isTrue);
      expect(summary.matchesQuery('current', 'alice'), isTrue);
      expect(summary.matchesQuery('current', 'disponible'), isTrue);
      expect(summary.matchesQuery('current', 'jardin'), isTrue);
      expect(summary.matchesQuery('current', 'professionnelle'), isTrue);
      expect(summary.matchesQuery('current', 'introuvable'), isFalse);
    });
  });

  test('mergeWith gère les cartes booléennes et les dates absentes', () {
    final date = DateTime.utc(2026, 7, 16);
    final leftWithoutDates = _summary(
      id: 'merge-thread',
      participants: const <String>['user-a'],
      archivedBy: const <String, bool>{
        'user-a': true,
        ' ': true,
      },
      deletedBy: const <String, bool>{'user-a': false},
      blockedBy: const <String, bool>{'user-a': false},
    );
    final rightWithDates = _summary(
      id: 'merge-thread',
      participants: const <String>['user-b'],
      createdAt: date,
      updatedAt: date,
      lastMessageAt: date,
      archivedBy: const <String, bool>{
        'user-a': false,
        'user-b': true,
      },
      deletedBy: const <String, bool>{'user-a': true},
      blockedBy: const <String, bool>{'user-b': true},
    );

    final mergedFromNull = leftWithoutDates.mergeWith(rightWithDates);
    expect(mergedFromNull.createdAt, date);
    expect(mergedFromNull.updatedAt, date);
    expect(mergedFromNull.lastMessageAt, date);
    expect(mergedFromNull.archivedBy, <String, bool>{
      'user-a': true,
      ' ': true,
      'user-b': true,
    });
    expect(mergedFromNull.deletedBy['user-a'], isTrue);
    expect(mergedFromNull.blockedBy['user-b'], isTrue);

    final mergedIntoNull = rightWithDates.mergeWith(leftWithoutDates);
    expect(mergedIntoNull.createdAt, date);
    expect(mergedIntoNull.updatedAt, date);
    expect(mergedIntoNull.lastMessageAt, date);
  });
}

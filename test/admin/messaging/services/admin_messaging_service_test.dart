import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/admin/messaging/services/admin_messaging_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late AdminMessagingService service;

  Timestamp time(int day) => Timestamp.fromDate(DateTime.utc(2026, 7, day));

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    service = AdminMessagingService(firestore: firestore);

    await firestore.collection('conversations').doc('conversation-a').set({
      'contextTitle': 'Jardinage',
      'participantIds': <String>['u1', 'u2'],
      'participantNames': <String, String>{'u1': 'Alice', 'u2': 'Bob'},
      'status': 'active',
      'region': 'GP',
      'adminWatchlisted': true,
      'updatedAt': time(15),
      'messageCount': 4,
    });
    await firestore.collection('conversations').doc('conversation-b').set({
      'contextTitle': 'Ménage',
      'participantIds': <String>['u3', 'u4'],
      'status': 'active',
      'region': 'GP',
      'adminWatchlisted': true,
      'updatedAt': time(14),
      'messageCount': 2,
    });
    await firestore.collection('conversations').doc('conversation-c').set({
      'contextTitle': 'Bricolage',
      'status': 'closed',
      'region': 'MQ',
      'adminWatchlisted': false,
      'updatedAt': time(13),
    });

    await firestore.collection('message_reports').doc('report-a').set({
      'conversationId': 'conversation-a',
      'status': 'nouveau',
      'priority': 'haute',
      'reason': 'spam',
      'createdAt': time(15),
    });
    await firestore.collection('message_reports').doc('report-b').set({
      'conversationId': 'conversation-b',
      'status': 'nouveau',
      'priority': 'haute',
      'reason': 'harcèlement',
      'createdAt': time(14),
    });
    await firestore.collection('message_reports').doc('report-c').set({
      'conversationId': 'conversation-c',
      'status': 'résolu',
      'priority': 'basse',
      'createdAt': time(13),
    });

    await firestore.collection('users').doc('user-a').set({
      'displayName': 'Alice',
      'primaryRole': 'user',
      'messagingStatus': 'actif',
      'updatedAt': time(15),
    });
    await firestore.collection('users').doc('user-b').set({
      'displayName': 'Bob',
      'primaryRole': 'user',
      'messagingStatus': 'actif',
      'updatedAt': time(14),
    });
    await firestore.collection('users').doc('user-c').set({
      'displayName': 'Admin',
      'primaryRole': 'admin',
      'messagingStatus': 'bloqué',
      'updatedAt': time(13),
    });

    await firestore.collection('message_attachments').doc('attachment-a').set({
      'conversationId': 'conversation-a',
      'fileType': 'image',
      'moderationStatus': 'pending',
      'createdAt': time(15),
    });
    await firestore.collection('message_attachments').doc('attachment-b').set({
      'conversationId': 'conversation-b',
      'fileType': 'image',
      'moderationStatus': 'pending',
      'createdAt': time(14),
    });
    await firestore.collection('message_attachments').doc('attachment-c').set({
      'conversationId': 'conversation-c',
      'fileType': 'document',
      'moderationStatus': 'approved',
      'createdAt': time(13),
    });
  });

  test('watchConversations applique statut, région, watchlist, ordre et limite',
      () async {
    final items = await service
        .watchConversations(
          limit: 1,
          status: ' active ',
          region: ' GP ',
          watchlisted: true,
        )
        .first;

    expect(items, hasLength(1));
    expect(items.single.id, 'conversation-a');
    expect(items.single.contextTitle, 'Jardinage');
  });

  test('watchConversations accepte les filtres vides', () async {
    final items = await service
        .watchConversations(status: ' ', region: '', watchlisted: false)
        .first;
    expect(items.map((item) => item.id),
        <String>['conversation-a', 'conversation-b', 'conversation-c']);
  });

  test('fetchConversationsPage pagine et conserve le dernier document',
      () async {
    final first = await service.fetchConversationsPage(
      pageSize: 1,
      status: 'active',
      region: 'GP',
      watchlisted: true,
    );
    expect(first.items.map((item) => item.id), <String>['conversation-a']);
    expect(first.hasMore, isTrue);
    expect(first.lastDocument, isNotNull);

    final second = await service.fetchConversationsPage(
      pageSize: 1,
      startAfter: first.lastDocument,
      status: 'active',
      region: 'GP',
      watchlisted: true,
    );
    expect(second.items.map((item) => item.id), <String>['conversation-b']);
    expect(second.hasMore, isFalse);
  });

  test('fetchConversationsPage vide conserve le curseur fourni', () async {
    final seed = await service.fetchConversationsPage(pageSize: 1);
    final empty = await service.fetchConversationsPage(
      pageSize: 1,
      startAfter: seed.lastDocument,
      status: 'inexistant',
    );
    expect(empty.items, isEmpty);
    expect(empty.lastDocument, same(seed.lastDocument));
    expect(empty.hasMore, isFalse);
  });

  test('watchReports filtre statut et priorité', () async {
    final items = await service
        .watchReports(
          limit: 1,
          status: ' nouveau ',
          priority: ' haute ',
        )
        .first;
    expect(items, hasLength(1));
    expect(items.single.id, 'report-a');
    expect(items.single.reason, 'spam');
  });

  test('watchReports accepte les filtres vides', () async {
    final items = await service.watchReports(status: ' ', priority: '').first;
    expect(items, hasLength(3));
  });

  test('fetchReportsPage couvre pagination et curseur', () async {
    final first = await service.fetchReportsPage(
      pageSize: 1,
      status: 'nouveau',
      priority: 'haute',
    );
    expect(first.items.single.id, 'report-a');
    expect(first.hasMore, isTrue);

    final second = await service.fetchReportsPage(
      pageSize: 1,
      startAfter: first.lastDocument,
      status: 'nouveau',
      priority: 'haute',
    );
    expect(second.items.single.id, 'report-b');
    expect(second.hasMore, isFalse);
  });

  test('watchUsers filtre statut et rôle', () async {
    final items = await service
        .watchUsers(
          limit: 1,
          messagingStatus: ' actif ',
          role: ' user ',
        )
        .first;
    expect(items, hasLength(1));
    expect(items.single.uid, 'user-a');
    expect(items.single.name, 'Alice');
  });

  test('watchUsers accepte les filtres vides', () async {
    final items =
        await service.watchUsers(messagingStatus: ' ', role: '').first;
    expect(items, hasLength(3));
  });

  test('fetchUsersPage couvre pagination et curseur', () async {
    final first = await service.fetchUsersPage(
      pageSize: 1,
      messagingStatus: 'actif',
      role: 'user',
    );
    expect(first.items.single.uid, 'user-a');
    expect(first.hasMore, isTrue);

    final second = await service.fetchUsersPage(
      pageSize: 1,
      startAfter: first.lastDocument,
      messagingStatus: 'actif',
      role: 'user',
    );
    expect(second.items.single.uid, 'user-b');
    expect(second.hasMore, isFalse);
  });

  test('watchAttachments ordonne et limite les pièces jointes', () async {
    final items = await service.watchAttachments(limit: 2).first;
    expect(items.map((item) => item.id),
        <String>['attachment-a', 'attachment-b']);
  });

  test('fetchAttachmentsPage filtre et pagine', () async {
    final first = await service.fetchAttachmentsPage(
      pageSize: 1,
      moderationStatus: ' pending ',
      fileType: ' image ',
    );
    expect(first.items.single.id, 'attachment-a');
    expect(first.hasMore, isTrue);

    final second = await service.fetchAttachmentsPage(
      pageSize: 1,
      startAfter: first.lastDocument,
      moderationStatus: 'pending',
      fileType: 'image',
    );
    expect(second.items.single.id, 'attachment-b');
    expect(second.hasMore, isFalse);
  });

  test('fetchAttachmentsPage accepte les filtres vides', () async {
    final page = await service.fetchAttachmentsPage(
      pageSize: 1000,
      moderationStatus: ' ',
      fileType: '',
    );
    expect(page.items, hasLength(3));
    expect(page.hasMore, isFalse);
  });

  test('AdminPagedResult expose ses valeurs', () {
    const result = AdminPagedResult<int>(
      items: <int>[1, 2],
      lastDocument: null,
      hasMore: true,
    );
    expect(result.items, <int>[1, 2]);
    expect(result.lastDocument, isNull);
    expect(result.hasMore, isTrue);
  });
}

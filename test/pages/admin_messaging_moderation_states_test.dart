import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/admin_messaging_moderation_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpPage(
    WidgetTester tester,
    Stream<List<ModerationLogEntry>> stream,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: AdminMessagingModerationPage(entriesStream: stream),
      ),
    );
  }

  test('normalise les clés modernes et les valeurs invalides', () {
    final entry = ModerationLogEntry.fromMap(
      messageId: 'message-modern',
      conversationId: 'conversation-modern',
      data: <String, dynamic>{
        'senderId': 'sender-modern',
        'senderName': 'Modern User',
        'text': 'Message moderne',
        'createdAt': '2026-07-19T12:00:00.000Z',
        'moderation': <String, dynamic>{
          'mode': 'manual',
          'status': 'approved',
          'visibility': 'visible',
          'reason': 'approved_automatically',
          'userMessage': 'Accepté',
          'autoFlags': <dynamic>[' spam ', null, ''],
          'riskScore': 'invalid',
        },
      },
    );

    expect(entry.senderId, 'sender-modern');
    expect(entry.senderName, 'Modern User');
    expect(entry.text, 'Message moderne');
    expect(entry.mode, 'manual');
    expect(entry.status, 'approved');
    expect(entry.visibility, 'visible');
    expect(entry.reason, 'approved_automatically');
    expect(entry.userMessage, 'Accepté');
    expect(entry.autoFlags, <String>[' spam ', 'null']);
    expect(entry.riskScore, 0);
    expect(entry.createdAt, DateTime.utc(2026, 7, 19, 12));
    expect(entry.isModerated, isFalse);
  });

  test('convertit un document Firestore avec son identifiant de conversation',
      () async {
    final firestore = FakeFirebaseFirestore();
    await firestore
        .collection('conversations')
        .doc('conversation-document')
        .collection('messages')
        .doc('message-document')
        .set(<String, dynamic>{
      'sender_id': 'sender-legacy',
      'sender_name': 'Legacy User',
      'body': 'Message depuis Firestore',
      'created_at': '2026-07-19T13:00:00.000Z',
      'moderation': <String, dynamic>{
        'status': 'rejected',
        'reason': 'spam',
        'riskScore': 91,
      },
    });

    final snapshot = await firestore
        .collection('conversations')
        .doc('conversation-document')
        .collection('messages')
        .get();
    final entry = ModerationLogEntry.fromDocument(snapshot.docs.single);

    expect(entry.messageId, 'message-document');
    expect(entry.conversationId, 'conversation-document');
    expect(entry.senderId, 'sender-legacy');
    expect(entry.senderName, 'Legacy User');
    expect(entry.text, 'Message depuis Firestore');
    expect(entry.status, 'rejected');
    expect(entry.reason, 'spam');
    expect(entry.riskScore, 91);
    expect(entry.isModerated, isTrue);
  });

  test('accepte une modération absente et des valeurs nulles', () {
    final entry = ModerationLogEntry.fromMap(
      messageId: 'message-empty',
      conversationId: 'conversation-empty',
      data: <String, dynamic>{'moderation': 'invalid'},
    );

    expect(entry.senderId, isEmpty);
    expect(entry.senderName, isEmpty);
    expect(entry.text, isEmpty);
    expect(entry.mode, isEmpty);
    expect(entry.status, isEmpty);
    expect(entry.visibility, isEmpty);
    expect(entry.reason, isEmpty);
    expect(entry.userMessage, isEmpty);
    expect(entry.autoFlags, isEmpty);
    expect(entry.riskScore, 0);
    expect(entry.createdAt, isNull);
    expect(entry.isModerated, isFalse);
  });

  testWidgets('affiche le chargement avant la première émission', (tester) async {
    final controller = StreamController<List<ModerationLogEntry>>();
    addTearDown(controller.close);

    await pumpPage(tester, controller.stream);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('filtre les messages approuvés du journal', (tester) async {
    const approved = ModerationLogEntry(
      messageId: 'approved',
      conversationId: 'conversation',
      senderId: 'sender',
      senderName: 'Utilisateur approuvé',
      text: 'Message approuvé',
      mode: 'automatic',
      status: 'approved',
      visibility: 'visible',
      reason: 'approved_automatically',
      userMessage: '',
      autoFlags: <String>[],
      riskScore: 0,
      createdAt: null,
    );

    await pumpPage(tester, Stream.value(const <ModerationLogEntry>[approved]));
    await tester.pump();

    expect(find.text('Utilisateur approuvé'), findsNothing);
    expect(
      find.text('Aucun message modéré récent pour ce filtre.'),
      findsOneWidget,
    );
  });

  test('expose les quatre filtres et crée son état', () {
    expect(ModerationLogFilter.values, <ModerationLogFilter>[
      ModerationLogFilter.all,
      ModerationLogFilter.pending,
      ModerationLogFilter.manualReview,
      ModerationLogFilter.rejected,
    ]);
    expect(
      const AdminMessagingModerationPage().createState(),
      isA<State<AdminMessagingModerationPage>>(),
    );
  });
}

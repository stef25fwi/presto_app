import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/admin/messaging/admin_messaging_center_page.dart';
import 'package:presto_app/pages/admin_messaging_moderation_page.dart';
import 'package:presto_app/pages/messages/conversation_thread_page.dart'
    as thread;
import 'package:presto_app/pages/messages/conversations_list_page.dart'
    as conversations;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  test('décrit les requêtes de conversations', () {
    final adminShape = conversations.ConversationsQueryContract.shape(
      isAdminMode: true,
      userId: 'admin-1',
    );
    expect(adminShape['collection'], 'conversations');
    expect(adminShape['orderBy'], 'updatedAt');
    expect(adminShape['descending'], isTrue);
    expect(adminShape['limit'], 50);
    expect(adminShape['participantField'], isNull);
    expect(adminShape['participantValue'], isNull);

    final userShape = conversations.ConversationsQueryContract.shape(
      isAdminMode: false,
      userId: 'user-42',
    );
    expect(userShape['collection'], 'conversations');
    expect(userShape['orderBy'], 'updatedAt');
    expect(userShape['descending'], isTrue);
    expect(userShape['participantField'], 'participantIds');
    expect(userShape['participantValue'], 'user-42');
    expect(userShape['limit'], isNull);
  });

  test('chaque section possède un libellé et une icône', () {
    expect(AdminMessagingSection.values, hasLength(10));
    for (final section in AdminMessagingSection.values) {
      expect(section.label, isNotEmpty);
      expect(section.icon, isA<IconData>());
    }
  });

  test('conserve les paramètres publics du fil de conversation', () {
    const page = thread.ConversationThreadPage(
      conversationId: 'conversation-42',
      offerTitle: 'Peinture salon',
      currentUserId: 'user-42',
      initialDraftText: 'Bonjour, votre annonce est-elle disponible ?',
    );

    expect(page.conversationId, 'conversation-42');
    expect(page.offerTitle, 'Peinture salon');
    expect(page.currentUserId, 'user-42');
    expect(
      page.initialDraftText,
      'Bonjour, votre annonce est-elle disponible ?',
    );
  });

  test('conserve les paramètres publics de la liste de conversations', () {
    const page = conversations.ConversationsListPage(
      initialConversationId: 'conversation-42',
      initialDraftText: 'Message initial',
      appBarTitle: 'Centre de messages',
    );

    expect(page.initialConversationId, 'conversation-42');
    expect(page.initialDraftText, 'Message initial');
    expect(page.appBarTitle, 'Centre de messages');
    expect(page.createState(), isA<State<conversations.ConversationsListPage>>());

    const defaultPage = conversations.ConversationsListPage();
    expect(defaultPage.initialConversationId, isNull);
    expect(defaultPage.initialDraftText, isNull);
    expect(defaultPage.appBarTitle, 'Mes messages');
  });

  test('expose les styles système et la palette des écrans de messagerie', () {
    expect(thread.kPrestoOrange, const Color(0xFFFF6600));
    expect(thread.kPrestoBlue, const Color(0xFF1A73E8));
    expect(thread.kThreadMineColor, const Color(0xFFD9FDD3));
    expect(thread.kThreadOtherColor, Colors.white);
    expect(
      thread.kConversationThreadStatusBarStyle.statusBarColor,
      thread.kPrestoOrange,
    );
    expect(
      thread.kConversationThreadStatusBarStyle.statusBarIconBrightness,
      Brightness.light,
    );

    expect(conversations.kPrestoOrange, const Color(0xFFFF6600));
    expect(conversations.kPrestoBlue, const Color(0xFF1A73E8));
    expect(conversations.kMessagesPageBackground, const Color(0xFFFFFEFE));
    expect(
      conversations.kMessagesStatusBarStyle.statusBarColor,
      conversations.kPrestoOrange,
    );
    expect(
      conversations.kMessagesStatusBarStyle.statusBarIconBrightness,
      Brightness.light,
    );
  });

  test('normalise les données de modération historiques et actuelles', () {
    final entry = ModerationLogEntry.fromMap(
      messageId: 'message-1',
      conversationId: 'conversation-1',
      data: {
        'sender_id': 'user-1',
        'sender_name': 'Alice',
        'body': 'Contenu signalé',
        'created_at': DateTime(2026, 7, 18, 12, 30),
        'moderation': {
          'mode': 'automatic',
          'status': 'manual_review',
          'visibility': 'hidden',
          'reason': 'language',
          'userMessage': 'Message refusé',
          'autoFlags': ['insulte', '', 42],
          'riskScore': 71.6,
        },
      },
    );

    expect(entry.messageId, 'message-1');
    expect(entry.conversationId, 'conversation-1');
    expect(entry.senderId, 'user-1');
    expect(entry.senderName, 'Alice');
    expect(entry.text, 'Contenu signalé');
    expect(entry.mode, 'automatic');
    expect(entry.status, 'manual_review');
    expect(entry.visibility, 'hidden');
    expect(entry.reason, 'language');
    expect(entry.userMessage, 'Message refusé');
    expect(entry.autoFlags, ['insulte', '42']);
    expect(entry.riskScore, 72);
    expect(entry.createdAt, isNotNull);
    expect(entry.isModerated, isTrue);
  });

  test('distingue les messages approuvés des messages modérés', () {
    ModerationLogEntry entry(String status, String reason) {
      return ModerationLogEntry(
        messageId: status,
        conversationId: 'conversation',
        senderId: 'user',
        senderName: '',
        text: '',
        mode: '',
        status: status,
        visibility: '',
        reason: reason,
        userMessage: '',
        autoFlags: const [],
        riskScore: 0,
        createdAt: null,
      );
    }

    expect(entry('pending', '').isModerated, isTrue);
    expect(entry('manual_review', '').isModerated, isTrue);
    expect(entry('rejected', '').isModerated, isTrue);
    expect(entry('approved', 'policy').isModerated, isTrue);
    expect(entry('approved', 'approved_automatically').isModerated, isFalse);
    expect(entry('approved', '').isModerated, isFalse);
  });

  Future<void> pumpModeration(
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
    await tester.pump();
  }

  const pending = ModerationLogEntry(
    messageId: 'pending-1',
    conversationId: 'conversation-pending',
    senderId: 'sender-pending',
    senderName: 'Alice',
    text: 'Message en attente',
    mode: 'hybrid',
    status: 'pending',
    visibility: 'visible',
    reason: 'vérification',
    userMessage: 'Analyse en cours',
    autoFlags: ['flag-a'],
    riskScore: 30,
    createdAt: null,
  );
  final manual = ModerationLogEntry(
    messageId: 'manual-1',
    conversationId: 'conversation-manual',
    senderId: 'sender-manual',
    senderName: '',
    text: '',
    mode: '',
    status: 'manual_review',
    visibility: '',
    reason: '',
    userMessage: '',
    autoFlags: const [],
    riskScore: 50,
    createdAt: DateTime(2026, 7, 18, 14, 5),
  );
  const rejected = ModerationLogEntry(
    messageId: 'rejected-1',
    conversationId: 'conversation-rejected',
    senderId: 'sender-rejected',
    senderName: 'Bob',
    text: 'Message refusé',
    mode: 'automatic',
    status: 'rejected',
    visibility: 'hidden',
    reason: 'contenu interdit',
    userMessage: 'Votre message a été refusé',
    autoFlags: ['violence', 'spam'],
    riskScore: 95,
    createdAt: null,
  );

  testWidgets('affiche les cartes modérées et leurs détails', (tester) async {
    await pumpModeration(
      tester,
      Stream.value([pending, manual, rejected]),
    );
    await tester.pump();

    expect(find.text('Modération messages'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('sender-manual'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Message en attente'), findsOneWidget);
    expect(find.text('Message sans texte explicite'), findsOneWidget);
    expect(find.text('Raison: contenu interdit'), findsOneWidget);
    expect(find.text('Message utilisateur: Analyse en cours'), findsOneWidget);
    expect(find.text('violence'), findsOneWidget);
    expect(find.text('spam'), findsOneWidget);
    expect(find.text('Risk 95'), findsOneWidget);
    expect(find.textContaining('Date inconnue'), findsWidgets);
  });

  testWidgets('filtre pending revue refusés puis revient à tous', (tester) async {
    await pumpModeration(
      tester,
      Stream.value([pending, manual, rejected]),
    );
    await tester.pump();

    await tester.tap(find.text('Pending'));
    await tester.pump();
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsNothing);

    await tester.tap(find.text('Revue'));
    await tester.pump();
    expect(find.text('sender-manual'), findsOneWidget);
    expect(find.text('Alice'), findsNothing);

    await tester.tap(find.text('Refusés'));
    await tester.pump();
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('sender-manual'), findsNothing);

    await tester.tap(find.text('Tous'));
    await tester.pump();
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('sender-manual'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
  });

  testWidgets('affiche les états vide et erreur', (tester) async {
    await pumpModeration(tester, Stream.value(const []));
    await tester.pump();
    expect(
      find.text('Aucun message modéré récent pour ce filtre.'),
      findsOneWidget,
    );

    await pumpModeration(
      tester,
      Stream<List<ModerationLogEntry>>.error('permission-denied'),
    );
    await tester.pump();
    expect(
      find.textContaining('permission-denied'),
      findsOneWidget,
    );
  });
}

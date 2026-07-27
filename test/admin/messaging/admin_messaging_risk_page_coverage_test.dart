import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/admin/messaging/admin_messaging_risk_page.dart';
import 'package:presto_app/admin/messaging/models/admin_conversation_model.dart';
import 'package:presto_app/admin/messaging/models/admin_messaging_user_model.dart';

AdminConversationModel conversation({
  required String id,
  required String title,
  required int riskScore,
  bool watchlisted = false,
}) {
  return AdminConversationModel(
    id: id,
    shortId: id,
    contextId: 'listing-$id',
    contextTitle: title,
    category: 'Service',
    region: 'Guadeloupe',
    participantIds: const <String>['user-1', 'user-2'],
    participantNames: const <String, String>{
      'user-1': 'Alice',
      'user-2': 'Bob',
    },
    createdAt: null,
    updatedAt: null,
    lastMessageAt: null,
    messageCount: 2,
    status: 'active',
    riskScore: riskScore,
    reportCount: 0,
    adminWatchlisted: watchlisted,
    hasAttachments: false,
    hasUnread: false,
  );
}

AdminMessagingUserModel messagingUser({
  required String uid,
  required String name,
  required int riskScore,
  required String status,
}) {
  return AdminMessagingUserModel(
    uid: uid,
    name: name,
    email: '$uid@ilipresto.fr',
    role: 'user',
    region: 'Guadeloupe',
    createdAt: null,
    lastActivityAt: null,
    openConversations: 1,
    messagesSent: 2,
    messagesReceived: 3,
    reportsReceived: 0,
    reportsSent: 0,
    messagingStatus: status,
    riskScore: riskScore,
    responseRate: 1,
    averageResponseHours: 1,
  );
}

void configureViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('affiche les deux états vides', (tester) async {
    configureViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: AdminMessagingRiskPage(
          conversationsStream:
              Stream<List<AdminConversationModel>>.value(const []),
          usersStream: Stream<List<AdminMessagingUserModel>>.value(const []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Supervision des risques'), findsOneWidget);
    expect(
      find.text('Aucune conversation à risque élevé dans le flux récent.'),
      findsOneWidget,
    );
    expect(
      find.text('Aucun utilisateur sensible dans le flux récent.'),
      findsOneWidget,
    );
  });

  testWidgets('filtre et présente les conversations et utilisateurs sensibles',
      (tester) async {
    configureViewport(tester);
    final conversations = <AdminConversationModel>[
      conversation(
        id: 'risk',
        title: 'Conversation score élevé',
        riskScore: 82,
      ),
      conversation(
        id: 'watch',
        title: 'Conversation watchlistée',
        riskScore: 10,
        watchlisted: true,
      ),
      conversation(
        id: 'normal',
        title: 'Conversation normale',
        riskScore: 20,
      ),
    ];
    final users = <AdminMessagingUserModel>[
      messagingUser(
        uid: 'risk-user',
        name: 'Utilisateur score élevé',
        riskScore: 75,
        status: 'actif',
      ),
      messagingUser(
        uid: 'blocked-user',
        name: 'Utilisateur bloqué',
        riskScore: 5,
        status: 'bloqué',
      ),
      messagingUser(
        uid: 'suspended-user',
        name: 'Utilisateur suspendu',
        riskScore: 5,
        status: 'suspendu',
      ),
      messagingUser(
        uid: 'normal-user',
        name: 'Utilisateur normal',
        riskScore: 5,
        status: 'actif',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: AdminMessagingRiskPage(
          conversationsStream:
              Stream<List<AdminConversationModel>>.value(conversations),
          usersStream: Stream<List<AdminMessagingUserModel>>.value(users),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Conversation score élevé'), findsOneWidget);
    expect(find.text('Conversation watchlistée'), findsOneWidget);
    expect(find.text('Conversation normale'), findsNothing);
    expect(find.text('Watchlist'), findsOneWidget);

    expect(find.text('Utilisateur score élevé'), findsOneWidget);
    expect(find.text('Utilisateur bloqué'), findsOneWidget);
    expect(find.text('Utilisateur suspendu'), findsOneWidget);
    expect(find.text('Utilisateur normal'), findsNothing);
  });
}

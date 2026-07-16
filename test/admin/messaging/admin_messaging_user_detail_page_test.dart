import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/admin/messaging/admin_messaging_user_detail_page.dart';
import 'package:presto_app/admin/messaging/models/admin_messaging_user_model.dart';

void main() {
  const user = AdminMessagingUserModel(
    uid: 'user-123',
    name: 'Marie Test',
    email: 'marie@example.com',
    role: 'professionnel',
    region: 'Guadeloupe',
    createdAt: null,
    lastActivityAt: null,
    openConversations: 4,
    messagesSent: 12,
    messagesReceived: 9,
    reportsReceived: 2,
    reportsSent: 1,
    messagingStatus: 'actif',
    riskScore: 37,
    responseRate: 84.6,
    averageResponseHours: 2.75,
  );

  Widget buildPage({
    AdminMessagingUserModel displayedUser = user,
    required AdminUserMessagingStatusUpdater updateStatus,
  }) {
    return MaterialApp(
      home: AdminMessagingUserDetailPage(
        user: displayedUser,
        updateUserMessagingStatus: updateStatus,
      ),
    );
  }

  testWidgets('affiche toutes les informations et actions utilisateur',
      (tester) async {
    await tester.pumpWidget(
      buildPage(
        updateStatus: ({
          required String userId,
          required String status,
          required String reason,
        }) async {},
      ),
    );

    expect(find.text('Fiche utilisateur messagerie'), findsOneWidget);
    expect(find.text('Marie Test'), findsOneWidget);
    expect(find.text('marie@example.com'), findsOneWidget);
    expect(find.text('professionnel'), findsOneWidget);
    expect(find.text('Guadeloupe'), findsOneWidget);
    expect(find.text('Conversations ouvertes: 4'), findsOneWidget);
    expect(find.text('Messages envoyés: 12'), findsOneWidget);
    expect(find.text('Messages reçus: 9'), findsOneWidget);
    expect(find.text('Signalements reçus: 2'), findsOneWidget);
    expect(find.text('Signalements envoyés: 1'), findsOneWidget);
    expect(find.text('Taux de réponse: 85 %'), findsOneWidget);
    expect(find.text('Délai moyen: 2.8 h'), findsOneWidget);
    expect(find.text('Activer'), findsOneWidget);
    expect(find.text('Restreindre'), findsOneWidget);
    expect(find.text('Suspendre'), findsOneWidget);
    expect(find.text('Bloquer'), findsOneWidget);
  });

  testWidgets('affiche l’identifiant lorsque l’email est vide', (tester) async {
    const userWithoutEmail = AdminMessagingUserModel(
      uid: 'fallback-uid',
      name: 'Utilisateur sans email',
      email: '',
      role: 'user',
      region: 'Martinique',
      createdAt: null,
      lastActivityAt: null,
      openConversations: 0,
      messagesSent: 0,
      messagesReceived: 0,
      reportsReceived: 0,
      reportsSent: 0,
      messagingStatus: 'restreint',
      riskScore: 0,
      responseRate: 0,
      averageResponseHours: 0,
    );

    await tester.pumpWidget(
      buildPage(
        displayedUser: userWithoutEmail,
        updateStatus: ({
          required String userId,
          required String status,
          required String reason,
        }) async {},
      ),
    );

    expect(find.text('fallback-uid'), findsOneWidget);
  });

  testWidgets('annuler la confirmation ne déclenche aucune modération',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      buildPage(
        updateStatus: ({
          required String userId,
          required String status,
          required String reason,
        }) async {
          calls += 1;
        },
      ),
    );

    await tester.tap(find.text('Bloquer'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmer le changement de statut'), findsOneWidget);

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(calls, 0);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  const actions = <String, String>{
    'Activer': 'actif',
    'Restreindre': 'restreint',
    'Suspendre': 'suspendu',
    'Bloquer': 'bloqué',
  };

  for (final entry in actions.entries) {
    testWidgets('${entry.key} transmet le statut confirmé', (tester) async {
      String? receivedUserId;
      String? receivedStatus;
      String? receivedReason;

      await tester.pumpWidget(
        buildPage(
          updateStatus: ({
            required String userId,
            required String status,
            required String reason,
          }) async {
            receivedUserId = userId;
            receivedStatus = status;
            receivedReason = reason;
          },
        ),
      );

      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmer'));
      await tester.pumpAndSettle();

      expect(receivedUserId, 'user-123');
      expect(receivedStatus, entry.value);
      expect(
        receivedReason,
        'Action depuis la fiche utilisateur messagerie',
      );
      expect(
        find.text('Statut utilisateur mis à jour: ${entry.value}'),
        findsOneWidget,
      );
    });
  }

  testWidgets('désactive les actions pendant la sauvegarde', (tester) async {
    final completer = Completer<void>();

    await tester.pumpWidget(
      buildPage(
        updateStatus: ({
          required String userId,
          required String status,
          required String reason,
        }) =>
            completer.future,
      ),
    );

    await tester.tap(find.text('Restreindre'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmer'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    for (final label in actions.keys) {
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, label),
      );
      expect(button.onPressed, isNull);
    }

    completer.complete();
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Statut utilisateur mis à jour: restreint'), findsOneWidget);
  });
}

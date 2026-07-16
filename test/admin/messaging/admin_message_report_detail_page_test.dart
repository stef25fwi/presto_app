import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/admin/messaging/admin_message_report_detail_page.dart';
import 'package:presto_app/admin/messaging/models/admin_message_report_model.dart';

void main() {
  const report = AdminMessageReportModel(
    id: 'report-123',
    conversationId: 'conversation-456',
    messageId: 'message-789',
    reportedBy: 'reporter-1',
    reportedUserId: 'target-2',
    reason: 'Contenu inapproprié',
    description: 'Description détaillée du signalement.',
    priority: 'haute',
    status: 'nouveau',
    assignedTo: 'admin@example.com',
    adminDecision: 'analyse en cours',
    createdAt: null,
    resolvedAt: null,
  );

  Widget buildPage({
    AdminMessageReportModel displayedReport = report,
    required AdminMessageReportStatusUpdater updateStatus,
  }) {
    return MaterialApp(
      home: AdminMessageReportDetailPage(
        report: displayedReport,
        updateReportStatus: updateStatus,
      ),
    );
  }

  testWidgets('affiche toutes les informations et décisions du signalement',
      (tester) async {
    await tester.pumpWidget(
      buildPage(
        updateStatus: ({
          required String reportId,
          required String status,
          required String decision,
          required String reason,
        }) async {},
      ),
    );

    expect(find.text('Détail signalement'), findsOneWidget);
    expect(find.text('Contenu inapproprié'), findsOneWidget);
    expect(find.text('Description détaillée du signalement.'), findsOneWidget);
    expect(find.text('Conversation: conversation-456'), findsOneWidget);
    expect(find.text('Message: message-789'), findsOneWidget);
    expect(find.text('Signalé par: reporter-1'), findsOneWidget);
    expect(find.text('Utilisateur visé: target-2'), findsOneWidget);
    expect(find.text('Assigné à: admin@example.com'), findsOneWidget);
    expect(find.text('Décision admin: analyse en cours'), findsOneWidget);
    expect(find.text('Passer en revue'), findsOneWidget);
    expect(find.text('Clore sans action'), findsOneWidget);
    expect(find.text('Clore avec action'), findsOneWidget);
  });

  testWidgets('affiche les valeurs de repli lorsque les détails sont absents',
      (tester) async {
    const reportWithoutDetails = AdminMessageReportModel(
      id: 'report-empty',
      conversationId: 'conversation-empty',
      messageId: 'message-empty',
      reportedBy: 'reporter-empty',
      reportedUserId: 'target-empty',
      reason: 'Autre',
      description: '   ',
      priority: 'moyenne',
      status: 'nouveau',
      assignedTo: '',
      adminDecision: '',
      createdAt: null,
      resolvedAt: null,
    );

    await tester.pumpWidget(
      buildPage(
        displayedReport: reportWithoutDetails,
        updateStatus: ({
          required String reportId,
          required String status,
          required String decision,
          required String reason,
        }) async {},
      ),
    );

    expect(find.text('Aucune description complémentaire.'), findsOneWidget);
    expect(find.text('Assigné à: non assigné'), findsOneWidget);
    expect(find.text('Décision admin: aucune'), findsOneWidget);
  });

  testWidgets('annuler la confirmation ne déclenche aucune mise à jour',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      buildPage(
        updateStatus: ({
          required String reportId,
          required String status,
          required String decision,
          required String reason,
        }) async {
          calls += 1;
        },
      ),
    );

    await tester.ensureVisible(find.text('Clore avec action'));
    await tester.tap(find.text('Clore avec action'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmer la décision'), findsOneWidget);

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(calls, 0);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  const actions = <String, ({String status, String decision})>{
    'Passer en revue': (status: 'en revue', decision: 'manual_review'),
    'Clore sans action': (
      status: 'résolu',
      decision: 'resolved_no_action',
    ),
    'Clore avec action': (status: 'résolu', decision: 'action_taken'),
  };

  for (final entry in actions.entries) {
    testWidgets('${entry.key} transmet la décision confirmée', (tester) async {
      String? receivedReportId;
      String? receivedStatus;
      String? receivedDecision;
      String? receivedReason;

      await tester.pumpWidget(
        buildPage(
          updateStatus: ({
            required String reportId,
            required String status,
            required String decision,
            required String reason,
          }) async {
            receivedReportId = reportId;
            receivedStatus = status;
            receivedDecision = decision;
            receivedReason = reason;
          },
        ),
      );

      await tester.ensureVisible(find.text(entry.key));
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();

      expect(receivedReportId, 'report-123');
      expect(receivedStatus, entry.value.status);
      expect(receivedDecision, entry.value.decision);
      expect(receivedReason, 'Traitement depuis le détail signalement');
      expect(
        find.text('Signalement mis à jour: ${entry.value.status}'),
        findsOneWidget,
      );
    });
  }

  testWidgets('désactive les décisions pendant la sauvegarde', (tester) async {
    final completer = Completer<void>();

    await tester.pumpWidget(
      buildPage(
        updateStatus: ({
          required String reportId,
          required String status,
          required String decision,
          required String reason,
        }) =>
            completer.future,
      ),
    );

    await tester.ensureVisible(find.text('Passer en revue'));
    await tester.tap(find.text('Passer en revue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Valider'));
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
    expect(find.text('Signalement mis à jour: en revue'), findsOneWidget);
  });
}

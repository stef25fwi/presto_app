import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/admin/messaging/widgets/admin_confirm_sensitive_action_dialog.dart';
import 'package:presto_app/admin/messaging/widgets/admin_conversation_status_badge.dart';
import 'package:presto_app/admin/messaging/widgets/admin_messaging_filter_bar.dart';
import 'package:presto_app/admin/messaging/widgets/admin_report_priority_badge.dart';
import 'package:presto_app/admin/messaging/widgets/admin_risk_score_badge.dart';
import 'package:presto_app/admin/messaging/widgets/admin_user_messaging_status_badge.dart';

void main() {
  Widget app(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('les badges conversation couvrent tous les statuts', (
    tester,
  ) async {
    const statuses = <String>[
      'closed',
      'bloquée',
      'blocked',
      'archived',
      'archivée',
      'reported',
      'signalée',
      'deleted',
      'supprimée',
      'active',
    ];

    await tester.pumpWidget(
      app(
        Wrap(
          children: statuses
              .map(
                (status) => AdminConversationStatusBadge(status: status),
              )
              .toList(growable: false),
        ),
      ),
    );

    for (final status in statuses) {
      expect(find.text(status), findsOneWidget);
    }
  });

  testWidgets('les badges priorité et utilisateur couvrent leurs niveaux', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        const Wrap(
          children: <Widget>[
            AdminReportPriorityBadge(priority: 'critique'),
            AdminReportPriorityBadge(priority: 'haute'),
            AdminReportPriorityBadge(priority: 'moyenne'),
            AdminReportPriorityBadge(priority: 'basse'),
            AdminUserMessagingStatusBadge(status: 'bloqué'),
            AdminUserMessagingStatusBadge(status: 'suspendu'),
            AdminUserMessagingStatusBadge(status: 'restreint'),
            AdminUserMessagingStatusBadge(status: 'surveillé'),
            AdminUserMessagingStatusBadge(status: 'actif'),
          ],
        ),
      ),
    );

    expect(find.text('critique'), findsOneWidget);
    expect(find.text('haute'), findsOneWidget);
    expect(find.text('moyenne'), findsOneWidget);
    expect(find.text('basse'), findsOneWidget);
    expect(find.text('bloqué'), findsOneWidget);
    expect(find.text('suspendu'), findsOneWidget);
    expect(find.text('restreint'), findsOneWidget);
    expect(find.text('surveillé'), findsOneWidget);
    expect(find.text('actif'), findsOneWidget);
  });

  testWidgets('le badge risque couvre faible, moyen et élevé', (tester) async {
    await tester.pumpWidget(
      app(
        const Wrap(
          children: <Widget>[
            AdminRiskScoreBadge(score: 20),
            AdminRiskScoreBadge(score: 50),
            AdminRiskScoreBadge(score: 80),
          ],
        ),
      ),
    );

    expect(find.text('Risque 20'), findsOneWidget);
    expect(find.text('Risque 50'), findsOneWidget);
    expect(find.text('Risque 80'), findsOneWidget);
  });

  testWidgets('la barre de filtre soumet la recherche et les filtres rapides', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    String? submitted;
    String? quickFilter;

    await tester.pumpWidget(
      app(
        AdminMessagingFilterBar(
          controller: controller,
          hintText: 'Rechercher une conversation',
          quickFilters: const <String>['Signalées', 'Bloquées'],
          onSubmitted: (value) => submitted = value,
          onQuickFilterTap: (value) => quickFilter = value,
        ),
      ),
    );

    expect(find.text('Signalées'), findsOneWidget);
    expect(find.text('Bloquées'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'utilisateur');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(submitted, 'utilisateur');

    await tester.tap(find.text('Signalées'));
    await tester.pump();
    expect(quickFilter, 'Signalées');
  });

  testWidgets('la barre sans filtres et sans callback reste utilisable', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      app(
        AdminMessagingFilterBar(
          controller: controller,
          hintText: 'Recherche',
        ),
      ),
    );

    expect(find.byType(ActionChip), findsNothing);
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
  });

  testWidgets('le dialogue retourne false à l annulation', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showDialog<bool>(
                context: context,
                builder: (_) => const AdminConfirmSensitiveActionDialog(
                  title: 'Bloquer',
                  message: 'Confirmer le blocage ?',
                ),
              );
            },
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    expect(find.text('Bloquer'), findsOneWidget);
    expect(find.text('Confirmer'), findsOneWidget);

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('le dialogue retourne true avec un libellé personnalisé', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showDialog<bool>(
                context: context,
                builder: (_) => const AdminConfirmSensitiveActionDialog(
                  title: 'Supprimer',
                  message: 'Action irréversible',
                  confirmLabel: 'Supprimer maintenant',
                ),
              );
            },
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer maintenant'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/admin_monitoring_health_page.dart';

void main() {
  Future<void> pumpPage(
    WidgetTester tester,
    Stream<List<Map<String, dynamic>>> stream,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: AdminMonitoringHealthPage(eventsStream: stream),
      ),
    );
  }

  Future<void> flushStream(WidgetTester tester) async {
    for (var index = 0; index < 5; index++) {
      await tester.pump();
    }
  }

  void expectHealthValue(String label, String value) {
    final card = find.ancestor(
      of: find.text(label),
      matching: find.byType(Card),
    );
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text(value)),
      findsOneWidget,
    );
  }

  testWidgets('affiche le chargement avant la première émission',
      (tester) async {
    final controller = StreamController<List<Map<String, dynamic>>>();
    addTearDown(controller.close);

    await pumpPage(tester, controller.stream);
    await tester.pump();

    expect(find.text('Santé app'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Derniers événements'), findsNothing);
  });

  testWidgets('affiche une erreur de monitoring lisible', (tester) async {
    await pumpPage(
      tester,
      Stream<List<Map<String, dynamic>>>.error(
        StateError('service indisponible'),
      ),
    );
    await flushStream(tester);

    expect(
      find.textContaining('Erreur monitoring :'),
      findsOneWidget,
    );
    expect(find.textContaining('service indisponible'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('affiche les six compteurs à zéro pour un flux vide',
      (tester) async {
    await pumpPage(
      tester,
      Stream.value(const <Map<String, dynamic>>[]),
    );
    await flushStream(tester);

    for (final label in const [
      'Événements 24h',
      'Erreurs',
      'Critiques',
      'Warnings',
      'App Check refusé',
      'Admin connecté',
    ]) {
      expectHealthValue(label, '0');
    }

    expect(find.text('Derniers événements'), findsOneWidget);
    expect(
      find.text('Aucun événement monitoring sur les dernières 24h.'),
      findsOneWidget,
    );
  });

  testWidgets('agrège les niveaux et rend les derniers événements',
      (tester) async {
    final events = <Map<String, dynamic>>[
      {
        'level': 'critical',
        'scope': 'app_check',
        'action': 'refused',
        'message': 'Jeton refusé',
        'appBuild': '100',
        'gitCommit': 'abc123',
      },
      {
        'level': 'error',
        'scope': 'payments',
        'action': 'webhook_failed',
        'message': 'Webhook en erreur',
        'appBuild': '100',
        'gitCommit': 'def456',
      },
      {
        'level': 'warning',
        'scope': 'storage',
        'action': 'quota_high',
        'message': 'Quota élevé',
        'appBuild': '101',
        'gitCommit': 'ghi789',
      },
      {
        'level': 'info',
        'scope': 'admin',
        'action': 'admin_connected',
        'message': 'Connexion admin',
        'appBuild': '101',
        'gitCommit': 'jkl012',
      },
      {
        'scope': 'admin',
        'action': 'admin_connected',
        'message': 'Nouvelle connexion',
      },
    ];

    await pumpPage(tester, Stream.value(events));
    await flushStream(tester);

    expectHealthValue('Événements 24h', '5');
    expectHealthValue('Erreurs', '2');
    expectHealthValue('Critiques', '1');
    expectHealthValue('Warnings', '1');
    expectHealthValue('App Check refusé', '1');
    expectHealthValue('Admin connecté', '2');

    expect(find.text('app_check / refused'), findsOneWidget);
    expect(find.text('payments / webhook_failed'), findsOneWidget);
    expect(find.text('storage / quota_high'), findsOneWidget);
    expect(find.text('admin / admin_connected'), findsNWidgets(2));
    expect(find.textContaining('critical · Jeton refusé'), findsOneWidget);
    expect(find.textContaining('Build 100 · Commit abc123'), findsOneWidget);
    expect(find.textContaining('- · Nouvelle connexion'), findsOneWidget);
    expect(find.textContaining('Build - · Commit -'), findsOneWidget);

    final criticalTile = find.ancestor(
      of: find.text('app_check / refused'),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(
        of: criticalTile,
        matching: find.byIcon(Icons.warning_amber),
      ),
      findsOneWidget,
    );

    final errorTile = find.ancestor(
      of: find.text('payments / webhook_failed'),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(
        of: errorTile,
        matching: find.byIcon(Icons.error_outline),
      ),
      findsOneWidget,
    );

    final warningTile = find.ancestor(
      of: find.text('storage / quota_high'),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(
        of: warningTile,
        matching: find.byIcon(Icons.report_problem_outlined),
      ),
      findsOneWidget,
    );

    final infoTiles = find.ancestor(
      of: find.text('admin / admin_connected'),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(
        of: infoTiles,
        matching: find.byIcon(Icons.info_outline),
      ),
      findsNWidgets(2),
    );
  });
}

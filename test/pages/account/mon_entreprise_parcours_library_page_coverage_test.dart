import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/subscriptions/subscription_credit_service.dart';
import 'package:presto_app/pages/account/mon_entreprise_parcours_library_page.dart';

SavedJourneyRecord journey({
  String id = 'j1',
  String title = 'Mon activité',
  String activity = 'Conseil',
  String status = 'Salarié',
  String region = 'Guadeloupe',
}) {
  return SavedJourneyRecord(
    id: id,
    title: title,
    activity: activity,
    currentStatus: status,
    region: region,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 2),
    snapshot: const {'summary': {'title': 'Résumé'}},
  );
}

Widget app(MonEntrepriseParcoursLibraryPage page) => MaterialApp(home: page);

void main() {
  testWidgets('shows loading then empty library and opens new journey', (tester) async {
    final completer = Completer<List<SavedJourneyRecord>>();
    await tester.pumpWidget(app(MonEntrepriseParcoursLibraryPage(
      showCredits: false,
      loadLibrary: () => completer.future,
      newJourneyBuilder: () => const Scaffold(body: Text('Nouvelle fiche')),
    )));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    completer.complete(const []);
    await tester.pumpAndSettle();

    expect(find.text('Aucun parcours sauvegardé. Créez-en un pour le retrouver sur tous vos appareils.'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    await tester.tap(find.text('Créer un nouveau parcours'));
    await tester.pumpAndSettle();
    expect(find.text('Nouvelle fiche'), findsOneWidget);
  });

  testWidgets('shows load error and retries successfully', (tester) async {
    var calls = 0;
    await tester.pumpWidget(app(MonEntrepriseParcoursLibraryPage(
      showCredits: false,
      loadLibrary: () async {
        calls++;
        if (calls == 1) throw StateError('boom');
        return const [];
      },
    )));
    await tester.pumpAndSettle();

    expect(find.text('Impossible de charger vos parcours pour le moment.'), findsOneWidget);
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.textContaining('Aucun parcours sauvegardé'), findsOneWidget);
  });

  testWidgets('renders records, fallbacks and opens summary', (tester) async {
    final records = [
      journey(),
      journey(id: 'j2', title: '', activity: 'Photographie', status: '', region: ''),
      journey(id: 'j3', title: '', activity: '', status: '', region: ''),
    ];
    await tester.pumpWidget(app(MonEntrepriseParcoursLibraryPage(
      showCredits: false,
      loadLibrary: () async => records,
      summaryBuilder: (_) => const Scaffold(body: Text('Résumé ouvert')),
    )));
    await tester.pumpAndSettle();

    expect(find.text('3'), findsOneWidget);
    expect(find.text('Mon activité'), findsOneWidget);
    expect(find.text('Salarié · Guadeloupe'), findsOneWidget);
    expect(find.text('Photographie'), findsOneWidget);
    expect(find.text('Mon parcours personnalisé'), findsOneWidget);

    await tester.tap(find.text('Ouvrir').first);
    await tester.pumpAndSettle();
    expect(find.text('Résumé ouvert'), findsOneWidget);
  });

  testWidgets('exports and deletes a journey after confirmation', (tester) async {
    var records = [journey()];
    var exported = false;
    var deleted = false;
    await tester.pumpWidget(app(MonEntrepriseParcoursLibraryPage(
      showCredits: false,
      loadLibrary: () async => records,
      exportJourney: (_) async {
        exported = true;
        return true;
      },
      deleteJourney: (_) async {
        deleted = true;
        records = [];
      },
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('PDF'));
    await tester.pumpAndSettle();
    expect(exported, isTrue);
    expect(find.text('PDF généré et téléchargé.'), findsOneWidget);

    await tester.tap(find.byTooltip('Supprimer'));
    await tester.pumpAndSettle();
    expect(find.text('Supprimer ce parcours ?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
    await tester.pumpAndSettle();
    expect(deleted, isTrue);
    expect(find.textContaining('Aucun parcours sauvegardé'), findsOneWidget);
  });
}

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/account/mes_projets_fiche_page.dart';

void main() {
  Widget buildPage({
    required String? uid,
    required Stream<List<Map<String, dynamic>>> Function(String uid) loader,
  }) {
    return MaterialApp(
      home: MesProjetsFichePage(
        userIdProvider: () => uid,
        recordsStreamProvider: loader,
        toolboxPageBuilder: (_) => const Scaffold(
          body: Center(child: Text('Outil cible')),
        ),
      ),
    );
  }

  testWidgets('affiche l’état déconnecté sans ouvrir le flux', (tester) async {
    var loaderCalled = false;

    await tester.pumpWidget(
      buildPage(
        uid: null,
        loader: (_) {
          loaderCalled = true;
          return const Stream<List<Map<String, dynamic>>>.empty();
        },
      ),
    );

    expect(
      find.text('Connectez-vous pour accéder à vos projets.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.folder_off_rounded), findsOneWidget);
    expect(loaderCalled, isFalse);
  });

  testWidgets('affiche le chargement puis libère correctement le flux', (
    tester,
  ) async {
    final controller = StreamController<List<Map<String, dynamic>>>();

    await tester.pumpWidget(
      buildPage(uid: 'user-1', loader: (_) => controller.stream),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await controller.close();
    await tester.pump();
    expect(find.text('Aucun projet sauvegardé'), findsOneWidget);
  });

  testWidgets('affiche l’erreur du flux', (tester) async {
    await tester.pumpWidget(
      buildPage(
        uid: 'user-error',
        loader: (_) => Stream<List<Map<String, dynamic>>>.error(
          StateError('indisponible'),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Erreur de chargement'), findsOneWidget);
    expect(find.textContaining('indisponible'), findsOneWidget);
  });

  testWidgets('l’état vide ouvre la création de projet', (tester) async {
    await tester.pumpWidget(
      buildPage(
        uid: 'user-empty',
        loader: (_) => Stream.value(const <Map<String, dynamic>>[]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aucun projet sauvegardé'), findsOneWidget);
    expect(find.text('Démarrer un projet'), findsOneWidget);

    await tester.tap(find.text('Démarrer un projet'));
    await tester.pumpAndSettle();
    expect(find.text('Outil cible'), findsOneWidget);
  });

  testWidgets('le bouton app bar ouvre aussi la création', (tester) async {
    await tester.pumpWidget(
      buildPage(
        uid: null,
        loader: (_) => const Stream<List<Map<String, dynamic>>>.empty(),
      ),
    );

    await tester.tap(find.byTooltip('Nouveau projet'));
    await tester.pumpAndSettle();
    expect(find.text('Outil cible'), findsOneWidget);
  });

  testWidgets('rend les projets terminés et brouillons avec leurs fallbacks', (
    tester,
  ) async {
    final records = <Map<String, dynamic>>[
      <String, dynamic>{
        'data': <String, dynamic>{
          'projectText': 'Atelier créatif',
          'activityType': 'Artisanat',
          'territory': <String, dynamic>{'region': 'Guadeloupe'},
        },
        'status': 'completed',
        'updatedAt': Timestamp.fromDate(DateTime(2026, 7, 27, 14, 5)),
      },
      <String, dynamic>{
        'data': <String, dynamic>{
          'projectText': '   ',
          'activityType': '',
          'territory': <String, dynamic>{'region': ''},
        },
        'status': 'draft',
      },
    ];

    await tester.pumpWidget(
      buildPage(
        uid: 'user-projects',
        loader: (_) => Stream.value(records),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Atelier créatif'), findsOneWidget);
    expect(find.text('Artisanat · Guadeloupe'), findsOneWidget);
    expect(find.text('Terminé'), findsOneWidget);
    expect(find.text('Modifié le 27 juil 2026 à 14h05'), findsOneWidget);
    expect(find.text('Projet sans titre'), findsOneWidget);
    expect(find.text('Brouillon'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.byIcon(Icons.edit_note_rounded), findsOneWidget);

    await tester.tap(find.text('Atelier créatif'));
    await tester.pumpAndSettle();
    expect(find.text('Outil cible'), findsOneWidget);
  });
}

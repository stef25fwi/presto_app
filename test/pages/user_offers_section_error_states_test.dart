import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/user_offers_section.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    ),
  );
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxFrames = 120,
}) async {
  for (var frame = 0; frame < maxFrames; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  fail('Widget attendu introuvable après $maxFrames frames: $finder');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  testWidgets(
    'affiche un indicateur pendant le premier chargement avec un utilisateur non vide',
    (tester) async {
      await tester.pumpWidget(
        _wrap(const UserOffersSection(userId: 'user-error-state')),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Mes annonces publiées'), findsNothing);
    },
  );

  testWidgets(
    'affiche la carte erreur et permet de relancer le chargement quand Firestore echoue',
    (tester) async {
      await tester.pumpWidget(
        _wrap(const UserOffersSection(userId: 'user-error-state')),
      );
      await _pumpUntilFound(tester, find.text('Réessayer'));

      expect(find.text('Mes annonces publiées'), findsOneWidget);
      expect(
        find.textContaining('Impossible de charger vos annonces'),
        findsOneWidget,
      );
      expect(find.text('Réessayer'), findsOneWidget);

      await tester.tap(find.text('Réessayer'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await _pumpUntilFound(tester, find.text('Réessayer'));
      expect(find.text('Mes annonces publiées'), findsOneWidget);
      expect(
        find.textContaining('Impossible de charger vos annonces'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'masque la section quand un utilisateur non vide devient vide',
    (tester) async {
      final key = GlobalKey();

      await tester.pumpWidget(
        _wrap(UserOffersSection(key: key, userId: 'user-error-state')),
      );
      await _pumpUntilFound(tester, find.text('Réessayer'));
      expect(find.text('Mes annonces publiées'), findsOneWidget);

      await tester.pumpWidget(
        _wrap(UserOffersSection(key: key, userId: '')),
      );
      await tester.pump();

      expect(find.text('Mes annonces publiées'), findsNothing);
      expect(find.text('Réessayer'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

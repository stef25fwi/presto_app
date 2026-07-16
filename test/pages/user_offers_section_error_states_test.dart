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
        _wrap(const UserOffersSection(userId: 'user-loading-state')),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Mes annonces publiées'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'masque immédiatement la section quand un utilisateur non vide devient vide',
    (tester) async {
      final key = GlobalKey();

      await tester.pumpWidget(
        _wrap(UserOffersSection(key: key, userId: 'user-loading-state')),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpWidget(
        _wrap(UserOffersSection(key: key, userId: '')),
      );
      await tester.pump();

      expect(find.text('Mes annonces publiées'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reste masquée pour un identifiant utilisateur vide dès le premier rendu',
    (tester) async {
      await tester.pumpWidget(
        _wrap(const UserOffersSection(userId: '')),
      );
      await tester.pump();

      expect(find.text('Mes annonces publiées'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

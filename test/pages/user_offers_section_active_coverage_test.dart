import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/user_offers_section.dart';

Widget _app(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    ),
  );
}

Future<void> _drainBackendAttempt(WidgetTester tester) async {
  for (var i = 0; i < 20; i += 1) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  testWidgets('annonces actives terminent proprement le chargement sans backend natif',
      (tester) async {
    await tester.pumpWidget(
      _app(const UserOffersSection(userId: 'coverage-user-1')),
    );
    await _drainBackendAttempt(tester);

    final hasError = find.text('Mes annonces publiées').evaluate().isNotEmpty;
    final hasEmpty =
        find.text('Tu n’as pas encore d’annonce à gérer.').evaluate().isNotEmpty;

    expect(hasError || hasEmpty, isTrue);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);

    if (hasError) {
      final retry = find.text('Réessayer');
      expect(retry, findsOneWidget);
      await tester.tap(retry);
      await tester.pump();
      await _drainBackendAttempt(tester);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('changement utilisateur actif relance le cycle et se dispose proprement',
      (tester) async {
    final key = GlobalKey();

    await tester.pumpWidget(
      _app(UserOffersSection(key: key, userId: 'coverage-user-a')),
    );
    await _drainBackendAttempt(tester);

    await tester.pumpWidget(
      _app(UserOffersSection(key: key, userId: 'coverage-user-b', showTitle: false)),
    );
    await _drainBackendAttempt(tester);

    await tester.pumpWidget(_app(const SizedBox.shrink()));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('favoris actifs gèrent aussi leur échec backend et leur retry',
      (tester) async {
    await tester.pumpWidget(
      _app(const FavoriteOffersSection(userId: 'coverage-favorite-user')),
    );
    await _drainBackendAttempt(tester);

    final hasError = find.text('Mes annonces favorites').evaluate().isNotEmpty &&
        find.text('Réessayer').evaluate().isNotEmpty;
    final hasEmpty = find
        .text('Vous n’avez pas encore ajoute d’annonces favorites.')
        .evaluate()
        .isNotEmpty;

    expect(hasError || hasEmpty, isTrue);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);

    if (hasError) {
      await tester.tap(find.text('Réessayer'));
      await tester.pump();
      await _drainBackendAttempt(tester);
      expect(tester.takeException(), isNull);
    }
  });
}

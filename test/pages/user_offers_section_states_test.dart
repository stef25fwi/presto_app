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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  testWidgets('les favoris demandent une connexion sans identifiant',
      (tester) async {
    await tester.pumpWidget(
      _app(const FavoriteOffersSection(userId: '')),
    );
    await tester.pump();

    expect(
      find.text('Connectez-vous pour voir vos favoris.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('les favoris traitent un identifiant composé d espaces',
      (tester) async {
    await tester.pumpWidget(
      _app(const FavoriteOffersSection(userId: '   ', showTitle: false)),
    );
    await tester.pump();

    expect(
      find.text('Connectez-vous pour voir vos favoris.'),
      findsOneWidget,
    );
    expect(find.text('Mes annonces favorites'), findsNothing);
  });

  testWidgets('un changement d identifiant vide recharge l état des favoris',
      (tester) async {
    final key = GlobalKey();

    await tester.pumpWidget(
      _app(FavoriteOffersSection(key: key, userId: '')),
    );
    await tester.pump();

    await tester.pumpWidget(
      _app(FavoriteOffersSection(key: key, userId: '   ')),
    );
    await tester.pump();

    expect(
      find.text('Connectez-vous pour voir vos favoris.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('la gestion des annonces reste masquée sans utilisateur',
      (tester) async {
    await tester.pumpWidget(
      _app(const UserOffersSection(userId: '')),
    );
    await tester.pump();

    expect(find.text('Gérer mes annonces'), findsNothing);
    expect(find.text('Tu n’as pas encore d’annonce à gérer.'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(SizedBox), findsWidgets);
  });

  testWidgets('la gestion des annonces normalise un identifiant vide',
      (tester) async {
    final key = GlobalKey();

    await tester.pumpWidget(
      _app(UserOffersSection(key: key, userId: '')),
    );
    await tester.pump();

    await tester.pumpWidget(
      _app(UserOffersSection(key: key, userId: '   ', showTitle: false)),
    );
    await tester.pump();

    expect(find.text('Gérer mes annonces'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('les deux sections annulent proprement leurs abonnements',
      (tester) async {
    await tester.pumpWidget(
      _app(
        const Column(
          children: [
            FavoriteOffersSection(userId: ''),
            UserOffersSection(userId: ''),
          ],
        ),
      ),
    );
    await tester.pump();

    await tester.pumpWidget(_app(const SizedBox.shrink()));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}

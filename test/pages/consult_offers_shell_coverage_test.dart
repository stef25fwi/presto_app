import 'dart:async';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/consult_offers_page.dart';

class _SignedOutConsultAuthPlatform extends FirebaseAuthPlatform {
  _SignedOutConsultAuthPlatform() : super(appInstance: null);

  final StreamController<UserPlatform?> _authController =
      StreamController<UserPlatform?>.broadcast();
  final StreamController<UserPlatform?> _idTokenController =
      StreamController<UserPlatform?>.broadcast();
  final StreamController<UserPlatform?> _userController =
      StreamController<UserPlatform?>.broadcast();

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) =>
      this;

  @override
  UserPlatform? get currentUser => null;

  @override
  Stream<UserPlatform?> authStateChanges() => _authController.stream;

  @override
  Stream<UserPlatform?> idTokenChanges() => _idTokenController.stream;

  @override
  Stream<UserPlatform?> userChanges() => _userController.stream;

  Future<void> close() async {
    await _authController.close();
    await _idTokenController.close();
    await _userController.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _SignedOutConsultAuthPlatform authPlatform;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    authPlatform = _SignedOutConsultAuthPlatform();
    FirebaseAuthPlatform.instance = authPlatform;
  });

  tearDownAll(() async {
    await authPlatform.close();
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    String? categoryFilter,
    String? searchQuery,
  }) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ConsultOffersPage(
          categoryFilter: categoryFilter,
          searchQuery: searchQuery,
        ),
      ),
    );
    // Les lectures Firestore du shell sont asynchrones et leurs erreurs sont
    // gérées par la page. Quelques frames suffisent pour exercer l'UI sans
    // attendre un backend réel.
    for (var i = 0; i < 5; i += 1) {
      await tester.pump(const Duration(milliseconds: 80));
    }
  }

  testWidgets('recherche initiale affiche son filtre actif puis le réinitialise',
      (tester) async {
    await pumpPage(tester, searchQuery: 'plomberie urgente');

    expect(find.text('Je consulte les offres'), findsOneWidget);
    expect(find.text('Filtres'), findsOneWidget);
    expect(find.text('Recherche: plomberie urgente'), findsOneWidget);
    expect(find.text('Réinitialiser'), findsOneWidget);

    await tester.tap(find.text('Filtres'));
    await tester.pump();
    expect(find.byType(TextField), findsWidgets);

    // Referme puis exerce la suppression globale de tous les critères.
    await tester.tap(find.text('Filtres'));
    await tester.pump();
    await tester.tap(find.text('Réinitialiser'));
    await tester.pump();

    expect(find.text('Recherche: plomberie urgente'), findsNothing);
    expect(find.text('Réinitialiser'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('catégorie initiale construit le titre et la puce catégorie',
      (tester) async {
    await pumpPage(tester, categoryFilter: 'Bricolage');

    expect(find.textContaining('Offres :'), findsOneWidget);
    expect(find.textContaining('Catégorie:'), findsOneWidget);
    expect(find.text('Filtres'), findsOneWidget);
    expect(find.byType(InputChip), findsWidgets);

    // Supprime directement la puce catégorie pour couvrir la mutation locale.
    final chip = tester.widget<InputChip>(find.byType(InputChip).first);
    chip.onDeleted?.call();
    await tester.pump();

    expect(find.text('Je consulte les offres'), findsOneWidget);
    expect(find.byType(InputChip), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sans filtre conserve le panneau replié et se dispose proprement',
      (tester) async {
    await pumpPage(tester);

    expect(find.text('Je consulte les offres'), findsOneWidget);
    expect(find.text('Filtres'), findsOneWidget);
    expect(find.byType(InputChip), findsNothing);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });
}

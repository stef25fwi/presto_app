import 'dart:async';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/pro_profile_page.dart';

class _SignedOutProAuthPlatform extends FirebaseAuthPlatform {
  _SignedOutProAuthPlatform() : super(appInstance: null);

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

  Future<void> disposeControllers() async {
    await _authController.close();
    await _idTokenController.close();
    await _userController.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _SignedOutProAuthPlatform authPlatform;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    authPlatform = _SignedOutProAuthPlatform();
    FirebaseAuthPlatform.instance = authPlatform;
  });

  tearDownAll(() async {
    await authPlatform.disposeControllers();
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    String? initialSiret = '12345678901234',
    String? initialCompanyName = '  Société Test  ',
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ProProfilePage(
          initialSiret: initialSiret,
          initialCompanyName: initialCompanyName,
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
  }

  Finder textFieldWithLabel(String label) => find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == label,
      );

  String fieldValue(WidgetTester tester, String label) {
    final field = tester.widget<TextField>(textFieldWithLabel(label));
    return field.controller?.text ?? '';
  }

  Future<void> scrollTo(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
  }

  testWidgets('affiche tout le formulaire et normalise les valeurs initiales',
      (tester) async {
    await pumpPage(tester);

    expect(find.text('Profil Pro'), findsOneWidget);
    expect(
      find.text('Vérifiez votre SIRET pour valider le compte professionnel.'),
      findsOneWidget,
    );
    expect(find.text('Vérification entreprise'), findsOneWidget);
    expect(find.text('Activité'), findsOneWidget);
    expect(find.text('Contact'), findsOneWidget);

    expect(textFieldWithLabel('SIRET *'), findsOneWidget);
    expect(textFieldWithLabel("Nom officiel de l'entreprise"), findsOneWidget);
    expect(textFieldWithLabel('SIREN'), findsOneWidget);
    expect(textFieldWithLabel('Code NAF'), findsOneWidget);
    expect(textFieldWithLabel('Activité / secteur *'), findsOneWidget);
    expect(textFieldWithLabel('Email *'), findsOneWidget);

    expect(fieldValue(tester, 'SIRET *'), '12345678901234');
    expect(fieldValue(tester, "Nom officiel de l'entreprise"), 'Société Test');
    expect(tester.takeException(), isNull);
  });

  testWidgets('la vérification SIRET déconnectée affiche le message dédié',
      (tester) async {
    await pumpPage(tester);

    final verifyButton = find.text('Vérifier mon SIRET');
    expect(verifyButton, findsOneWidget);
    await tester.tap(verifyButton);
    await tester.pump();

    expect(
      find.text('Connectez-vous avant de vérifier le SIRET.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('valide les champs requis puis bloque un SIRET non vérifié',
      (tester) async {
    await pumpPage(tester);

    final saveButton = find.text('Enregistrer mon Profil Pro');
    await scrollTo(tester, saveButton);
    await tester.tap(saveButton);
    await tester.pump();

    expect(find.text('Obligatoire'), findsNWidgets(2));
    expect(find.text('Email invalide'), findsOneWidget);

    await tester.enterText(
      textFieldWithLabel('Activité / secteur *'),
      'Services numériques',
    );
    await tester.enterText(
      textFieldWithLabel('Nom du contact *'),
      'Stéphane Test',
    );
    await tester.enterText(
      textFieldWithLabel('Email *'),
      'contact@example.test',
    );

    await scrollTo(tester, saveButton);
    await tester.tap(saveButton);
    await tester.pump();

    expect(
      find.text(
        'Vérifiez votre SIRET avant d’enregistrer le profil professionnel.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('filtre le SIRET et permet de basculer les conditions',
      (tester) async {
    await pumpPage(tester, initialSiret: null, initialCompanyName: null);

    final siret = textFieldWithLabel('SIRET *');
    await tester.enterText(siret, '12ab34567890123456');
    await tester.pump();
    expect(fieldValue(tester, 'SIRET *'), '12345678901234');

    final termsText = find.text(
      "J'accepte les conditions d'utilisation professionnelles",
    );
    await scrollTo(tester, termsText);

    CheckboxListTile termsTile() =>
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile));

    expect(termsTile().value, isFalse);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    expect(termsTile().value, isTrue);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    expect(termsTile().value, isFalse);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

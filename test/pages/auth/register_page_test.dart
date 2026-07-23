import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/operating_mode/app_operating_mode.dart';
import 'package:presto_app/pages/auth/register_page.dart';
import 'package:presto_app/pages/legal_info_page.dart';

void main() {
  Future<void> pumpRegister(
    WidgetTester tester, {
    RegisterPage page = const RegisterPage(),
  }) async {
    tester.view.physicalSize = const Size(430, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: page));
    await tester.pump();
  }

  Finder field(String label) {
    final decorator = find.byWidgetPredicate(
      (widget) =>
          widget is InputDecorator && widget.decoration.labelText == label,
    );
    return find.descendant(of: decorator, matching: find.byType(EditableText));
  }

  Future<void> acceptLegal(WidgetTester tester) async {
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
  }

  Future<void> fillBase(WidgetTester tester) async {
    await tester.enterText(field('Nom *'), 'Durand');
    await tester.enterText(field('Prénom *'), 'Lina');
    await tester.enterText(field('Pseudo'), 'Lina');
    await tester.enterText(field('Email'), 'lina@example.com');
    await tester.enterText(field('Mot de passe'), 'Password1');
    await acceptLegal(tester);
  }

  testWidgets('affiche le formulaire particulier complet', (tester) async {
    await pumpRegister(tester);

    expect(find.text('Bienvenue sur Prestō'), findsOneWidget);
    expect(find.text('Particulier'), findsOneWidget);
    expect(field('Nom *'), findsOneWidget);
    expect(field('Prénom *'), findsOneWidget);
    expect(field('Pseudo'), findsOneWidget);
    expect(field('Email'), findsOneWidget);
    expect(field('Mot de passe'), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
    expect(find.text('Créer mon compte'), findsOneWidget);
  });

  testWidgets('bloque la création sans acceptation juridique', (tester) async {
    await pumpRegister(tester);
    await tester.tap(find.text('Créer mon compte'));
    await tester.pump();

    expect(
      find.text(
        'Veuillez accepter les CGU et la politique de confidentialité.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('affiche toutes les erreurs après acceptation', (tester) async {
    await pumpRegister(tester);
    await acceptLegal(tester);
    await tester.tap(find.text('Créer mon compte'));
    await tester.pump();

    expect(find.text('Nom obligatoire'), findsOneWidget);
    expect(find.text('Prénom obligatoire'), findsOneWidget);
    expect(
      find.text('Pseudo obligatoire (2 caractères minimum).'),
      findsOneWidget,
    );
    expect(find.text('Email obligatoire.'), findsOneWidget);
    expect(find.text('8 caractères minimum.'), findsOneWidget);
  });

  testWidgets('valide les limites du pseudo et le format email', (tester) async {
    await pumpRegister(tester);
    await fillBase(tester);

    await tester.enterText(field('Pseudo'), 'a');
    await tester.enterText(field('Email'), 'adresse-invalide');
    await tester.tap(find.text('Créer mon compte'));
    await tester.pump();
    expect(
      find.text('Pseudo obligatoire (2 caractères minimum).'),
      findsOneWidget,
    );
    expect(find.text('Email invalide.'), findsOneWidget);

    await tester.enterText(field('Pseudo'), 'a' * 31);
    await tester.tap(find.text('Créer mon compte'));
    await tester.pump();
    expect(
      find.text('Pseudo trop long (30 caractères maximum).'),
      findsOneWidget,
    );
  });

  testWidgets('valide lettre et chiffre du mot de passe', (tester) async {
    await pumpRegister(tester);
    await fillBase(tester);

    await tester.enterText(field('Mot de passe'), '12345678');
    await tester.tap(find.text('Créer mon compte'));
    await tester.pump();
    expect(find.text('Ajoute au moins une lettre.'), findsOneWidget);

    await tester.enterText(field('Mot de passe'), 'abcdefgh');
    await tester.tap(find.text('Créer mon compte'));
    await tester.pump();
    expect(find.text('Ajoute au moins un chiffre.'), findsOneWidget);
  });

  testWidgets('bascule la visibilité du mot de passe', (tester) async {
    await pumpRegister(tester);

    EditableText passwordField() =>
        tester.widget<EditableText>(field('Mot de passe'));

    expect(passwordField().obscureText, isTrue);
    await tester.tap(find.byIcon(Icons.visibility));
    await tester.pump();
    expect(passwordField().obscureText, isFalse);
    expect(find.byIcon(Icons.visibility_off), findsOneWidget);
  });

  testWidgets('soumet, enregistre la version juridique puis navigue',
      (tester) async {
    final submission = Completer<void>();
    final captured = <String, String>{};
    AppOperatingModeState? acceptedState;

    await pumpRegister(
      tester,
      page: RegisterPage(
        registerWithEmail: ({
          required email,
          required password,
          required displayName,
          required fullName,
          required firstName,
          required lastName,
          required pseudo,
        }) async {
          captured.addAll(<String, String>{
            'email': email,
            'password': password,
            'displayName': displayName,
            'fullName': fullName,
            'firstName': firstName,
            'lastName': lastName,
            'pseudo': pseudo,
          });
          await submission.future;
        },
        recordLegalAcceptance: (state) async {
          acceptedState = state;
        },
        successPageBuilder: (_) => const Scaffold(
          body: Text('Vérification test'),
        ),
      ),
    );

    await tester.enterText(field('Nom *'), '  Durand  ');
    await tester.enterText(field('Prénom *'), '  Lina  ');
    await tester.enterText(field('Pseudo'), '  Lina D  ');
    await tester.enterText(field('Email'), '  lina@example.com  ');
    await tester.enterText(field('Mot de passe'), 'Password1');
    await acceptLegal(tester);
    await tester.tap(find.text('Créer mon compte'));
    await tester.pump();

    expect(captured, <String, String>{
      'email': '  lina@example.com  ',
      'password': 'Password1',
      'displayName': 'Lina D',
      'fullName': 'Lina Durand',
      'firstName': 'Lina',
      'lastName': 'Durand',
      'pseudo': 'Lina D',
    });
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    submission.complete();
    await tester.pumpAndSettle();

    expect(acceptedState?.mode, AppOperatingMode.freeBeta);
    expect(acceptedState?.cguVersion, 'cgu-beta-free-v1');
    expect(find.text('Vérification test'), findsOneWidget);
    expect(find.byType(RegisterPage), findsNothing);
  });

  testWidgets('affiche l erreur Firebase et réactive la soumission',
      (tester) async {
    await pumpRegister(
      tester,
      page: RegisterPage(
        registerWithEmail: ({
          required email,
          required password,
          required displayName,
          required fullName,
          required firstName,
          required lastName,
          required pseudo,
        }) async {
          throw FirebaseAuthException(code: 'email-already-in-use');
        },
      ),
    );
    await fillBase(tester);

    await tester.tap(find.text('Créer mon compte'));
    await tester.pumpAndSettle();

    expect(
      find.text('Cette adresse email est déjà associée à un compte.'),
      findsOneWidget,
    );
    expect(find.byType(RegisterPage), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('ouvre les mentions légales sur le bon onglet', (tester) async {
    await pumpRegister(tester);
    await tester.tap(find.text('Mentions légales'));
    await tester.pumpAndSettle();

    expect(find.byType(LegalInfoPage), findsOneWidget);
    expect(
      tester.widget<LegalInfoPage>(find.byType(LegalInfoPage)).initialTab,
      0,
    );
  });
}

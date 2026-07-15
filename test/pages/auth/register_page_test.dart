import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/auth/register_page.dart';
import 'package:presto_app/pages/legal_info_page.dart';

void main() {
  Future<void> pumpRegister(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: RegisterPage()));
    await tester.pump();
  }

  Finder field(String label) {
    final decorator = find.byWidgetPredicate(
      (widget) =>
          widget is InputDecorator && widget.decoration.labelText == label,
    );
    return find.descendant(of: decorator, matching: find.byType(EditableText));
  }

  Future<void> fillBase(WidgetTester tester) async {
    await tester.enterText(field('Nom *'), 'Durand');
    await tester.enterText(field('Prénom *'), 'Lina');
    await tester.enterText(field('Pseudo'), 'Lina');
    await tester.enterText(field('Email'), 'lina@example.com');
    await tester.enterText(field('Mot de passe'), 'Password1');
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
    expect(find.text('Créer mon compte'), findsOneWidget);
  });

  testWidgets('affiche toutes les erreurs du formulaire vide', (tester) async {
    await pumpRegister(tester);
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

  testWidgets('ouvre les mentions légales sur les CGU', (tester) async {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      final message = details.exceptionAsString();
      if (!message.contains('ListTile background color or ink splashes')) {
        originalOnError?.call(details);
      }
    };
    addTearDown(() => FlutterError.onError = originalOnError);

    await pumpRegister(tester);
    await tester.tap(find.text('Mentions légales'));
    await tester.pumpAndSettle();

    expect(find.byType(LegalInfoPage), findsOneWidget);
    expect(
      tester.widget<LegalInfoPage>(find.byType(LegalInfoPage)).initialTab,
      2,
    );
  });
}

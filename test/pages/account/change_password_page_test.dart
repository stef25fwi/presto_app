import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/account/change_password_page.dart';

void main() {
  Widget buildPage(ChangePasswordAction action) {
    return MaterialApp(
      home: ChangePasswordPage(onChangePassword: action),
    );
  }

  testWidgets('affiche le formulaire et permet de révéler les mots de passe',
      (tester) async {
    await tester.pumpWidget(
      buildPage(
        ({required currentPassword, required newPassword}) async {},
      ),
    );

    expect(find.text('Changer mot de passe'), findsOneWidget);
    expect(find.text('Mot de passe actuel'), findsOneWidget);
    expect(find.text('Nouveau mot de passe'), findsOneWidget);
    expect(find.text('Modifier'), findsOneWidget);

    final fields = find.byType(TextFormField);
    expect(tester.widget<TextFormField>(fields.at(0)).obscureText, isTrue);
    expect(tester.widget<TextFormField>(fields.at(1)).obscureText, isTrue);

    await tester.tap(find.byIcon(Icons.visibility).first);
    await tester.pump();
    expect(tester.widget<TextFormField>(fields.at(0)).obscureText, isFalse);

    await tester.tap(find.byIcon(Icons.visibility).last);
    await tester.pump();
    expect(tester.widget<TextFormField>(fields.at(1)).obscureText, isFalse);
  });

  testWidgets('valide les champs avant d’appeler le service', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      buildPage(
        ({required currentPassword, required newPassword}) async {
          calls += 1;
        },
      ),
    );

    await tester.tap(find.text('Modifier'));
    await tester.pump();
    expect(find.text('Mot de passe actuel obligatoire.'), findsOneWidget);
    expect(find.text('8 caractères minimum.'), findsOneWidget);
    expect(calls, 0);

    await tester.enterText(find.byType(TextFormField).at(0), 'Ancien123');
    await tester.enterText(find.byType(TextFormField).at(1), '12345678');
    await tester.tap(find.text('Modifier'));
    await tester.pump();
    expect(find.text('Ajoute au moins une lettre.'), findsOneWidget);
    expect(calls, 0);

    await tester.enterText(find.byType(TextFormField).at(1), 'abcdefgh');
    await tester.tap(find.text('Modifier'));
    await tester.pump();
    expect(find.text('Ajoute au moins un chiffre.'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets('transmet les valeurs, affiche le chargement puis ferme la page',
      (tester) async {
    final completer = Completer<void>();
    String? receivedCurrent;
    String? receivedNew;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ChangePasswordPage(
                      onChangePassword: ({
                        required currentPassword,
                        required newPassword,
                      }) {
                        receivedCurrent = currentPassword;
                        receivedNew = newPassword;
                        return completer.future;
                      },
                    ),
                  ),
                );
              },
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Ancien123');
    await tester.enterText(find.byType(TextFormField).at(1), 'Nouveau456');
    await tester.tap(find.text('Modifier'));
    await tester.pump();

    expect(receivedCurrent, 'Ancien123');
    expect(receivedNew, 'Nouveau456');
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );

    completer.complete();
    await tester.pumpAndSettle();

    expect(find.text('Changer mot de passe'), findsNothing);
    expect(find.text('Mot de passe modifié.'), findsOneWidget);
  });

  testWidgets('affiche l’erreur Firebase sans fermer la page', (tester) async {
    await tester.pumpWidget(
      buildPage(
        ({required currentPassword, required newPassword}) async {
          throw FirebaseAuthException(code: 'wrong-password');
        },
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'Erreur123');
    await tester.enterText(find.byType(TextFormField).at(1), 'Nouveau456');
    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();

    expect(find.text('Changer mot de passe'), findsOneWidget);
    expect(find.text('Email ou mot de passe incorrect.'), findsOneWidget);
    expect(find.text('Modifier'), findsOneWidget);
  });
}

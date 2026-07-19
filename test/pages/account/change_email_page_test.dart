import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/account/change_email_page.dart';

void main() {
  Future<void> openPage(
    WidgetTester tester, {
    ChangeEmailRequest? requestEmailChange,
    ChangeEmailErrorMessageMapper? errorMessageMapper,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              key: const Key('open-change-email'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ChangeEmailPage(
                      requestEmailChange: requestEmailChange,
                      errorMessageMapper: errorMessageMapper,
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
    await tester.tap(find.byKey(const Key('open-change-email')));
    await tester.pumpAndSettle();
  }

  Finder get emailField => find.byType(TextFormField).at(0);
  Finder get passwordField => find.byType(TextFormField).at(1);
  Finder get submitButton => find.text('Envoyer le lien de validation');

  testWidgets('valide les deux champs avant tout appel', (tester) async {
    var calls = 0;
    await openPage(
      tester,
      requestEmailChange: ({
        required String currentPassword,
        required String newEmail,
      }) async {
        calls += 1;
      },
    );

    await tester.tap(submitButton);
    await tester.pump();

    expect(find.text('Nouvel email obligatoire.'), findsOneWidget);
    expect(find.text('Mot de passe obligatoire.'), findsOneWidget);
    expect(calls, 0);

    await tester.enterText(emailField, 'email-invalide');
    await tester.enterText(passwordField, 'mot-de-passe');
    await tester.tap(submitButton);
    await tester.pump();

    expect(find.text('Email invalide.'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets('affiche puis masque le mot de passe', (tester) async {
    await openPage(tester);

    expect(
      tester.widget<TextFormField>(passwordField).obscureText,
      isTrue,
    );
    expect(find.byIcon(Icons.visibility), findsOneWidget);

    await tester.tap(find.byIcon(Icons.visibility));
    await tester.pump();

    expect(
      tester.widget<TextFormField>(passwordField).obscureText,
      isFalse,
    );
    expect(find.byIcon(Icons.visibility_off), findsOneWidget);
  });

  testWidgets('affiche le chargement puis revient après succès', (tester) async {
    final completer = Completer<void>();
    String? receivedPassword;
    String? receivedEmail;
    await openPage(
      tester,
      requestEmailChange: ({
        required String currentPassword,
        required String newEmail,
      }) async {
        receivedPassword = currentPassword;
        receivedEmail = newEmail;
        await completer.future;
      },
    );

    await tester.enterText(emailField, 'nouveau@ilipresto.fr');
    await tester.enterText(passwordField, 'secret-actuel');
    await tester.tap(submitButton);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(receivedPassword, 'secret-actuel');
    expect(receivedEmail, 'nouveau@ilipresto.fr');

    completer.complete();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('open-change-email')), findsOneWidget);
    expect(
      find.text('Lien de validation envoyé au nouvel email.'),
      findsOneWidget,
    );
  });

  testWidgets('affiche l erreur mappée et conserve la page', (tester) async {
    var calls = 0;
    await openPage(
      tester,
      requestEmailChange: ({
        required String currentPassword,
        required String newEmail,
      }) async {
        calls += 1;
        throw StateError('backend indisponible');
      },
      errorMessageMapper: (error) => 'Erreur de changement maîtrisée.',
    );

    await tester.enterText(emailField, 'nouveau@ilipresto.fr');
    await tester.enterText(passwordField, 'secret-actuel');
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.text('Changer mon email'), findsOneWidget);
    expect(find.text('Erreur de changement maîtrisée.'), findsOneWidget);
    expect(submitButton, findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}

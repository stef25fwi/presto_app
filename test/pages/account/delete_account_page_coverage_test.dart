import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/account/delete_account_page.dart';

Widget _host(DeleteAccountPage page) => MaterialApp(home: page);

Future<void> _enterConfirmation(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Tape SUPPRIMER'),
    'SUPPRIMER',
  );
}

void main() {
  testWidgets('compte mot de passe affiche les deux confirmations et validations',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(_host(DeleteAccountPage(
      usesPasswordProviderOverride: true,
      deleteAccountAction: ({password}) async => calls++,
    )));

    expect(find.text('Supprimer mon compte'), findsOneWidget);
    expect(find.text('Mot de passe'), findsOneWidget);
    expect(find.text('Tape SUPPRIMER'), findsOneWidget);
    expect(find.byTooltip('Afficher le mot de passe'), findsOneWidget);

    await tester.tap(find.text('Supprimer définitivement'));
    await tester.pump();

    expect(find.text('Mot de passe obligatoire.'), findsOneWidget);
    expect(find.text('Tape SUPPRIMER pour confirmer.'), findsOneWidget);
    expect(calls, 0);

    await tester.tap(find.byTooltip('Afficher le mot de passe'));
    await tester.pump();
    expect(find.byTooltip('Masquer le mot de passe'), findsOneWidget);
  });

  testWidgets('compte mot de passe transmet le secret exact et revient à la racine',
      (tester) async {
    String? receivedPassword;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => DeleteAccountPage(
                usesPasswordProviderOverride: true,
                deleteAccountAction: ({password}) async {
                  receivedPassword = password;
                },
              ),
            )),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mot de passe'),
      'Secret123!',
    );
    await _enterConfirmation(tester);
    await tester.tap(find.text('Supprimer définitivement'));
    await tester.pumpAndSettle();

    expect(receivedPassword, 'Secret123!');
    expect(find.text('Ouvrir'), findsOneWidget);
    expect(find.text('Supprimer mon compte'), findsNothing);
  });

  testWidgets('compte social masque le mot de passe et transmet null',
      (tester) async {
    Object? receivedPassword = Object();
    await tester.pumpWidget(_host(DeleteAccountPage(
      usesPasswordProviderOverride: false,
      deleteAccountAction: ({password}) async {
        receivedPassword = password;
      },
    )));

    expect(find.text('Mot de passe'), findsNothing);
    expect(find.textContaining('une réauthentification peut s’ouvrir'),
        findsOneWidget);

    await _enterConfirmation(tester);
    await tester.tap(find.text('Supprimer définitivement'));
    await tester.pumpAndSettle();

    expect(receivedPassword, isNull);
  });

  testWidgets('chargement verrouille le bouton jusqu à la fin', (tester) async {
    final completer = Completer<void>();
    await tester.pumpWidget(_host(DeleteAccountPage(
      usesPasswordProviderOverride: false,
      deleteAccountAction: ({password}) => completer.future,
    )));

    await _enterConfirmation(tester);
    await tester.tap(find.text('Supprimer définitivement'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);

    completer.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('erreur Firebase affiche le message utilisateur et réactive le bouton',
      (tester) async {
    await tester.pumpWidget(_host(DeleteAccountPage(
      usesPasswordProviderOverride: false,
      deleteAccountAction: ({password}) async {
        throw FirebaseAuthException(code: 'requires-recent-login');
      },
    )));

    await _enterConfirmation(tester);
    await tester.tap(find.text('Supprimer définitivement'));
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNotNull);
  });
}

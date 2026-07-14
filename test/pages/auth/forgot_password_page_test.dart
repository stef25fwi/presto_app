import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/auth/forgot_password_page.dart';

void main() {
  Widget app(Widget child) => MaterialApp(home: child);

  testWidgets('ForgotPasswordPage affiche le contenu principal', (tester) async {
    await tester.pumpWidget(app(const ForgotPasswordPage()));

    expect(find.text('Mot de passe oublié'), findsOneWidget);
    expect(find.text('Réinitialiser le mot de passe'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Envoyer le lien'), findsOneWidget);
    expect(find.byIcon(Icons.lock_reset), findsOneWidget);
  });

  testWidgets('ForgotPasswordPage valide les emails obligatoires et invalides',
      (tester) async {
    var resetCalled = false;

    await tester.pumpWidget(
      app(
        ForgotPasswordPage(
          sendPasswordReset: ({required String email}) async {
            resetCalled = true;
          },
        ),
      ),
    );

    await tester.tap(find.text('Envoyer le lien'));
    await tester.pump();

    expect(find.text('Email obligatoire.'), findsOneWidget);
    expect(resetCalled, isFalse);

    await tester.enterText(find.byType(TextFormField), 'email-invalide');
    await tester.tap(find.text('Envoyer le lien'));
    await tester.pump();

    expect(find.text('Email invalide.'), findsOneWidget);
    expect(resetCalled, isFalse);
  });

  testWidgets('ForgotPasswordPage envoie un email trimme puis navigue',
      (tester) async {
    String? sentEmail;

    await tester.pumpWidget(
      app(
        ForgotPasswordPage(
          sendPasswordReset: ({required String email}) async {
            sentEmail = email;
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField), '  test@exemple.fr  ');
    await tester.tap(find.text('Envoyer le lien'));
    await tester.pumpAndSettle();

    expect(sentEmail, 'test@exemple.fr');
    expect(find.text('Email envoyé'), findsOneWidget);
    expect(find.text('Vérifie ta boîte email'), findsOneWidget);
    expect(find.textContaining('test@exemple.fr'), findsOneWidget);
  });

  testWidgets('ForgotPasswordPage affiche une erreur mapped en SnackBar',
      (tester) async {
    await tester.pumpWidget(
      app(
        ForgotPasswordPage(
          sendPasswordReset: ({required String email}) async {
            throw StateError('smtp unavailable');
          },
          errorMessageMapper: (_) => 'Erreur reset test',
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField), 'test@exemple.fr');
    await tester.tap(find.text('Envoyer le lien'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Erreur reset test'), findsOneWidget);
  });
}

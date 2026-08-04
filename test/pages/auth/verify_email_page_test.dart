import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/auth/verify_email_page.dart';

void main() {
  Widget app(Widget child) => MaterialApp(home: child);

  VerifyEmailPage page({
    Future<bool> Function()? checkEmailVerified,
    Future<void> Function()? resendVerificationEmail,
    Future<void> Function()? signOut,
    String Function(Object error)? errorMessageMapper,
  }) {
    return VerifyEmailPage(
      email: 'test@exemple.fr',
      initialCooldownSeconds: 0,
      checkEmailVerified: checkEmailVerified ?? () async => false,
      resendVerificationEmail: resendVerificationEmail ?? () async {},
      signOut: signOut ?? () async {},
      errorMessageMapper: errorMessageMapper,
    );
  }

  testWidgets('VerifyEmailPage affiche email, actions et resend disponible',
      (tester) async {
    await tester.pumpWidget(app(page()));

    expect(find.text('Confirmez votre adresse e-mail'), findsOneWidget);
    expect(find.text('Validation de l’adresse requise'), findsOneWidget);
    expect(find.textContaining('test@exemple.fr'), findsOneWidget);
    expect(find.textContaining('iliprestō'), findsOneWidget);
    expect(find.text('J’ai validé mon adresse e-mail'), findsOneWidget);
    expect(find.text('Renvoyer l’e-mail'), findsOneWidget);
    expect(find.text('Déconnexion'), findsOneWidget);
    expect(find.byIcon(Icons.verified_user), findsOneWidget);
  });

  testWidgets('VerifyEmailPage affiche le succes quand email verifie',
      (tester) async {
    var checked = false;

    await tester.pumpWidget(
      app(
        page(
          checkEmailVerified: () async {
            checked = true;
            return true;
          },
        ),
      ),
    );

    await tester.tap(find.text('J’ai validé mon adresse e-mail'));
    await tester.pumpAndSettle();

    expect(checked, isTrue);
    expect(find.text('Adresse e-mail validée avec succès.'), findsOneWidget);
  });

  testWidgets('VerifyEmailPage affiche le message non verifie', (tester) async {
    await tester.pumpWidget(
      app(
        page(
          checkEmailVerified: () async => false,
        ),
      ),
    );

    await tester.tap(find.text('J’ai validé mon adresse e-mail'));
    await tester.pumpAndSettle();

    expect(
      find.text('Adresse e-mail pas encore validée. Ouvrez le lien reçu.'),
      findsOneWidget,
    );
  });

  testWidgets('VerifyEmailPage renvoie le mail et affiche un SnackBar',
      (tester) async {
    var resent = false;

    await tester.pumpWidget(
      app(
        page(
          resendVerificationEmail: () async {
            resent = true;
          },
        ),
      ),
    );

    await tester.tap(find.text('Renvoyer l’e-mail'));
    await tester.pumpAndSettle();

    expect(resent, isTrue);
    expect(find.text('E-mail de confirmation renvoyé.'), findsOneWidget);
  });

  testWidgets('VerifyEmailPage mappe les erreurs de verification',
      (tester) async {
    await tester.pumpWidget(
      app(
        page(
          checkEmailVerified: () async {
            throw StateError('network');
          },
          errorMessageMapper: (_) => 'Erreur verify test',
        ),
      ),
    );

    await tester.tap(find.text('J’ai validé mon adresse e-mail'));
    await tester.pumpAndSettle();

    expect(find.text('Erreur verify test'), findsOneWidget);
  });

  testWidgets('VerifyEmailPage deconnecte avec le callback injecte',
      (tester) async {
    var signedOut = false;

    await tester.pumpWidget(
      app(
        page(
          signOut: () async {
            signedOut = true;
          },
        ),
      ),
    );

    await tester.tap(find.text('Déconnexion'));
    await tester.pumpAndSettle();

    expect(signedOut, isTrue);
  });
}

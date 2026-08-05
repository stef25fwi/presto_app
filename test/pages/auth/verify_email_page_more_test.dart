import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/auth/verify_email_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget host(VerifyEmailPage page) => MaterialApp(home: page);

  testWidgets('affiche l email explicite et termine le cooldown court',
      (tester) async {
    await tester.pumpWidget(
      host(
        VerifyEmailPage(
          email: '  test@ilipresto.fr  ',
          initialCooldownSeconds: 2,
          cooldownTick: const Duration(milliseconds: 10),
          checkEmailVerified: () async => false,
          resendVerificationEmail: () async {},
          signOut: () async {},
        ),
      ),
    );

    expect(find.textContaining('test@ilipresto.fr'), findsOneWidget);
    expect(find.text('Renvoyer dans 2 s'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 10));
    expect(find.text('Renvoyer dans 1 s'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 10));
    expect(find.text('Renvoyer l’e-mail'), findsOneWidget);
  });

  testWidgets('cooldown nul autorise immédiatement le renvoi réussi',
      (tester) async {
    var resendCalls = 0;
    await tester.pumpWidget(
      host(
        VerifyEmailPage(
          email: 'user@example.com',
          initialCooldownSeconds: 0,
          resendVerificationEmail: () async => resendCalls++,
          checkEmailVerified: () async => false,
          signOut: () async {},
        ),
      ),
    );

    await tester.tap(find.text('Renvoyer l’e-mail'));
    await tester.pump();

    expect(resendCalls, 1);
    expect(find.text('E-mail de confirmation renvoyé.'), findsOneWidget);
    expect(find.text('Renvoyer l’e-mail'), findsOneWidget);
  });

  testWidgets('erreur de renvoi utilise le mapper injecté', (tester) async {
    await tester.pumpWidget(
      host(
        VerifyEmailPage(
          email: 'user@example.com',
          initialCooldownSeconds: 0,
          resendVerificationEmail: () async => throw StateError('offline'),
          errorMessageMapper: (error) => 'RENVOI: $error',
          checkEmailVerified: () async => false,
          signOut: () async {},
        ),
      ),
    );

    await tester.tap(find.text('Renvoyer l’e-mail'));
    await tester.pump();

    expect(find.textContaining('RENVOI:'), findsOneWidget);
    expect(find.text('Renvoyer l’e-mail'), findsOneWidget);
  });

  testWidgets('déconnexion appelle le callback injecté', (tester) async {
    var signOutCalls = 0;
    await tester.pumpWidget(
      host(
        VerifyEmailPage(
          email: 'user@example.com',
          initialCooldownSeconds: 0,
          checkEmailVerified: () async => false,
          resendVerificationEmail: () async {},
          signOut: () async => signOutCalls++,
        ),
      ),
    );

    await tester.tap(find.text('Déconnexion'));
    await tester.pump();

    expect(signOutCalls, 1);
  });
}

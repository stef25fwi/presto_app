import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/account_page.dart';
import 'package:presto_app/pages/auth/login_page.dart';
import 'package:presto_app/services/auth_guard.dart';

void main() {
  Widget app({required Future<void> Function(BuildContext context) action}) {
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => action(context),
            child: const Text('Verifier'),
          ),
        ),
      ),
    );
  }

  testWidgets('redirige vers le compte sans utilisateur', (tester) async {
    bool? result;

    await tester.pumpWidget(
      app(
        action: (context) async {
          result = await AuthGuard.requireVerifiedEmail(
            context,
            identityReader: () => null,
            accountBuilder: (_) => const Scaffold(body: Text('ACCOUNT')),
          );
        },
      ),
    );

    await tester.tap(find.text('Verifier'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    expect(find.text('ACCOUNT'), findsOneWidget);
  });

  testWidgets('redirige un compte mot de passe non verifie', (tester) async {
    var reloadCalls = 0;
    var reads = 0;
    bool? result;

    AuthGuardIdentity identity({required bool verified}) {
      return AuthGuardIdentity(
        providerIds: const ['password'],
        emailVerified: verified,
        reload: () async => reloadCalls++,
      );
    }

    await tester.pumpWidget(
      app(
        action: (context) async {
          result = await AuthGuard.requireVerifiedEmail(
            context,
            identityReader: () {
              reads++;
              return identity(verified: false);
            },
            verifyEmailBuilder: (_) => const Scaffold(body: Text('VERIFY')),
          );
        },
      ),
    );

    await tester.tap(find.text('Verifier'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    expect(reloadCalls, 1);
    expect(reads, 2);
    expect(find.text('VERIFY'), findsOneWidget);
  });

  testWidgets('autorise un compte mot de passe verifie', (tester) async {
    bool? result;
    final identity = AuthGuardIdentity(
      providerIds: const ['password'],
      emailVerified: true,
      reload: () async {},
    );

    await tester.pumpWidget(
      app(
        action: (context) async {
          result = await AuthGuard.requireVerifiedEmail(
            context,
            identityReader: () => identity,
          );
        },
      ),
    );

    await tester.tap(find.text('Verifier'));
    await tester.pump();

    expect(result, isTrue);
    expect(find.text('Verifier'), findsOneWidget);
  });

  testWidgets('autorise un compte social non verifie', (tester) async {
    bool? result;
    final identity = AuthGuardIdentity(
      providerIds: const ['google.com'],
      emailVerified: false,
      reload: () async {},
    );

    await tester.pumpWidget(
      app(
        action: (context) async {
          result = await AuthGuard.requireVerifiedEmail(
            context,
            identityReader: () => identity,
          );
        },
      ),
    );

    await tester.tap(find.text('Verifier'));
    await tester.pump();

    expect(result, isTrue);
  });

  testWidgets('ne navigue pas avec un contexte deja demonte', (tester) async {
    late BuildContext staleContext;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            staleContext = context;
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));

    final result = await AuthGuard.requireVerifiedEmail(
      staleContext,
      identityReader: () => null,
    );

    expect(result, isFalse);
  });

  testWidgets('ignore la redirection verification apres demontage',
      (tester) async {
    late BuildContext guardedContext;
    final reloadCompleter = Completer<void>();
    final identity = AuthGuardIdentity(
      providerIds: const ['password'],
      emailVerified: false,
      reload: reloadCompleter.future,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            guardedContext = context;
            return const SizedBox();
          },
        ),
      ),
    );

    final future = AuthGuard.requireVerifiedEmail(
      guardedContext,
      identityReader: () => identity,
    );
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    reloadCompleter.complete();

    expect(await future, isFalse);
  });

  testWidgets('LoginPage conserve la route et construit AccountPage',
      (tester) async {
    Widget? built;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            built = const LoginPage().build(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(LoginPage.routeName, '/login');
    expect(built, isA<AccountPage>());
  });
}

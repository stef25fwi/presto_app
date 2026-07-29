import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/account/phone_verification_page.dart';
import 'package:presto_app/services/phone_verification_service.dart';

Future<void> _pumpPage(
  WidgetTester tester, {
  required PhoneVerificationService service,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: PhoneVerificationPage(
        phoneVerificationService: service,
        initialPhoneNumber: '',
      ),
    ),
  );
}

void main() {
  testWidgets('envoie le code puis confirme et referme la page', (tester) async {
    var sendCodeCalls = 0;
    var confirmCodeCalls = 0;
    final service = PhoneVerificationService(
      verifyStarter: ({
        required phoneNumber,
        required timeout,
        required verificationCompleted,
        required verificationFailed,
        required codeSent,
        required codeAutoRetrievalTimeout,
      }) async {
        sendCodeCalls++;
        codeSent('verification-id-1', null);
      },
      linker: (_) async {},
      confirmCaller: () async {
        confirmCodeCalls++;
        return <String, dynamic>{'ok': true};
      },
    );

    bool? poppedWith;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              poppedWith = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => PhoneVerificationPage(
                    phoneVerificationService: service,
                    initialPhoneNumber: '',
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Numéro de téléphone'),
      '+33612345678',
    );
    await tester.tap(find.text('Envoyer le code'));
    await tester.pumpAndSettle();

    expect(sendCodeCalls, 1);
    expect(find.text('Vérifier'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Code reçu par SMS'),
      '123456',
    );
    await tester.tap(find.text('Vérifier'));
    await tester.pumpAndSettle();

    expect(confirmCodeCalls, 1);
    expect(poppedWith, isTrue);
  });

  testWidgets('affiche une erreur lisible quand verificationFailed est déclenché', (
    tester,
  ) async {
    final service = PhoneVerificationService(
      verifyStarter: ({
        required phoneNumber,
        required timeout,
        required verificationCompleted,
        required verificationFailed,
        required codeSent,
        required codeAutoRetrievalTimeout,
      }) async {
        verificationFailed(
          FirebaseAuthException(code: 'invalid-phone-number'),
        );
      },
    );

    await _pumpPage(tester, service: service);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Numéro de téléphone'),
      '+33612345678',
    );
    await tester.tap(find.text('Envoyer le code'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Numéro de téléphone invalide'),
      findsOneWidget,
    );
    // On reste sur l'étape de saisie du numéro.
    expect(find.text('Envoyer le code'), findsOneWidget);
  });

  testWidgets('rejette un numéro qui ne respecte pas le format E.164', (
    tester,
  ) async {
    final service = PhoneVerificationService(
      verifyStarter: ({
        required phoneNumber,
        required timeout,
        required verificationCompleted,
        required verificationFailed,
        required codeSent,
        required codeAutoRetrievalTimeout,
      }) async {
        fail('verifyStarter ne doit pas être appelé pour un numéro invalide');
      },
    );

    await _pumpPage(tester, service: service);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Numéro de téléphone'),
      '0612345678',
    );
    await tester.tap(find.text('Envoyer le code'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Format attendu'), findsOneWidget);
  });

  testWidgets('le bouton renvoyer un code revient à la saisie du numéro', (
    tester,
  ) async {
    final service = PhoneVerificationService(
      verifyStarter: ({
        required phoneNumber,
        required timeout,
        required verificationCompleted,
        required verificationFailed,
        required codeSent,
        required codeAutoRetrievalTimeout,
      }) async {
        codeSent('verification-id-1', null);
      },
    );

    await _pumpPage(tester, service: service);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Numéro de téléphone'),
      '+33612345678',
    );
    await tester.tap(find.text('Envoyer le code'));
    await tester.pumpAndSettle();

    expect(find.text('Vérifier'), findsOneWidget);

    await tester.tap(find.text('Changer de numéro / renvoyer un code'));
    await tester.pumpAndSettle();

    expect(find.text('Envoyer le code'), findsOneWidget);
  });
}

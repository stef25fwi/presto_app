import 'package:cloud_functions/cloud_functions.dart';
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

PhoneAttemptReserver get _allowAttempt => (phoneNumber) async =>
    <String, dynamic>{'allowed': true, 'limited': true, 'dailyLimit': 1};

void main() {
  testWidgets('envoie le code puis confirme et referme la page', (tester) async {
    var sendCodeCalls = 0;
    var confirmCodeCalls = 0;
    final service = PhoneVerificationService(
      attemptReserver: _allowAttempt,
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
      '0612345678',
    );
    await tester.tap(find.text('Envoyer le code'));
    await tester.pumpAndSettle();

    expect(sendCodeCalls, 1);
    expect(find.text('Vérifier'), findsOneWidget);
    expect(find.textContaining('+33612345678'), findsOneWidget);

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
      attemptReserver: _allowAttempt,
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
      '0612345678',
    );
    await tester.tap(find.text('Envoyer le code'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Numéro de téléphone invalide'),
      findsOneWidget,
    );
    expect(find.textContaining('n’est pas décomptée'), findsOneWidget);
    expect(find.text('Envoyer le code'), findsOneWidget);
  });

  testWidgets('normalise un numéro national avant de réserver et envoyer', (
    tester,
  ) async {
    String? reservedPhone;
    String? sentPhone;
    final service = PhoneVerificationService(
      attemptReserver: (phoneNumber) async {
        reservedPhone = phoneNumber;
        return <String, dynamic>{'allowed': true, 'dailyLimit': 1};
      },
      verifyStarter: ({
        required phoneNumber,
        required timeout,
        required verificationCompleted,
        required verificationFailed,
        required codeSent,
        required codeAutoRetrievalTimeout,
      }) async {
        sentPhone = phoneNumber;
        codeSent('verification-id-1', null);
      },
    );

    await _pumpPage(tester, service: service);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Numéro de téléphone'),
      '06 12 34 56 78',
    );
    await tester.tap(find.text('Envoyer le code'));
    await tester.pumpAndSettle();

    expect(reservedPhone, '+33612345678');
    expect(sentPhone, '+33612345678');
  });

  testWidgets('bloque le second essai quand le quota serveur est épuisé', (
    tester,
  ) async {
    var verifyStarterCalled = false;
    final service = PhoneVerificationService(
      attemptReserver: (_) async {
        throw FirebaseFunctionsException(
          code: 'resource-exhausted',
          message: 'Quota SMS atteint',
          details: <String, dynamic>{
            'nextAllowedAt': '2026-08-10T12:00:00.000Z',
          },
        );
      },
      verifyStarter: ({
        required phoneNumber,
        required timeout,
        required verificationCompleted,
        required verificationFailed,
        required codeSent,
        required codeAutoRetrievalTimeout,
      }) async {
        verifyStarterCalled = true;
      },
    );

    await _pumpPage(tester, service: service);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Numéro de téléphone'),
      '0612345678',
    );
    await tester.tap(find.text('Envoyer le code'));
    await tester.pumpAndSettle();

    expect(verifyStarterCalled, isFalse);
    expect(find.textContaining('Quota atteint'), findsOneWidget);
    expect(find.textContaining('1 tentative SMS'), findsOneWidget);
  });

  testWidgets('le bouton changer de numéro revient à la saisie', (
    tester,
  ) async {
    final service = PhoneVerificationService(
      attemptReserver: _allowAttempt,
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
      '0612345678',
    );
    await tester.tap(find.text('Envoyer le code'));
    await tester.pumpAndSettle();

    expect(find.text('Vérifier'), findsOneWidget);

    await tester.tap(find.text('Changer de numéro'));
    await tester.pumpAndSettle();

    expect(find.text('Envoyer le code'), findsOneWidget);
  });
}

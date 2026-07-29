import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/phone_verification_service.dart';

void main() {
  group('PhoneVerificationService', () {
    test('sendCode transmet le numéro et relaie codeSent', () async {
      String? capturedPhoneNumber;
      String? codeSentId;

      final service = PhoneVerificationService(
        verifyStarter: ({
          required phoneNumber,
          required timeout,
          required verificationCompleted,
          required verificationFailed,
          required codeSent,
          required codeAutoRetrievalTimeout,
        }) async {
          capturedPhoneNumber = phoneNumber;
          codeSent('verification-id-1', null);
        },
      );

      await service.sendCode(
        phoneNumber: '+33612345678',
        onCodeSent: (id) => codeSentId = id,
        onFailed: (_) => fail('onFailed ne doit pas être appelé'),
        onAutoVerified: () async => fail('onAutoVerified ne doit pas être appelé'),
      );

      expect(capturedPhoneNumber, '+33612345678');
      expect(codeSentId, 'verification-id-1');
    });

    test('sendCode relaie verificationFailed', () async {
      FirebaseAuthException? capturedError;

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

      await service.sendCode(
        phoneNumber: 'invalide',
        onCodeSent: (_) => fail('onCodeSent ne doit pas être appelé'),
        onFailed: (error) => capturedError = error,
        onAutoVerified: () async => fail('onAutoVerified ne doit pas être appelé'),
      );

      expect(capturedError?.code, 'invalid-phone-number');
    });

    test(
      'sendCode déclenche onAutoVerified quand la vérification est automatique',
      () async {
        var linkedCredentialCount = 0;
        var confirmed = false;
        var autoVerifiedCalled = false;

        final service = PhoneVerificationService(
          verifyStarter: ({
            required phoneNumber,
            required timeout,
            required verificationCompleted,
            required verificationFailed,
            required codeSent,
            required codeAutoRetrievalTimeout,
          }) async {
            verificationCompleted(
              PhoneAuthProvider.credential(
                verificationId: 'auto-id',
                smsCode: '123456',
              ),
            );
          },
          linker: (_) async => linkedCredentialCount++,
          confirmCaller: () async {
            confirmed = true;
            return <String, dynamic>{'ok': true};
          },
        );

        await service.sendCode(
          phoneNumber: '+33612345678',
          onCodeSent: (_) => fail('onCodeSent ne doit pas être appelé'),
          onFailed: (_) => fail('onFailed ne doit pas être appelé'),
          onAutoVerified: () async {
            autoVerifiedCalled = true;
            await service.confirmServerSide();
          },
        );

        expect(linkedCredentialCount, 1);
        expect(autoVerifiedCalled, isTrue);
        expect(confirmed, isTrue);
      },
    );

    test('confirmCode lie le credential puis confirme côté serveur', () async {
      PhoneAuthCredential? capturedCredential;
      Map<String, dynamic>? capturedParametersUnused;

      final service = PhoneVerificationService(
        linker: (credential) async {
          capturedCredential = credential;
        },
        confirmCaller: () async {
          capturedParametersUnused = <String, dynamic>{};
          return <String, dynamic>{'ok': true, 'phone': '+33612345678'};
        },
      );

      final result = await service.confirmCode(
        verificationId: 'verification-id-1',
        smsCode: '654321',
      );

      expect(result, isTrue);
      expect(capturedCredential, isNotNull);
      expect(capturedParametersUnused, isNotNull);
    });

    test('confirmServerSide retourne false pour une réponse négative', () async {
      final service = PhoneVerificationService(
        confirmCaller: () async => <String, dynamic>{'ok': false},
      );

      expect(await service.confirmServerSide(), isFalse);
    });

    test('confirmServerSide tolère une réponse vide', () async {
      final service = PhoneVerificationService(confirmCaller: () async => null);

      expect(await service.confirmServerSide(), isFalse);
    });
  });
}

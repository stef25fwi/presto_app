import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/phone_verification_service.dart';

void main() {
  group('PhoneVerificationService', () {
    test('reserveDailyAttempt transmet le numéro au contrôle serveur', () async {
      String? capturedPhoneNumber;
      final service = PhoneVerificationService(
        attemptReserver: (phoneNumber) async {
          capturedPhoneNumber = phoneNumber;
          return <String, dynamic>{
            'allowed': true,
            'limited': true,
            'dailyLimit': 1,
          };
        },
      );

      final result = await service.reserveDailyAttempt(
        phoneNumber: '+590690123456',
      );

      expect(capturedPhoneNumber, '+590690123456');
      expect(result['allowed'], isTrue);
      expect(result['dailyLimit'], 1);
    });

    test('verificationFailed libère la réservation avant de relayer l’erreur', () async {
      final events = <String>[];
      final service = PhoneVerificationService(
        attemptReserver: (_) async => <String, dynamic>{
          'allowed': true,
          'limited': true,
          'dailyLimit': 1,
          'reservationId': 'reservation_12345',
        },
        attemptReleaser: (reservationId, reason) async {
          events.add('release:$reservationId:$reason');
          return <String, dynamic>{'released': true};
        },
        attemptCommitter: (_) async {
          fail('La réservation ne doit pas être commit avant codeSent.');
        },
        verifyStarter: ({
          required phoneNumber,
          required timeout,
          required verificationCompleted,
          required verificationFailed,
          required codeSent,
          required codeAutoRetrievalTimeout,
        }) async {
          verificationFailed(
            FirebaseAuthException(code: 'captcha-check-failed'),
          );
        },
      );

      await service.reserveDailyAttempt(phoneNumber: '+590690123456');
      await service.sendCode(
        phoneNumber: '+590690123456',
        onCodeSent: (_) => fail('codeSent ne doit pas être appelé'),
        onFailed: (error) => events.add('failed:${error.code}'),
        onAutoVerified: () async => fail('auto verification inattendue'),
      );

      expect(
        events,
        <String>[
          'release:reservation_12345:firebase_captcha-check-failed',
          'failed:captcha-check-failed',
        ],
      );
    });

    test('codeSent commit la réservation et ne la libère pas', () async {
      String? committedReservationId;
      var released = false;
      final service = PhoneVerificationService(
        attemptReserver: (_) async => <String, dynamic>{
          'allowed': true,
          'limited': true,
          'dailyLimit': 1,
          'reservationId': 'reservation_67890',
        },
        attemptCommitter: (reservationId) async {
          committedReservationId = reservationId;
          return <String, dynamic>{'committed': true};
        },
        attemptReleaser: (_, __) async {
          released = true;
          return <String, dynamic>{'released': true};
        },
        verifyStarter: ({
          required phoneNumber,
          required timeout,
          required verificationCompleted,
          required verificationFailed,
          required codeSent,
          required codeAutoRetrievalTimeout,
        }) async {
          codeSent('verification-id-sent', null);
        },
      );

      await service.reserveDailyAttempt(phoneNumber: '+590690123456');
      await service.sendCode(
        phoneNumber: '+590690123456',
        onCodeSent: (_) {},
        onFailed: (_) => fail('onFailed ne doit pas être appelé'),
        onAutoVerified: () async => fail('auto verification inattendue'),
      );

      expect(committedReservationId, 'reservation_67890');
      expect(released, isFalse);
    });

    test('une exception Firebase immédiate libère aussi la réservation', () async {
      String? releasedReservationId;
      String? failureCode;
      final service = PhoneVerificationService(
        attemptReserver: (_) async => <String, dynamic>{
          'allowed': true,
          'limited': true,
          'dailyLimit': 1,
          'reservationId': 'reservation_54321',
        },
        attemptReleaser: (reservationId, _) async {
          releasedReservationId = reservationId;
          return <String, dynamic>{'released': true};
        },
        verifyStarter: ({
          required phoneNumber,
          required timeout,
          required verificationCompleted,
          required verificationFailed,
          required codeSent,
          required codeAutoRetrievalTimeout,
        }) async {
          throw FirebaseAuthException(code: 'app-not-authorized');
        },
      );

      await service.reserveDailyAttempt(phoneNumber: '+590690123456');
      await service.sendCode(
        phoneNumber: '+590690123456',
        onCodeSent: (_) => fail('codeSent ne doit pas être appelé'),
        onFailed: (error) => failureCode = error.code,
        onAutoVerified: () async => fail('auto verification inattendue'),
      );

      expect(releasedReservationId, 'reservation_54321');
      expect(failureCode, 'app-not-authorized');
    });

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

    test(
      'sendCode fixe le timeout et ignore la fin de récupération auto',
      () async {
        Duration? capturedTimeout;

        final service = PhoneVerificationService(
          verifyStarter: ({
            required phoneNumber,
            required timeout,
            required verificationCompleted,
            required verificationFailed,
            required codeSent,
            required codeAutoRetrievalTimeout,
          }) async {
            capturedTimeout = timeout;
            codeAutoRetrievalTimeout('verification-id-timeout');
          },
        );

        await service.sendCode(
          phoneNumber: '+33600000000',
          onCodeSent: (_) => fail('onCodeSent ne doit pas être appelé'),
          onFailed: (_) => fail('onFailed ne doit pas être appelé'),
          onAutoVerified: () async =>
              fail('onAutoVerified ne doit pas être appelé'),
        );

        expect(capturedTimeout, const Duration(seconds: 60));
      },
    );

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

    test('sendCode relaie une erreur Firebase du lien automatique', () async {
      final failure = Completer<FirebaseAuthException>();

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
              verificationId: 'auto-link-error',
              smsCode: '123456',
            ),
          );
        },
        linker: (_) async {
          throw FirebaseAuthException(code: 'provider-already-linked');
        },
      );

      await service.sendCode(
        phoneNumber: '+33612345678',
        onCodeSent: (_) => fail('onCodeSent ne doit pas être appelé'),
        onFailed: (error) {
          if (!failure.isCompleted) {
            failure.complete(error);
          }
        },
        onAutoVerified: () async =>
            fail('onAutoVerified ne doit pas être appelé'),
      );

      final capturedError = await failure.future.timeout(
        const Duration(seconds: 1),
      );
      expect(capturedError.code, 'provider-already-linked');
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

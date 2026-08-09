import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/phone_verification_service.dart';

void main() {
  test('verificationCompleted reste accepté après codeSent', () async {
    final autoVerified = Completer<void>();
    var codeSentCount = 0;
    var linkCount = 0;

    final service = PhoneVerificationService(
      attemptReserver: (_) async => <String, dynamic>{
        'allowed': true,
        'limited': true,
        'dailyLimit': 1,
        'reservationId': 'sequence-reservation',
      },
      attemptCommitter: (_) async => <String, dynamic>{'committed': true},
      linker: (_) async => linkCount++,
      verifyStarter: ({
        required phoneNumber,
        required timeout,
        required verificationCompleted,
        required verificationFailed,
        required codeSent,
        required codeAutoRetrievalTimeout,
      }) async {
        codeSent('sequence-verification-id', null);
        verificationCompleted(
          PhoneAuthProvider.credential(
            verificationId: 'sequence-verification-id',
            smsCode: '123456',
          ),
        );
      },
    );

    await service.reserveDailyAttempt(phoneNumber: '+590690123456');
    await service.sendCode(
      phoneNumber: '+590690123456',
      onCodeSent: (_) => codeSentCount++,
      onFailed: (error) => fail('Erreur inattendue : ${error.code}'),
      onAutoVerified: () async {
        if (!autoVerified.isCompleted) autoVerified.complete();
      },
    );

    await autoVerified.future.timeout(const Duration(seconds: 1));
    expect(codeSentCount, 1);
    expect(linkCount, 1);
  });
}

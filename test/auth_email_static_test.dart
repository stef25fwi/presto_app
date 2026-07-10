import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Auth email / connexion static checks', () {
    String read(String path) => File(path).readAsStringSync();

    test('tests inscription register createUserWithEmailAndPassword', () {
      final auth = read('lib/services/auth_service.dart');

      expect(auth, contains('registerWithEmail'));
      expect(auth, contains('createUserWithEmailAndPassword'));
      expect(auth, contains('sendEmailVerification'));
      expect(auth, contains("collection('users')"));
    });

    test('tests connexion signInWithEmailAndPassword', () {
      final auth = read('lib/services/auth_service.dart');

      expect(auth, contains('signInWithEmail'));
      expect(auth, contains('signInWithEmailAndPassword'));
      expect(auth, contains('lastLoginAt'));
    });

    test('tests mot de passe oublié sendPasswordResetEmail', () {
      final auth = read('lib/services/auth_service.dart');
      final page = read('lib/pages/auth/forgot_password_page.dart');

      expect(auth, contains('sendPasswordResetEmail'));
      expect(page, contains('ForgotPasswordPage'));
    });

    test('tests email non vérifié VerifyEmailPage AuthGuard', () {
      final guard = read('lib/services/auth_guard.dart');
      final page = read('lib/pages/auth/verify_email_page.dart');

      expect(guard, contains('requireVerifiedEmail'));
      expect(guard, contains('emailVerified'));
      expect(page, contains('VerifyEmailPage'));
    });

    test('tests email vérifié checkEmailVerified', () {
      final auth = read('lib/services/auth_service.dart');

      expect(auth, contains('checkEmailVerified'));
      expect(auth, contains('syncEmailVerifiedToFirestore'));
    });

    test('tests suppression compte deleteCurrentAccount', () {
      final auth = read('lib/services/auth_service.dart');
      final page = read('lib/pages/account/delete_account_page.dart');

      expect(auth, contains('deleteCurrentAccount'));
      expect(auth, contains("name: 'requestAccountDeletion'"));
      expect(auth, isNot(contains('await user.delete()')));
      expect(page, contains('SUPPRIMER'));
    });
  });
}

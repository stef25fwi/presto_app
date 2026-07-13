import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/auth/validators/auth_validators.dart';

void main() {
  group('displayName', () {
    test('refuse vide et trop court', () {
      expect(AuthValidators.displayName(null), 'Indiquez votre nom ou pseudo.');
      expect(AuthValidators.displayName(' '), 'Indiquez votre nom ou pseudo.');
      expect(
        AuthValidators.displayName('A'),
        'Le nom doit contenir au moins 2 caractères.',
      );
    });

    test('accepte une valeur normalisée', () {
      expect(AuthValidators.displayName(' Alice '), isNull);
    });
  });

  group('firstName', () {
    test('refuse vide et trop court', () {
      expect(AuthValidators.firstName(null), 'Le prénom est obligatoire.');
      expect(
        AuthValidators.firstName('A'),
        'Le prénom doit contenir au moins 2 caractères.',
      );
    });

    test('accepte un prénom valide', () {
      expect(AuthValidators.firstName(' Ana '), isNull);
    });
  });

  group('lastName', () {
    test('refuse vide et trop court', () {
      expect(AuthValidators.lastName(' '), 'Le nom est obligatoire.');
      expect(
        AuthValidators.lastName('B'),
        'Le nom doit contenir au moins 2 caractères.',
      );
    });

    test('accepte un nom valide', () {
      expect(AuthValidators.lastName(' Durand '), isNull);
    });
  });

  group('email', () {
    test('refuse les formats invalides', () {
      for (final value in <String?>[null, '', 'test', 'a@b', 'a b@c.fr']) {
        expect(AuthValidators.email(value), 'Adresse email invalide.');
      }
    });

    test('accepte une adresse valide normalisée', () {
      expect(AuthValidators.email(' user@example.com '), isNull);
    });
  });

  group('password', () {
    test('refuse vide et trop court', () {
      expect(AuthValidators.password(null), 'Mot de passe obligatoire.');
      expect(
        AuthValidators.password('1234567'),
        'Le mot de passe doit contenir au moins 8 caractères.',
      );
    });

    test('accepte huit caractères', () {
      expect(AuthValidators.password('12345678'), isNull);
    });
  });

  group('passwordConfirmation', () {
    test('réutilise la validation du mot de passe', () {
      expect(
        AuthValidators.passwordConfirmation('', '12345678'),
        'Mot de passe obligatoire.',
      );
    });

    test('refuse une confirmation différente', () {
      expect(
        AuthValidators.passwordConfirmation('abcdefgh', '12345678'),
        'Les mots de passe ne correspondent pas.',
      );
    });

    test('accepte une confirmation identique', () {
      expect(
        AuthValidators.passwordConfirmation('12345678', '12345678'),
        isNull,
      );
    });
  });
}

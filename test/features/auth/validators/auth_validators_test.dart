import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/auth/validators/auth_validators.dart';

void main() {
  group('AuthValidators.displayName', () {
    test('rejette les valeurs absentes, vides et trop courtes', () {
      expect(AuthValidators.displayName(null), 'Indiquez votre nom ou pseudo.');
      expect(AuthValidators.displayName('   '), 'Indiquez votre nom ou pseudo.');
      expect(
        AuthValidators.displayName(' A '),
        'Le nom doit contenir au moins 2 caractères.',
      );
    });

    test('accepte une valeur normalisée valide', () {
      expect(AuthValidators.displayName(' Stef '), isNull);
    });
  });

  group('AuthValidators.firstName', () {
    test('rejette les valeurs absentes, vides et trop courtes', () {
      expect(AuthValidators.firstName(null), 'Le prénom est obligatoire.');
      expect(AuthValidators.firstName('   '), 'Le prénom est obligatoire.');
      expect(
        AuthValidators.firstName(' A '),
        'Le prénom doit contenir au moins 2 caractères.',
      );
    });

    test('accepte un prénom valide', () {
      expect(AuthValidators.firstName(' Hema '), isNull);
    });
  });

  group('AuthValidators.lastName', () {
    test('rejette les valeurs absentes, vides et trop courtes', () {
      expect(AuthValidators.lastName(null), 'Le nom est obligatoire.');
      expect(AuthValidators.lastName('   '), 'Le nom est obligatoire.');
      expect(
        AuthValidators.lastName(' B '),
        'Le nom doit contenir au moins 2 caractères.',
      );
    });

    test('accepte un nom valide', () {
      expect(AuthValidators.lastName(' Brieux '), isNull);
    });
  });

  group('AuthValidators.email', () {
    test('rejette les valeurs absentes, vides ou mal formées', () {
      for (final value in <String?>[
        null,
        '',
        '   ',
        'stef',
        'stef@',
        '@ilipresto.fr',
        'stef@ilipresto',
        'stef @ilipresto.fr',
      ]) {
        expect(
          AuthValidators.email(value),
          'Adresse email invalide.',
          reason: 'value=$value',
        );
      }
    });

    test('accepte une adresse valide après trim', () {
      expect(AuthValidators.email(' stef@ilipresto.fr '), isNull);
    });
  });

  group('AuthValidators.password', () {
    test('rejette un mot de passe absent ou vide', () {
      expect(AuthValidators.password(null), 'Mot de passe obligatoire.');
      expect(AuthValidators.password(''), 'Mot de passe obligatoire.');
    });

    test('rejette un mot de passe trop court', () {
      expect(
        AuthValidators.password('1234567'),
        'Le mot de passe doit contenir au moins 8 caractères.',
      );
    });

    test('accepte huit caractères ou plus', () {
      expect(AuthValidators.password('12345678'), isNull);
      expect(AuthValidators.password('mot-de-passe-solide'), isNull);
    });
  });

  group('AuthValidators.passwordConfirmation', () {
    test('propage les erreurs du validateur de mot de passe', () {
      expect(
        AuthValidators.passwordConfirmation(null, '12345678'),
        'Mot de passe obligatoire.',
      );
      expect(
        AuthValidators.passwordConfirmation('123', '12345678'),
        'Le mot de passe doit contenir au moins 8 caractères.',
      );
    });

    test('rejette une confirmation différente', () {
      expect(
        AuthValidators.passwordConfirmation('12345678', 'abcdefgh'),
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

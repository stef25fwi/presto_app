abstract final class AuthValidators {
  static final RegExp _emailPattern = RegExp(
    r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
  );

  static String? displayName(String? value) {
    final normalized = (value ?? '').trim();
    if (normalized.isEmpty) {
      return 'Indiquez votre nom ou pseudo.';
    }
    if (normalized.length < 2) {
      return 'Le nom doit contenir au moins 2 caractères.';
    }
    return null;
  }

  static String? firstName(String? value) {
    final normalized = (value ?? '').trim();
    if (normalized.isEmpty) {
      return 'Le prénom est obligatoire.';
    }
    if (normalized.length < 2) {
      return 'Le prénom doit contenir au moins 2 caractères.';
    }
    return null;
  }

  static String? lastName(String? value) {
    final normalized = (value ?? '').trim();
    if (normalized.isEmpty) {
      return 'Le nom est obligatoire.';
    }
    if (normalized.length < 2) {
      return 'Le nom doit contenir au moins 2 caractères.';
    }
    return null;
  }

  static String? email(String? value) {
    final normalized = (value ?? '').trim();
    if (normalized.isEmpty || !_emailPattern.hasMatch(normalized)) {
      return 'Adresse email invalide.';
    }
    return null;
  }

  static String? password(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return 'Mot de passe obligatoire.';
    }
    if (password.length < 8) {
      return 'Le mot de passe doit contenir au moins 8 caractères.';
    }
    return null;
  }

  static String? passwordConfirmation(String? value, String password) {
    final passwordError = AuthValidators.password(value);
    if (passwordError != null) return passwordError;
    if ((value ?? '') != password) {
      return 'Les mots de passe ne correspondent pas.';
    }
    return null;
  }
}

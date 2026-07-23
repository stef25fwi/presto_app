import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/account_social_auth_actions.dart';

void main() {
  tearDown(AccountSocialAuthActions.resetTestingOverrides);

  test('génère des nonces de la longueur demandée avec le charset autorisé', () {
    final nonce = AccountSocialAuthActions.generateNonceForTesting(96);
    final allowed = RegExp(r'^[0-9A-Za-z._-]+$');

    expect(nonce, hasLength(96));
    expect(allowed.hasMatch(nonce), isTrue);
    expect(AccountSocialAuthActions.generateNonceForTesting(0), isEmpty);
  });

  test('calcule le SHA-256 attendu', () {
    expect(
      AccountSocialAuthActions.sha256OfStringForTesting('ilipresto'),
      'c370bf4c36d8dcd2b188d9029c861e55d27651d5ff5a936f577214fb1f0ae188',
    );
  });

  test('construit un fournisseur Google prêt pour la sélection de compte', () {
    final provider = AccountSocialAuthActions.buildGoogleProviderForTesting();

    expect(provider.providerId, 'google.com');
    expect(provider.scopes, containsAll(<String>['email', 'profile']));
    expect(provider.parameters['prompt'], 'select_account');
  });

  test('classe les erreurs nécessitant un redirect', () {
    expect(
      AccountSocialAuthActions.shouldFallbackToRedirectForTesting(
        StateError('popup_closed_by_browser'),
      ),
      isTrue,
    );
    expect(
      AccountSocialAuthActions.shouldFallbackToRedirectForTesting(
        StateError('erreur métier sans rapport'),
      ),
      isFalse,
    );
  });
}

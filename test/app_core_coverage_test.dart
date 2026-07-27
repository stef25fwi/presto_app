import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/app_core.dart';

void main() {
  tearDown(() {
    SessionState.userId = null;
    SessionState.userEmail = null;
  });

  group('règles de publication', () {
    test('retourne null pour une entrée vide ou sans correspondance', () {
      expect(resolvePublishCategoryPairFromText('   '), isNull);
      expect(resolvePublishCategoryPairFromText('promenade tranquille'), isNull);
    });

    test('normalise le texte et choisit le mot-clé le plus précis', () {
      final match = resolvePublishCategoryPairFromText(
        'Besoin d’un agent de SÉCURITÉ événementielle !',
      );

      expect(match, isNotNull);
      expect(match!.category, "Main-d'oeuvre");
      expect(match.subCategory, 'Vigile / sécurité événementielle');
      expect(match.suggestedTitle, 'Vigile / sécurité événementielle');
      expect(match.matchedKeyword, 'securite evenementielle');
    });

    test('résout les travaux de plomberie avec accents et ponctuation', () {
      final match = resolvePublishCategoryPairFromText(
        'Urgent : canalisation bouchée et fuite d’eau.',
      );

      expect(match, isNotNull);
      expect(match!.category, 'Bricolage / Travaux');
      expect(match.subCategory, 'Petits travaux plomberie');
      expect(match.suggestedTitle, 'Petits travaux plomberie');
      expect(match.matchedKeyword, 'canalisation');
    });
  });

  test('gère le cycle complet de session et notifie les auditeurs', () {
    final state = SessionState();
    var notifications = 0;
    state.addListener(() => notifications++);

    expect(state.isLoggedIn, isFalse);
    expect(state.email, isNull);

    state.logInDemo();
    expect(state.isLoggedIn, isTrue);
    expect(state.email, 'demo@ilipresto.app');
    expect(state.displayName, 'Compte démo');

    state.updateUser(
      id: 'user-42',
      email: 'personne@ilipresto.fr',
      name: 'Personne',
    );
    expect(SessionState.userId, 'user-42');
    expect(state.email, 'personne@ilipresto.fr');
    expect(state.displayName, 'Personne');

    state.logOut();
    expect(state.isLoggedIn, isFalse);
    expect(state.email, isNull);
    expect(state.displayName, isNull);
    expect(notifications, 3);
  });
}

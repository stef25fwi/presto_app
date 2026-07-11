import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/data/marketplace/chat_request_policy.dart';

void main() {
  const policy = ChatRequestPolicy();

  group('ChatRequestPolicy', () {
    test('normalise les identifiants', () {
      expect(
        policy.normalizeIdentifier('  listing-42  ', fieldName: 'listingId'),
        'listing-42',
      );
    });

    test('refuse un identifiant vide', () {
      expect(
        () => policy.normalizeIdentifier('   ', fieldName: 'threadId'),
        throwsA(isA<ChatRequestException>()),
      );
    });

    test('normalise un message valide', () {
      expect(policy.normalizeMessage('  Bonjour  '), 'Bonjour');
    });

    test('refuse un message vide ou supérieur à 2000 caractères', () {
      expect(
        () => policy.normalizeMessage('   '),
        throwsA(isA<ChatRequestException>()),
      );
      expect(
        () => policy.normalizeMessage('a' * 2001),
        throwsA(isA<ChatRequestException>()),
      );
    });

    test('accepte exactement 2000 caractères', () {
      expect(policy.normalizeMessage('a' * 2000).length, 2000);
    });

    test('lit threadId et l alias conversationId', () {
      expect(policy.extractThreadId({'threadId': ' t-1 '}), 't-1');
      expect(policy.extractThreadId({'conversationId': ' c-1 '}), 'c-1');
    });

    test('refuse une réponse backend sans identifiant de conversation', () {
      expect(
        () => policy.extractThreadId({'ok': true}),
        throwsA(isA<ChatRequestException>()),
      );
      expect(
        () => policy.extractThreadId(null),
        throwsA(isA<ChatRequestException>()),
      );
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/models/conversation_summary.dart';

void main() {
  test(
      'injecte un participant suppose pour les conversations recuperees par fallback',
      () {
    final summary = ConversationSummary.fromMap(
      'conversation_123',
      <String, dynamic>{
        'offerTitle': 'Annonce test',
      },
      assumedParticipants: const <String>['user_1'],
    );

    expect(summary.includesUser('user_1'), isTrue);
    expect(summary.participants, <String>['user_1']);
  });

  test('fusionne les versions pauvre et riche d une meme conversation', () {
    final fallbackSummary = ConversationSummary.fromMap(
      'conversation_123',
      <String, dynamic>{
        'offerTitle': 'Annonce test',
        'updatedAt': DateTime(2026, 4, 3, 10).millisecondsSinceEpoch,
      },
      assumedParticipants: const <String>['buyer_1'],
    );

    final liveSummary = ConversationSummary.fromMap(
      'conversation_123',
      <String, dynamic>{
        'participants': <String>['buyer_1', 'seller_1'],
        'participantNames': <String, dynamic>{
          'buyer_1': 'Acheteur',
          'seller_1': 'Vendeur',
        },
        'lastMessage': 'Bonjour',
        'lastSenderId': 'seller_1',
        'messageCount': 1,
        'lastMessageAt': DateTime(2026, 4, 3, 11).millisecondsSinceEpoch,
      },
    );

    final merged = fallbackSummary.mergeWith(liveSummary);

    expect(merged.includesUser('buyer_1'), isTrue);
    expect(merged.participants, <String>['buyer_1', 'seller_1']);
    expect(merged.offerTitle, 'Annonce test');
    expect(merged.lastMessage, 'Bonjour');
    expect(merged.messageCount, 1);
    expect(merged.titleFor('buyer_1'), 'Vendeur');
  });

  test('lit les champs listingId et listingTitle canoniques', () {
    final summary = ConversationSummary.fromMap(
      'conversation_456',
      <String, dynamic>{
        'participantIds': <String>['buyer_1', 'seller_1'],
        'listingId': 'listing_456',
        'listingTitle': 'Montage de cuisine',
      },
    );

    expect(summary.offerId, 'listing_456');
    expect(summary.offerTitle, 'Montage de cuisine');
    expect(summary.participants, <String>['buyer_1', 'seller_1']);
  });
}

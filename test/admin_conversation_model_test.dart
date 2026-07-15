import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/admin/messaging/models/admin_conversation_model.dart';

void main() {
  group('AdminConversationModel.fromData', () {
    test('normalise les données complètes et calcule les indicateurs', () {
      final createdAt = DateTime.utc(2026, 7, 1, 8);
      final updatedAt = DateTime.utc(2026, 7, 2, 9);
      final lastMessageAt = DateTime.utc(2026, 7, 3, 10);

      final model = AdminConversationModel.fromData(
        'conversation-long-id',
        <String, dynamic>{
          'contextId': 'offer-42',
          'contextTitle': 'Besoin de jardinage',
          'categoryId': 'jardinage',
          'region': 'Guadeloupe',
          'participantIds': <dynamic>[' user-a ', '', 42],
          'participantNames': <dynamic, dynamic>{
            ' user-a ': ' Alice ',
            'user-b': 'Bob',
            '': 'ignoré',
            'user-c': ' ',
          },
          'createdAt': createdAt,
          'updatedAt': updatedAt,
          'lastMessageAt': lastMessageAt,
          'messageCount': 12.8,
          'status': 'blocked',
          'riskScore': '7',
          'reportCount': 3,
          'adminWatchlisted': true,
          'attachmentIds': <String>['attachment-1'],
          'unreadCount': <String, dynamic>{
            'user-a': 0,
            'user-b': '2',
          },
        },
      );

      expect(model.id, 'conversation-long-id');
      expect(model.shortId, 'conversa');
      expect(model.contextId, 'offer-42');
      expect(model.contextTitle, 'Besoin de jardinage');
      expect(model.category, 'jardinage');
      expect(model.region, 'Guadeloupe');
      expect(model.participantIds, <String>['user-a', '42']);
      expect(model.participantNames, <String, String>{
        'user-a': 'Alice',
        'user-b': 'Bob',
      });
      expect(model.participantSummary, 'Alice • Bob');
      expect(model.createdAt, createdAt);
      expect(model.updatedAt, updatedAt);
      expect(model.lastMessageAt, lastMessageAt);
      expect(model.messageCount, 12);
      expect(model.status, 'blocked');
      expect(model.riskScore, 7);
      expect(model.reportCount, 3);
      expect(model.adminWatchlisted, isTrue);
      expect(model.hasAttachments, isTrue);
      expect(model.hasUnread, isTrue);
    });

    test('applique les replis hérités et les valeurs par défaut', () {
      final updatedAt = DateTime.utc(2026, 7, 4, 11);
      final model = AdminConversationModel.fromData(
        'short',
        <String, dynamic>{
          'listingId': 'listing-1',
          'listingTitle': 'Titre hérité',
          'category': 'service',
          'updatedAt': updatedAt,
          'messageCount': 'invalide',
          'riskScore': null,
          'reportCount': '4',
          'lastMessageType': 'attachment',
          'unreadCounts': <String, dynamic>{'user-a': '0', 'user-b': 'x'},
        },
      );

      expect(model.shortId, 'short');
      expect(model.contextId, 'listing-1');
      expect(model.contextTitle, 'Titre hérité');
      expect(model.category, 'service');
      expect(model.region, 'Non renseignée');
      expect(model.participantSummary, 'Participants inconnus');
      expect(model.createdAt, isNull);
      expect(model.updatedAt, updatedAt);
      expect(model.lastMessageAt, updatedAt);
      expect(model.messageCount, 0);
      expect(model.status, 'active');
      expect(model.riskScore, 0);
      expect(model.reportCount, 4);
      expect(model.adminWatchlisted, isFalse);
      expect(model.hasAttachments, isTrue);
      expect(model.hasUnread, isFalse);
    });

    test('utilise les identifiants comme résumé quand les noms manquent', () {
      final model = AdminConversationModel.fromData(
        'conversation-3',
        <String, dynamic>{
          'offerId': 'offer-legacy',
          'offerTitle': 'Titre offre',
          'participantIds': <String>['u1', 'u2'],
          'participantNames': 'format-invalide',
          'attachmentIds': const <String>[],
          'unreadCount': <String, dynamic>{'u1': -1},
        },
      );

      expect(model.contextId, 'offer-legacy');
      expect(model.contextTitle, 'Titre offre');
      expect(model.category, 'Non catégorisée');
      expect(model.participantSummary, 'u1 • u2');
      expect(model.hasAttachments, isFalse);
      expect(model.hasUnread, isFalse);
    });

    test('utilise les derniers replis de contexte', () {
      final model = AdminConversationModel.fromData(
        'conversation-4',
        <String, dynamic>{
          'unreadCount': <String, dynamic>{'u1': 1},
        },
      );

      expect(model.contextId, isEmpty);
      expect(model.contextTitle, 'Conversation sans titre');
      expect(model.hasUnread, isTrue);
    });
  });
}

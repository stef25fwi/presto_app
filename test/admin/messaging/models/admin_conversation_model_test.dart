import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/admin/messaging/models/admin_conversation_model.dart';

void main() {
  group('AdminConversationModel.participantSummary', () {
    test('privilégie les noms, puis les identifiants, puis le message par défaut',
        () {
      expect(
        const AdminConversationModel(
          id: 'conversation-1',
          shortId: 'conversa',
          contextId: '',
          contextTitle: '',
          category: '',
          region: '',
          participantIds: <String>['user-a', 'user-b'],
          participantNames: <String, String>{
            'user-a': ' Alice ',
            'user-b': 'Bob',
          },
          createdAt: null,
          updatedAt: null,
          lastMessageAt: null,
          messageCount: 0,
          status: 'active',
          riskScore: 0,
          reportCount: 0,
          adminWatchlisted: false,
          hasAttachments: false,
          hasUnread: false,
        ).participantSummary,
        'Alice • Bob',
      );

      expect(
        const AdminConversationModel(
          id: 'conversation-2',
          shortId: 'conversa',
          contextId: '',
          contextTitle: '',
          category: '',
          region: '',
          participantIds: <String>['user-a', 'user-b'],
          participantNames: <String, String>{},
          createdAt: null,
          updatedAt: null,
          lastMessageAt: null,
          messageCount: 0,
          status: 'active',
          riskScore: 0,
          reportCount: 0,
          adminWatchlisted: false,
          hasAttachments: false,
          hasUnread: false,
        ).participantSummary,
        'user-a • user-b',
      );

      expect(
        const AdminConversationModel(
          id: 'conversation-3',
          shortId: 'conversa',
          contextId: '',
          contextTitle: '',
          category: '',
          region: '',
          participantIds: <String>[],
          participantNames: <String, String>{},
          createdAt: null,
          updatedAt: null,
          lastMessageAt: null,
          messageCount: 0,
          status: 'active',
          riskScore: 0,
          reportCount: 0,
          adminWatchlisted: false,
          hasAttachments: false,
          hasUnread: false,
        ).participantSummary,
        'Participants inconnus',
      );
    });
  });

  group('AdminConversationModel.fromData', () {
    test('normalise les champs principaux et détecte non-lus et pièces jointes',
        () {
      final createdAt = DateTime.utc(2026, 7, 16, 8);
      final updatedAt = DateTime.utc(2026, 7, 16, 9);
      final model = AdminConversationModel.fromData(
        'conversation-123456789',
        <String, dynamic>{
          'participantIds': <dynamic>[' user-a ', '', 42],
          'participantNames': <String, dynamic>{
            ' user-a ': ' Alice ',
            '': 'Ignoré',
            'user-b': '   ',
            'user-c': 'Charlie',
          },
          'unreadCount': <String, dynamic>{
            'user-a': 0,
            'user-b': '2',
          },
          'attachmentIds': <String>['att-1'],
          'contextId': 'ctx-1',
          'contextTitle': 'Titre contexte',
          'categoryId': 'service-aide',
          'region': 'Guadeloupe',
          'createdAt': createdAt,
          'updatedAt': updatedAt,
          'lastMessageAt': updatedAt,
          'messageCount': '12',
          'status': 'archived',
          'riskScore': '80',
          'reportCount': '3',
          'adminWatchlisted': true,
        },
      );

      expect(model.id, 'conversation-123456789');
      expect(model.shortId, 'conversa');
      expect(model.contextId, 'ctx-1');
      expect(model.contextTitle, 'Titre contexte');
      expect(model.category, 'service-aide');
      expect(model.region, 'Guadeloupe');
      expect(model.participantIds, <String>['user-a', '42']);
      expect(model.participantNames, <String, String>{
        'user-a': 'Alice',
        'user-c': 'Charlie',
      });
      expect(model.createdAt, createdAt);
      expect(model.updatedAt, updatedAt);
      expect(model.lastMessageAt, updatedAt);
      expect(model.messageCount, 12);
      expect(model.status, 'archived');
      expect(model.riskScore, 80);
      expect(model.reportCount, 3);
      expect(model.adminWatchlisted, isTrue);
      expect(model.hasAttachments, isTrue);
      expect(model.hasUnread, isTrue);
    });

    test('utilise les fallbacks de contexte, catégorie, région et dates', () {
      final updatedAt = DateTime.utc(2026, 7, 16, 10);
      final model = AdminConversationModel.fromData(
        'short',
        <String, dynamic>{
          'listingId': 'listing-1',
          'offerTitle': 'Titre offre',
          'category': 'bricolage',
          'lastMessageType': 'attachment',
          'unreadCounts': <String, dynamic>{'user-a': '0'},
          'updatedAt': updatedAt,
        },
      );

      expect(model.shortId, 'short');
      expect(model.contextId, 'listing-1');
      expect(model.contextTitle, 'Titre offre');
      expect(model.category, 'bricolage');
      expect(model.region, 'Non renseignée');
      expect(model.lastMessageAt, updatedAt);
      expect(model.status, 'active');
      expect(model.messageCount, 0);
      expect(model.riskScore, 0);
      expect(model.reportCount, 0);
      expect(model.hasAttachments, isTrue);
      expect(model.hasUnread, isFalse);
    });

    test('retombe sur les libellés par défaut si les données sont absentes', () {
      final model = AdminConversationModel.fromData(
        'conversation-empty',
        const <String, dynamic>{},
      );

      expect(model.contextId, '');
      expect(model.contextTitle, 'Conversation sans titre');
      expect(model.category, 'Non catégorisée');
      expect(model.region, 'Non renseignée');
      expect(model.participantIds, isEmpty);
      expect(model.participantNames, isEmpty);
      expect(model.hasAttachments, isFalse);
      expect(model.hasUnread, isFalse);
      expect(model.participantSummary, 'Participants inconnus');
    });
  });
}

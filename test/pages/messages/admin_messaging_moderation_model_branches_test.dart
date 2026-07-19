import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/admin_messaging_moderation_page.dart';

void main() {
  group('ModerationLogEntry.fromMap', () {
    test('normalise une entrée complète avec les champs modernes', () {
      final entry = ModerationLogEntry.fromMap(
        messageId: 'message-1',
        conversationId: 'conversation-1',
        data: {
          'senderId': 'user-1',
          'senderName': 'Alice',
          'text': 'Contenu à vérifier',
          'createdAt': DateTime.utc(2026, 7, 19, 10, 30),
          'moderation': {
            'mode': 'hybrid',
            'status': 'manual_review',
            'visibility': 'hidden',
            'reason': 'suspicious_content',
            'userMessage': 'Message en cours de vérification',
            'autoFlags': ['spam', '', ' abusive '],
            'riskScore': 72.6,
          },
        },
      );

      expect(entry.messageId, 'message-1');
      expect(entry.conversationId, 'conversation-1');
      expect(entry.senderId, 'user-1');
      expect(entry.senderName, 'Alice');
      expect(entry.text, 'Contenu à vérifier');
      expect(entry.mode, 'hybrid');
      expect(entry.status, 'manual_review');
      expect(entry.visibility, 'hidden');
      expect(entry.reason, 'suspicious_content');
      expect(entry.userMessage, 'Message en cours de vérification');
      expect(entry.autoFlags, ['spam', ' abusive ']);
      expect(entry.riskScore, 73);
      expect(entry.createdAt, DateTime.utc(2026, 7, 19, 10, 30));
      expect(entry.isModerated, isTrue);
    });

    test('accepte les anciens noms de champs et les valeurs absentes', () {
      final entry = ModerationLogEntry.fromMap(
        messageId: 'legacy-message',
        conversationId: '',
        data: {
          'sender_id': 42,
          'sender_name': 'Compte supprimé',
          'body': 'Ancien message',
          'created_at': '2026-07-19T11:45:00.000Z',
          'moderation': 'invalide',
        },
      );

      expect(entry.senderId, '42');
      expect(entry.senderName, 'Compte supprimé');
      expect(entry.text, 'Ancien message');
      expect(entry.mode, isEmpty);
      expect(entry.status, isEmpty);
      expect(entry.visibility, isEmpty);
      expect(entry.reason, isEmpty);
      expect(entry.userMessage, isEmpty);
      expect(entry.autoFlags, isEmpty);
      expect(entry.riskScore, 0);
      expect(entry.createdAt, DateTime.utc(2026, 7, 19, 11, 45));
      expect(entry.isModerated, isFalse);
    });

    test('classe toutes les raisons et statuts de modération', () {
      ModerationLogEntry entry({
        required String status,
        String reason = '',
      }) {
        return ModerationLogEntry.fromMap(
          messageId: status,
          conversationId: 'conversation',
          data: {
            'moderation': {
              'status': status,
              'reason': reason,
            },
          },
        );
      }

      expect(entry(status: 'pending').isModerated, isTrue);
      expect(entry(status: 'manual_review').isModerated, isTrue);
      expect(entry(status: 'rejected').isModerated, isTrue);
      expect(entry(status: 'approved', reason: 'policy_match').isModerated,
          isTrue);
      expect(
        entry(status: 'approved', reason: 'approved_automatically')
            .isModerated,
        isFalse,
      );
      expect(entry(status: 'approved').isModerated, isFalse);
    });
  });

  test('expose les quatre filtres de modération', () {
    expect(
      ModerationLogFilter.values,
      [
        ModerationLogFilter.all,
        ModerationLogFilter.pending,
        ModerationLogFilter.manualReview,
        ModerationLogFilter.rejected,
      ],
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/subscriptions/subscription_credit_service.dart';
import 'package:presto_app/models/conversation_summary.dart';

void main() {
  group('ConversationSummary multi-file wave', () {
    test('normalise les alias, compteurs et états utilisateur', () {
      final summary = ConversationSummary.fromMap('conv-1', {
        'participants': [' user-a ', 'user-b', ''],
        'participant_names': {'user-a': 'Alice', 'user-b': 'Bob'},
        'offer_id': 'offer-1',
        'offer_title': 'Peinture portail',
        'last_message': 'Disponible demain',
        'last_sender_id': 'user-b',
        'last_sender_name': 'Bob',
        'unread_count': {'user-a': '2', 'user-b': 0.9, '': 9},
        'message_count': '4',
        'archivedBy': {'user-a': true},
        'deletedBy': {'user-b': true},
        'blockedBy': {'user-a': false, 'user-b': true},
      });

      expect(summary.participants, ['user-a', 'user-b']);
      expect(summary.offerId, 'offer-1');
      expect(summary.offerTitle, 'Peinture portail');
      expect(summary.messageCount, 4);
      expect(summary.unreadForUser(' user-a '), 2);
      expect(summary.isArchivedForUser('user-a'), isTrue);
      expect(summary.isDeletedForUser('user-b'), isTrue);
      expect(summary.isBlockedForUser('user-b'), isTrue);
      expect(summary.isBlocked, isTrue);
      expect(summary.includesUser('user-a'), isTrue);
      expect(summary.includesUser('   '), isFalse);
      expect(summary.titleFor('user-a'), 'Bob');
      expect(summary.previewFor('user-a'), 'Disponible demain');
      expect(summary.matchesQuery('user-a', 'portail'), isTrue);
      expect(summary.matchesQuery('user-a', 'introuvable'), isFalse);
      expect(summary.hasRenderableContent, isTrue);
    });

    test('applique tous les replis de titre et aperçu', () {
      final sent = ConversationSummary.fromMap('sent', {
        'participants': ['me', 'other'],
        'lastMessage': 'Bonjour',
        'lastSenderId': 'me',
      });
      expect(sent.previewFor('me'), 'Vous : Bonjour');
      expect(sent.titleFor('me'), 'Conversation en cours');

      final messageOnly = ConversationSummary.fromMap('message-only', {
        'messageCount': 3,
      });
      expect(messageOnly.previewFor('me'), 'Messages sans apercu');

      final offerOnly = ConversationSummary.fromMap('offer-only', {
        'offerTitle': 'Jardinage',
      });
      expect(offerOnly.titleFor('me'), 'Jardinage');
      expect(offerOnly.previewFor('me'), 'Jardinage');

      final identified = ConversationSummary.fromMap('identified', const {});
      expect(
        identified.previewFor('me'),
        'Touchez pour ouvrir cette conversation',
      );

      final empty = ConversationSummary.fromMap('', const {});
      expect(empty.titleFor('me'), 'Conversation');
      expect(
        empty.previewFor('me'),
        'Conversation en attente de synchronisation',
      );
      expect(empty.hasRenderableContent, isFalse);
    });

    test('fusionne deux résumés et refuse des identifiants différents', () {
      final older = ConversationSummary.fromMap('conv', {
        'participants': ['a'],
        'participantNames': {'a': 'Alice'},
        'lastMessage': 'Ancien',
        'lastMessageAt': DateTime.utc(2026, 7, 1),
        'createdAt': DateTime.utc(2026, 6, 1),
        'updatedAt': DateTime.utc(2026, 7, 1),
        'unreadCount': {'a': 1},
        'messageCount': 2,
        'archivedBy': {'a': true},
      });
      final newer = ConversationSummary.fromMap('conv', {
        'participants': ['b'],
        'participantNames': {'b': 'Bob'},
        'lastMessage': 'Nouveau',
        'lastSenderId': 'b',
        'lastMessageAt': DateTime.utc(2026, 7, 2),
        'createdAt': DateTime.utc(2026, 6, 2),
        'updatedAt': DateTime.utc(2026, 7, 3),
        'unreadCount': {'a': 3, 'b': 2},
        'messageCount': 5,
        'blockedBy': {'b': true},
      });

      final merged = older.mergeWith(newer);
      expect(merged.participants, ['a', 'b']);
      expect(merged.participantNames, {'a': 'Alice', 'b': 'Bob'});
      expect(merged.lastMessage, 'Nouveau');
      expect(merged.lastSenderId, 'b');
      expect(merged.unreadCount, {'a': 3, 'b': 2});
      expect(merged.messageCount, 5);
      expect(merged.createdAt, DateTime.utc(2026, 6, 1));
      expect(merged.updatedAt, DateTime.utc(2026, 7, 3));
      expect(merged.sortDate, DateTime.utc(2026, 7, 2));
      expect(merged.isArchivedForUser('a'), isTrue);
      expect(merged.isBlockedForUser('b'), isTrue);

      final other = ConversationSummary.fromMap('other', const {});
      expect(() => older.mergeWith(other), throwsArgumentError);
    });
  });

  group('SubscriptionCreditService multi-file wave', () {
    test('construit tous les crédits absents avec des valeurs sûres', () {
      final snapshot = SubscriptionCreditSnapshot.fromMap(const {});

      expect(snapshot.plan, 'free');
      expect(snapshot.period, '');
      expect(snapshot.freeAccessMode, isFalse);
      expect(snapshot.nextResetAt, isNull);
      for (final kind in SubscriptionCreditKind.values) {
        expect(snapshot[kind].used, 0);
        expect(snapshot[kind].limit, 0);
        expect(snapshot[kind].remaining, 0);
        expect(snapshot[kind].compactLabel, '0');
      }
    });

    test('normalise maps dynamiques, dates et valeurs numériques invalides', () {
      final snapshot = SubscriptionCreditSnapshot.fromMap({
        'plan': 42,
        'period': null,
        'nextResetAt': 'date-invalide',
        'credits': <Object?, Object?>{
          'pdf': <Object?, Object?>{
            'used': 'abc',
            'limit': '10',
            'remaining': 7.8,
            'unlimited': false,
            'exhausted': true,
          },
        },
      });

      final pdf = snapshot[SubscriptionCreditKind.pdf];
      expect(snapshot.plan, '42');
      expect(snapshot.period, '');
      expect(snapshot.nextResetAt, isNull);
      expect(pdf.used, 0);
      expect(pdf.limit, 10);
      expect(pdf.remaining, 7);
      expect(pdf.exhausted, isTrue);
      expect(pdf.compactLabel, '7/10');
    });

    test('SavedJourneyRecord filtre les données invalides sans exception', () {
      final record = SavedJourneyRecord.fromMap({
        'id': 99,
        'title': null,
        'activity': true,
        'currentStatus': 3.14,
        'region': 'Guadeloupe',
        'createdAtMillis': 'invalide',
        'updatedAtMillis': -10,
        'snapshot': 'pas une map',
      });

      expect(record.id, '99');
      expect(record.title, '');
      expect(record.activity, 'true');
      expect(record.currentStatus, '3.14');
      expect(record.region, 'Guadeloupe');
      expect(record.createdAt, isNull);
      expect(record.updatedAt, isNull);
      expect(record.snapshot, isEmpty);
    });
  });
}

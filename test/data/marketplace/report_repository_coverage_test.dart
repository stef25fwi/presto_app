import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/data/marketplace/report_repository.dart';
import 'package:presto_app/models/marketplace_enums.dart';
import 'package:presto_app/models/marketplace_report.dart';

void main() {
  group('ReportRepository coverage', () {
    test('transmet le signalement et journalise une revue déclenchée', () async {
      Map<String, dynamic>? sentParameters;
      String? eventName;
      Map<String, Object?>? eventParameters;
      final repository = ReportRepository(
        caller: (parameters) async {
          sentParameters = Map<String, dynamic>.from(parameters);
          return <String, dynamic>{
            'ok': true,
            'reviewTriggered': true,
          };
        },
        analyticsLogger: (name, parameters) async {
          eventName = name;
          eventParameters = Map<String, Object?>.from(parameters);
        },
      );
      const draft = ListingReportDraft(
        listingId: 'listing-42',
        reasonCode: ListingReportReasonCode.fraud,
        reasonText: 'Paiement suspect',
      );

      final result = await repository.reportListing(
        draft,
        recaptchaToken: 'recaptcha-token',
      );

      expect(result, isTrue);
      expect(sentParameters, <String, dynamic>{
        'listingId': 'listing-42',
        'reasonCode': 'fraud',
        'reasonText': 'Paiement suspect',
        'recaptchaToken': 'recaptcha-token',
      });
      expect(eventName, 'listing_reported');
      expect(eventParameters, <String, Object?>{
        'listing_id': 'listing-42',
        'reason_code': 'fraud',
        'review_triggered': true,
      });
    });

    test('gère une réponse vide comme un échec sans revue', () async {
      Map<String, Object?>? eventParameters;
      final repository = ReportRepository(
        caller: (_) async => null,
        analyticsLogger: (_, parameters) async {
          eventParameters = Map<String, Object?>.from(parameters);
        },
      );
      const draft = ListingReportDraft(
        listingId: 'listing-empty',
        reasonCode: ListingReportReasonCode.other,
      );

      final result = await repository.reportListing(
        draft,
        recaptchaToken: '',
      );

      expect(result, isFalse);
      expect(eventParameters, <String, Object?>{
        'listing_id': 'listing-empty',
        'reason_code': 'other',
        'review_triggered': false,
      });
    });

    test(
      'transmet le signalement de conversation et journalise une revue déclenchée',
      () async {
        Map<String, dynamic>? sentParameters;
        String? eventName;
        Map<String, Object?>? eventParameters;
        final repository = ReportRepository(
          caller: (parameters) async {
            sentParameters = Map<String, dynamic>.from(parameters);
            return <String, dynamic>{
              'ok': true,
              'reviewTriggered': true,
            };
          },
          analyticsLogger: (name, parameters) async {
            eventName = name;
            eventParameters = Map<String, Object?>.from(parameters);
          },
        );
        const draft = ConversationReportDraft(
          conversationId: 'conv-42',
          messageId: 'msg-7',
          reasonCode: MessageReportReasonCode.harassment,
          reasonText: 'Propos déplacés',
        );

        final result = await repository.reportConversation(
          draft,
          recaptchaToken: 'recaptcha-token',
        );

        expect(result, isTrue);
        expect(sentParameters, <String, dynamic>{
          'conversationId': 'conv-42',
          'messageId': 'msg-7',
          'reasonCode': 'harassment',
          'reasonText': 'Propos déplacés',
          'recaptchaToken': 'recaptcha-token',
        });
        expect(eventName, 'message_reported');
        expect(eventParameters, <String, Object?>{
          'conversation_id': 'conv-42',
          'reason_code': 'harassment',
          'review_triggered': true,
        });
      },
    );

    test(
      'gère une réponse vide pour un signalement de conversation',
      () async {
        final repository = ReportRepository(
          caller: (_) async => null,
          analyticsLogger: (_, __) async {},
        );
        const draft = ConversationReportDraft(
          conversationId: 'conv-empty',
          reasonCode: MessageReportReasonCode.spam,
        );

        final result = await repository.reportConversation(
          draft,
          recaptchaToken: '',
        );

        expect(result, isFalse);
      },
    );
  });
}

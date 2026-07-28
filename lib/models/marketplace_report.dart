import 'marketplace_enums.dart';

class ListingReportDraft {
  final String listingId;
  final ListingReportReasonCode reasonCode;
  final String? reasonText;

  const ListingReportDraft({
    required this.listingId,
    required this.reasonCode,
    this.reasonText,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'listingId': listingId,
      'reasonCode': reasonCode.value,
      'reasonText': reasonText,
    };
  }
}

class ConversationReportDraft {
  final String conversationId;
  final String? messageId;
  final MessageReportReasonCode reasonCode;
  final String? reasonText;

  const ConversationReportDraft({
    required this.conversationId,
    this.messageId,
    required this.reasonCode,
    this.reasonText,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'conversationId': conversationId,
      'messageId': messageId,
      'reasonCode': reasonCode.value,
      'reasonText': reasonText,
    };
  }
}

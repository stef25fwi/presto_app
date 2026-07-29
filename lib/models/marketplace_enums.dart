enum ListingStatus {
  draft,
  pending,
  active,
  rejected,
  archived,
  sold,
  deleted,
}

enum ModerationStatus {
  pending,
  autoFlagged,
  approved,
  rejected,
  manualReview,
  blocked,
}

enum ReportStatus {
  open,
  underReview,
  resolved,
  dismissed,
}

enum ListingVisibility {
  private,
  public,
  hidden,
}

enum ListingReportReasonCode {
  spam,
  fraud,
  inappropriate,
  duplicate,
  wrongCategory,
  fakeListing,
  harassment,
  other,
}

enum MessageReportReasonCode {
  spam,
  fraud,
  harassment,
  inappropriate,
  other,
}

extension ListingStatusParsing on ListingStatus {
  String get value => switch (this) {
        ListingStatus.draft => 'draft',
        ListingStatus.pending => 'pending',
        ListingStatus.active => 'active',
        ListingStatus.rejected => 'rejected',
        ListingStatus.archived => 'archived',
        ListingStatus.sold => 'sold',
        ListingStatus.deleted => 'deleted',
      };

  static ListingStatus fromString(String value) {
    return ListingStatus.values.firstWhere(
      (status) => status.value == value.trim(),
      orElse: () => ListingStatus.draft,
    );
  }
}

extension ModerationStatusParsing on ModerationStatus {
  String get value => switch (this) {
        ModerationStatus.pending => 'pending',
        ModerationStatus.autoFlagged => 'auto_flagged',
        ModerationStatus.approved => 'approved',
        ModerationStatus.rejected => 'rejected',
        ModerationStatus.manualReview => 'manual_review',
        ModerationStatus.blocked => 'blocked',
      };

  static ModerationStatus fromString(String value) {
    return ModerationStatus.values.firstWhere(
      (status) => status.value == value.trim(),
      orElse: () => ModerationStatus.pending,
    );
  }
}

extension ListingVisibilityParsing on ListingVisibility {
  String get value => switch (this) {
        ListingVisibility.private => 'private',
        ListingVisibility.public => 'public',
        ListingVisibility.hidden => 'hidden',
      };

  static ListingVisibility fromString(String value) {
    return ListingVisibility.values.firstWhere(
      (visibility) => visibility.value == value.trim(),
      orElse: () => ListingVisibility.private,
    );
  }
}

extension ListingReportReasonCodeParsing on ListingReportReasonCode {
  String get value => switch (this) {
        ListingReportReasonCode.spam => 'spam',
        ListingReportReasonCode.fraud => 'fraud',
        ListingReportReasonCode.inappropriate => 'inappropriate',
        ListingReportReasonCode.duplicate => 'duplicate',
        ListingReportReasonCode.wrongCategory => 'wrong_category',
        ListingReportReasonCode.fakeListing => 'fake_listing',
        ListingReportReasonCode.harassment => 'harassment',
        ListingReportReasonCode.other => 'other',
      };
}

extension MessageReportReasonCodeParsing on MessageReportReasonCode {
  String get value => switch (this) {
        MessageReportReasonCode.spam => 'spam',
        MessageReportReasonCode.fraud => 'fraud',
        MessageReportReasonCode.harassment => 'harassment',
        MessageReportReasonCode.inappropriate => 'inappropriate',
        MessageReportReasonCode.other => 'other',
      };
}

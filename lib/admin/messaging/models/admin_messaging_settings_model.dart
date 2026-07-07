class AdminMessagingSettingsModel {
  final bool enabled;
  final bool allowImages;
  final bool allowVoice;
  final bool allowDocuments;
  final int maxFileSizeMb;
  final int maxMessagesPerHour;
  final int maxConversationsPerDay;
  final int retentionDays;
  final bool notificationPreviewEnabled;
  final String moderationMode;
  final int riskThreshold;
  final int autoBlockThreshold;

  const AdminMessagingSettingsModel({
    required this.enabled,
    required this.allowImages,
    required this.allowVoice,
    required this.allowDocuments,
    required this.maxFileSizeMb,
    required this.maxMessagesPerHour,
    required this.maxConversationsPerDay,
    required this.retentionDays,
    required this.notificationPreviewEnabled,
    required this.moderationMode,
    required this.riskThreshold,
    required this.autoBlockThreshold,
  });

  factory AdminMessagingSettingsModel.fromMap(Map<String, dynamic> data) {
    return AdminMessagingSettingsModel(
      enabled: data['enabled'] != false,
      allowImages: data['allowImages'] != false,
      allowVoice: data['allowVoice'] != false,
      allowDocuments: data['allowDocuments'] != false,
      maxFileSizeMb: (data['maxFileSizeMb'] is num)
          ? (data['maxFileSizeMb'] as num).toInt()
          : 25,
      maxMessagesPerHour: (data['maxMessagesPerHour'] is num)
          ? (data['maxMessagesPerHour'] as num).toInt()
          : 60,
      maxConversationsPerDay: (data['maxConversationsPerDay'] is num)
          ? (data['maxConversationsPerDay'] as num).toInt()
          : 20,
      retentionDays: (data['retentionDays'] is num)
          ? (data['retentionDays'] as num).toInt()
          : 365,
      notificationPreviewEnabled: data['notificationPreviewEnabled'] == true,
      moderationMode: '${data['moderationMode'] ?? 'hybrid'}',
      riskThreshold: (data['riskThreshold'] is num)
          ? (data['riskThreshold'] as num).toInt()
          : 70,
      autoBlockThreshold: (data['autoBlockThreshold'] is num)
          ? (data['autoBlockThreshold'] as num).toInt()
          : 90,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'allowImages': allowImages,
      'allowVoice': allowVoice,
      'allowDocuments': allowDocuments,
      'maxFileSizeMb': maxFileSizeMb,
      'maxMessagesPerHour': maxMessagesPerHour,
      'maxConversationsPerDay': maxConversationsPerDay,
      'retentionDays': retentionDays,
      'notificationPreviewEnabled': notificationPreviewEnabled,
      'moderationMode': moderationMode,
      'riskThreshold': riskThreshold,
      'autoBlockThreshold': autoBlockThreshold,
    };
  }

  AdminMessagingSettingsModel copyWith({
    bool? enabled,
    bool? allowImages,
    bool? allowVoice,
    bool? allowDocuments,
    int? maxFileSizeMb,
    int? maxMessagesPerHour,
    int? maxConversationsPerDay,
    int? retentionDays,
    bool? notificationPreviewEnabled,
    String? moderationMode,
    int? riskThreshold,
    int? autoBlockThreshold,
  }) {
    return AdminMessagingSettingsModel(
      enabled: enabled ?? this.enabled,
      allowImages: allowImages ?? this.allowImages,
      allowVoice: allowVoice ?? this.allowVoice,
      allowDocuments: allowDocuments ?? this.allowDocuments,
      maxFileSizeMb: maxFileSizeMb ?? this.maxFileSizeMb,
      maxMessagesPerHour: maxMessagesPerHour ?? this.maxMessagesPerHour,
      maxConversationsPerDay:
          maxConversationsPerDay ?? this.maxConversationsPerDay,
      retentionDays: retentionDays ?? this.retentionDays,
      notificationPreviewEnabled:
          notificationPreviewEnabled ?? this.notificationPreviewEnabled,
      moderationMode: moderationMode ?? this.moderationMode,
      riskThreshold: riskThreshold ?? this.riskThreshold,
      autoBlockThreshold: autoBlockThreshold ?? this.autoBlockThreshold,
    );
  }
}

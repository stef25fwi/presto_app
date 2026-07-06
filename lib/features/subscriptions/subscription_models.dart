import 'package:cloud_firestore/cloud_firestore.dart';

enum SubscriptionPlan {
  free,
  iliprestoPlus,
  ilipro,
}

enum SubscriptionStatus {
  inactive,
  active,
  pastDue,
  canceled,
}

class SubscriptionAppConfig {
  final bool subscriptionSectionEnabled;
  final bool subscriptionsPrepared;
  final bool stripeEnabled;
  final bool freeAccessMode;
  final Timestamp? updatedAt;
  final String? updatedBy;

  const SubscriptionAppConfig({
    required this.subscriptionSectionEnabled,
    required this.subscriptionsPrepared,
    required this.stripeEnabled,
    required this.freeAccessMode,
    this.updatedAt,
    this.updatedBy,
  });

  const SubscriptionAppConfig.defaults()
      : subscriptionSectionEnabled = false,
        subscriptionsPrepared = true,
        stripeEnabled = false,
        freeAccessMode = true,
        updatedAt = null,
        updatedBy = null;

  factory SubscriptionAppConfig.fromMap(Map<String, dynamic>? data) {
    final map = data ?? <String, dynamic>{};

    return SubscriptionAppConfig(
      subscriptionSectionEnabled: map['subscriptionSectionEnabled'] == true,
      subscriptionsPrepared: map['subscriptionsPrepared'] != false,
      stripeEnabled: map['stripeEnabled'] == true,
      freeAccessMode: map['freeAccessMode'] != false,
      updatedAt:
          map['updatedAt'] is Timestamp ? map['updatedAt'] as Timestamp : null,
      updatedBy: (map['updatedBy'] as String?)?.trim(),
    );
  }

  Map<String, dynamic> toFirestoreMap({
    bool includeServerTimestamp = false,
    String? nextUpdatedBy,
  }) {
    return <String, dynamic>{
      'subscriptionSectionEnabled': subscriptionSectionEnabled,
      'subscriptionsPrepared': subscriptionsPrepared,
      'stripeEnabled': stripeEnabled,
      'freeAccessMode': freeAccessMode,
      'updatedAt':
          includeServerTimestamp ? FieldValue.serverTimestamp() : updatedAt,
      'updatedBy': nextUpdatedBy ?? updatedBy,
    };
  }
}

class AppUserSubscriptionState {
  final SubscriptionPlan plan;
  final SubscriptionStatus status;
  final DateTime? subscriptionExpiresAt;
  final bool phoneVerified;
  final bool proVerified;

  const AppUserSubscriptionState({
    required this.plan,
    required this.status,
    required this.subscriptionExpiresAt,
    required this.phoneVerified,
    required this.proVerified,
  });

  const AppUserSubscriptionState.free()
      : plan = SubscriptionPlan.free,
        status = SubscriptionStatus.inactive,
        subscriptionExpiresAt = null,
        phoneVerified = false,
        proVerified = false;

  factory AppUserSubscriptionState.fromMap(Map<String, dynamic>? data) {
    final map = data ?? <String, dynamic>{};

    return AppUserSubscriptionState(
      plan: subscriptionPlanFromKey(map['subscriptionPlan']?.toString()),
      status: subscriptionStatusFromKey(map['subscriptionStatus']?.toString()),
      subscriptionExpiresAt: _dateTimeFromDynamic(map['subscriptionExpiresAt']),
      phoneVerified: _boolFromKeys(
        map,
        const ['phoneVerified', 'isPhoneVerified', 'phoneNumberVerified'],
      ),
      proVerified: _boolFromKeys(
        map,
        const ['proVerified', 'isProVerified', 'siretVerified'],
      ),
    );
  }

  Map<String, dynamic> toFirestoreSeedMap() {
    return <String, dynamic>{
      'subscriptionPlan': subscriptionPlanKey(plan),
      'subscriptionStatus': subscriptionStatusKey(status),
      'subscriptionExpiresAt': subscriptionExpiresAt,
      'phoneVerified': phoneVerified,
      'proVerified': proVerified,
    };
  }
}

class SubscriptionFeatures {
  final bool canUseDirectCall;
  final bool canUseFavorites;
  final bool canReceiveFavoriteAlerts;
  final bool canUseAiDraft;
  final bool canUseVoiceAi;
  final bool canBoostOffer;
  final bool canAccessStats;
  final bool canCreateProProfile;
  final bool hasVerifiedBadge;
  final bool hasProBadge;
  final int maxActiveOffers;
  final int maxPhotosPerOffer;

  const SubscriptionFeatures({
    required this.canUseDirectCall,
    required this.canUseFavorites,
    required this.canReceiveFavoriteAlerts,
    required this.canUseAiDraft,
    required this.canUseVoiceAi,
    required this.canBoostOffer,
    required this.canAccessStats,
    required this.canCreateProProfile,
    required this.hasVerifiedBadge,
    required this.hasProBadge,
    required this.maxActiveOffers,
    required this.maxPhotosPerOffer,
  });
}

class ConversationAttachmentEntitlements {
  final bool canSendDocuments;
  final int maxPhotosPerConversation;
  final int maxAudioPerConversation;

  const ConversationAttachmentEntitlements({
    required this.canSendDocuments,
    required this.maxPhotosPerConversation,
    required this.maxAudioPerConversation,
  });
}

SubscriptionPlan subscriptionPlanFromKey(String? value) {
  switch ((value ?? '').trim().toLowerCase()) {
    case 'ilipresto_plus':
    case 'iliprestoplus':
    case 'ilipresto+':
      return SubscriptionPlan.iliprestoPlus;
    case 'ilipro':
      return SubscriptionPlan.ilipro;
    default:
      return SubscriptionPlan.free;
  }
}

SubscriptionStatus subscriptionStatusFromKey(String? value) {
  switch ((value ?? '').trim().toLowerCase()) {
    case 'active':
      return SubscriptionStatus.active;
    case 'past_due':
    case 'pastdue':
      return SubscriptionStatus.pastDue;
    case 'canceled':
    case 'cancelled':
      return SubscriptionStatus.canceled;
    default:
      return SubscriptionStatus.inactive;
  }
}

String subscriptionPlanKey(SubscriptionPlan plan) {
  switch (plan) {
    case SubscriptionPlan.free:
      return 'free';
    case SubscriptionPlan.iliprestoPlus:
      return 'ilipresto_plus';
    case SubscriptionPlan.ilipro:
      return 'ilipro';
  }
}

String subscriptionPlanLabel(SubscriptionPlan plan) {
  switch (plan) {
    case SubscriptionPlan.free:
      return 'Gratuit';
    case SubscriptionPlan.iliprestoPlus:
      return 'ilipresto+';
    case SubscriptionPlan.ilipro:
      return 'ilipro';
  }
}

String subscriptionStatusKey(SubscriptionStatus status) {
  switch (status) {
    case SubscriptionStatus.inactive:
      return 'inactive';
    case SubscriptionStatus.active:
      return 'active';
    case SubscriptionStatus.pastDue:
      return 'past_due';
    case SubscriptionStatus.canceled:
      return 'canceled';
  }
}

Map<String, dynamic> buildDefaultSubscriptionUserFields({
  bool phoneVerified = false,
  bool proVerified = false,
}) {
  return AppUserSubscriptionState(
    plan: SubscriptionPlan.free,
    status: SubscriptionStatus.inactive,
    subscriptionExpiresAt: null,
    phoneVerified: phoneVerified,
    proVerified: proVerified,
  ).toFirestoreSeedMap();
}

SubscriptionFeatures getFeaturesForPlan(
  String? plan, {
  bool freeAccessMode = true,
}) {
  return getFeaturesForSubscriptionPlan(
    subscriptionPlanFromKey(plan),
    freeAccessMode: freeAccessMode,
  );
}

ConversationAttachmentEntitlements getConversationAttachmentEntitlements(
  SubscriptionPlan plan, {
  bool freeAccessMode = true,
}) {
  if (freeAccessMode) {
    return const ConversationAttachmentEntitlements(
      canSendDocuments: true,
      maxPhotosPerConversation: 999,
      maxAudioPerConversation: 999,
    );
  }

  switch (plan) {
    case SubscriptionPlan.free:
      return const ConversationAttachmentEntitlements(
        canSendDocuments: false,
        maxPhotosPerConversation: 1,
        maxAudioPerConversation: 1,
      );
    case SubscriptionPlan.iliprestoPlus:
    case SubscriptionPlan.ilipro:
      return const ConversationAttachmentEntitlements(
        canSendDocuments: true,
        maxPhotosPerConversation: 999,
        maxAudioPerConversation: 999,
      );
  }
}

SubscriptionFeatures getFeaturesForSubscriptionPlan(
  SubscriptionPlan plan, {
  bool freeAccessMode = true,
}) {
  if (freeAccessMode) {
    return const SubscriptionFeatures(
      canUseDirectCall: true,
      canUseFavorites: true,
      canReceiveFavoriteAlerts: true,
      canUseAiDraft: true,
      canUseVoiceAi: true,
      canBoostOffer: true,
      canAccessStats: true,
      canCreateProProfile: true,
      hasVerifiedBadge: true,
      hasProBadge: true,
      maxActiveOffers: 9999,
      maxPhotosPerOffer: 999,
    );
  }

  switch (plan) {
    case SubscriptionPlan.free:
      return const SubscriptionFeatures(
        canUseDirectCall: false,
        canUseFavorites: true,
        canReceiveFavoriteAlerts: false,
        canUseAiDraft: false,
        canUseVoiceAi: false,
        canBoostOffer: false,
        canAccessStats: false,
        canCreateProProfile: false,
        hasVerifiedBadge: false,
        hasProBadge: false,
        maxActiveOffers: 3,
        maxPhotosPerOffer: 3,
      );
    case SubscriptionPlan.iliprestoPlus:
      return const SubscriptionFeatures(
        canUseDirectCall: true,
        canUseFavorites: true,
        canReceiveFavoriteAlerts: true,
        canUseAiDraft: true,
        canUseVoiceAi: true,
        canBoostOffer: true,
        canAccessStats: false,
        canCreateProProfile: false,
        hasVerifiedBadge: true,
        hasProBadge: false,
        maxActiveOffers: 10,
        maxPhotosPerOffer: 12,
      );
    case SubscriptionPlan.ilipro:
      return const SubscriptionFeatures(
        canUseDirectCall: true,
        canUseFavorites: true,
        canReceiveFavoriteAlerts: true,
        canUseAiDraft: true,
        canUseVoiceAi: true,
        canBoostOffer: true,
        canAccessStats: true,
        canCreateProProfile: true,
        hasVerifiedBadge: true,
        hasProBadge: true,
        maxActiveOffers: 50,
        maxPhotosPerOffer: 20,
      );
  }
}

DateTime? _dateTimeFromDynamic(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value.trim());
  }
  return null;
}

bool _boolFromKeys(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    if (data[key] == true) {
      return true;
    }
  }
  return false;
}

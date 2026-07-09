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
  final int maxMonthlyOfferReplies;
  final int maxFavorites;
  final int maxMonthlyAiAdDrafts;
  final bool hasInstantAlerts;
  final bool hasCategoryAlerts;

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
    required this.maxMonthlyOfferReplies,
    required this.maxFavorites,
    required this.maxMonthlyAiAdDrafts,
    required this.hasInstantAlerts,
    required this.hasCategoryAlerts,
  });

  bool get hasUnlimitedOfferReplies =>
      maxMonthlyOfferReplies >= kUnlimitedSubscriptionQuota;

  bool get hasUnlimitedFavorites => maxFavorites >= kUnlimitedSubscriptionQuota;

  bool get hasUnlimitedAiAdDrafts =>
      maxMonthlyAiAdDrafts >= kUnlimitedSubscriptionQuota;
}

/// Valeur utilisée pour représenter un quota d'abonnement "illimité" (mode
/// d'accès libre ou palier d'abonnement sans plafond). Distincte de
/// [kUnlimitedJourneyQuota] pour ne pas coupler les deux modèles de quotas.
const int kUnlimitedSubscriptionQuota = 999999;

/// Argument central à répéter partout où l'abonnement est mentionné.
const String kSubscriptionZeroCommissionMessage =
    "Avec iliprestō, vous payez seulement l'accès aux opportunités. Aucune "
    "commission n'est prélevée sur vos prestations.";

/// Messages standard affichés quand un quota gratuit est atteint. Réutilisés
/// par l'app et par les callables Cloud Functions correspondantes.
const String kOfferReplyLimitMessage =
    "Vous avez utilisé vos 3 réponses gratuites ce mois-ci. Avec "
    "iliprestō+ à 1,99 €/mois, répondez sans limite, sans commission, et "
    "gardez 100 % de vos gains.";

const String kFavoritesLimitMessage =
    "La formule gratuite permet 5 favoris. Avec iliprestō+ à 1,99 €/mois, "
    "vos favoris sont illimités, sans commission sur vos gains.";

const String kAiDraftLimitMessage =
    "Vous avez utilisé votre essai IA gratuit ce mois-ci. Avec iliprestō+ "
    "à 1,99 €/mois, rédigez vos annonces avec l'IA sans limite, sans "
    "commission, et gardez 100 % de vos gains.";

const String kPhotoLimitMessage =
    "Limite de photos atteinte pour votre formule. Passez à iliprestō+ ou "
    "ilipro pour publier des annonces plus complètes, toujours sans "
    "commission.";

const String kActiveOffersLimitMessage =
    "La formule gratuite permet 3 annonces actives. Avec iliprestō+, "
    "publiez jusqu'à 10 annonces actives, sans commission.";

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
      return 'iliprestō+';
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
      maxMonthlyOfferReplies: kUnlimitedSubscriptionQuota,
      maxFavorites: kUnlimitedSubscriptionQuota,
      maxMonthlyAiAdDrafts: kUnlimitedSubscriptionQuota,
      hasInstantAlerts: true,
      hasCategoryAlerts: true,
    );
  }

  switch (plan) {
    case SubscriptionPlan.free:
      return const SubscriptionFeatures(
        canUseDirectCall: false,
        canUseFavorites: true,
        canReceiveFavoriteAlerts: false,
        canUseAiDraft: true,
        canUseVoiceAi: false,
        canBoostOffer: false,
        canAccessStats: false,
        canCreateProProfile: false,
        hasVerifiedBadge: false,
        hasProBadge: false,
        maxActiveOffers: 3,
        maxPhotosPerOffer: 3,
        maxMonthlyOfferReplies: 3,
        maxFavorites: 5,
        maxMonthlyAiAdDrafts: 1,
        hasInstantAlerts: false,
        hasCategoryAlerts: false,
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
        maxMonthlyOfferReplies: kUnlimitedSubscriptionQuota,
        maxFavorites: kUnlimitedSubscriptionQuota,
        maxMonthlyAiAdDrafts: kUnlimitedSubscriptionQuota,
        hasInstantAlerts: true,
        hasCategoryAlerts: true,
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
        maxPhotosPerOffer: 10,
        maxMonthlyOfferReplies: kUnlimitedSubscriptionQuota,
        maxFavorites: kUnlimitedSubscriptionQuota,
        maxMonthlyAiAdDrafts: kUnlimitedSubscriptionQuota,
        hasInstantAlerts: true,
        hasCategoryAlerts: true,
      );
  }
}

/// Valeur utilisée pour représenter un quota "illimité" (mode d'accès libre
/// ou palier d'abonnement sans plafond).
const int kUnlimitedJourneyQuota = 999999;

/// Règles d'abonnement pour la fonctionnalité "Mon parcours personnalisé" :
/// - Gratuit : 1 sauvegarde locale par mois, aucun export PDF.
/// - IliPresto+ / ilipro : sauvegardes locales illimitées + 2 exports PDF
///   par mois, le PDF exporté devant porter le logo iliPresto et un filigrane.
class JourneyEntitlements {
  final int maxLocalSavesPerMonth;
  final bool canExportPdf;
  final int maxPdfExportsPerMonth;
  final bool pdfRequiresLogo;
  final bool pdfRequiresWatermark;

  const JourneyEntitlements({
    required this.maxLocalSavesPerMonth,
    required this.canExportPdf,
    required this.maxPdfExportsPerMonth,
    required this.pdfRequiresLogo,
    required this.pdfRequiresWatermark,
  });

  bool get hasUnlimitedLocalSaves =>
      maxLocalSavesPerMonth >= kUnlimitedJourneyQuota;

  bool get hasUnlimitedPdfExports =>
      maxPdfExportsPerMonth >= kUnlimitedJourneyQuota;
}

JourneyEntitlements getJourneyEntitlementsForPlan(
  SubscriptionPlan plan, {
  bool freeAccessMode = true,
}) {
  if (freeAccessMode) {
    return const JourneyEntitlements(
      maxLocalSavesPerMonth: kUnlimitedJourneyQuota,
      canExportPdf: true,
      maxPdfExportsPerMonth: kUnlimitedJourneyQuota,
      pdfRequiresLogo: true,
      pdfRequiresWatermark: true,
    );
  }

  switch (plan) {
    case SubscriptionPlan.free:
      return const JourneyEntitlements(
        maxLocalSavesPerMonth: 1,
        canExportPdf: false,
        maxPdfExportsPerMonth: 0,
        pdfRequiresLogo: false,
        pdfRequiresWatermark: false,
      );
    case SubscriptionPlan.iliprestoPlus:
    case SubscriptionPlan.ilipro:
      return const JourneyEntitlements(
        maxLocalSavesPerMonth: kUnlimitedJourneyQuota,
        canExportPdf: true,
        maxPdfExportsPerMonth: 2,
        pdfRequiresLogo: true,
        pdfRequiresWatermark: true,
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

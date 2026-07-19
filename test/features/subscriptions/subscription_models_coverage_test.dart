import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/subscriptions/subscription_models.dart';

void main() {
  group('SubscriptionAppConfig', () {
    test('applique les valeurs par défaut et normalise les champs', () {
      const defaults = SubscriptionAppConfig.defaults();
      expect(defaults.subscriptionSectionEnabled, isFalse);
      expect(defaults.subscriptionsPrepared, isTrue);
      expect(defaults.stripeEnabled, isFalse);
      expect(defaults.freeAccessMode, isTrue);
      expect(defaults.updatedAt, isNull);
      expect(defaults.updatedBy, isNull);

      final timestamp = Timestamp.fromMillisecondsSinceEpoch(1234);
      final parsed = SubscriptionAppConfig.fromMap(<String, dynamic>{
        'subscriptionSectionEnabled': true,
        'subscriptionsPrepared': false,
        'stripeEnabled': true,
        'freeAccessMode': false,
        'updatedAt': timestamp,
        'updatedBy': '  admin  ',
      });
      expect(parsed.subscriptionSectionEnabled, isTrue);
      expect(parsed.subscriptionsPrepared, isFalse);
      expect(parsed.stripeEnabled, isTrue);
      expect(parsed.freeAccessMode, isFalse);
      expect(parsed.updatedAt, timestamp);
      expect(parsed.updatedBy, 'admin');

      final fallback = SubscriptionAppConfig.fromMap(<String, dynamic>{
        'updatedAt': 'invalid',
      });
      expect(fallback.updatedAt, isNull);
      expect(fallback.subscriptionsPrepared, isTrue);
      expect(fallback.freeAccessMode, isTrue);
    });

    test('sérialise avec timestamp existant ou timestamp serveur', () {
      final timestamp = Timestamp.fromMillisecondsSinceEpoch(5678);
      final config = SubscriptionAppConfig(
        subscriptionSectionEnabled: true,
        subscriptionsPrepared: true,
        stripeEnabled: true,
        freeAccessMode: false,
        updatedAt: timestamp,
        updatedBy: 'original',
      );

      final stored = config.toFirestoreMap();
      expect(stored['updatedAt'], timestamp);
      expect(stored['updatedBy'], 'original');
      expect(stored['subscriptionSectionEnabled'], isTrue);
      expect(stored['stripeEnabled'], isTrue);

      final serverStored = config.toFirestoreMap(
        includeServerTimestamp: true,
        nextUpdatedBy: 'next',
      );
      expect(serverStored['updatedAt'], isA<FieldValue>());
      expect(serverStored['updatedBy'], 'next');
    });
  });

  group('AppUserSubscriptionState', () {
    test('lit les clés modernes, historiques et les dates supportées', () {
      final timestamp = Timestamp.fromDate(DateTime.utc(2026, 7, 19));
      final modern = AppUserSubscriptionState.fromMap(<String, dynamic>{
        'subscriptionPlan': ' ILIPRESTO+ ',
        'subscriptionStatus': 'past_due',
        'subscriptionExpiresAt': timestamp,
        'phoneVerified': true,
        'proVerified': true,
      });
      expect(modern.plan, SubscriptionPlan.iliprestoPlus);
      expect(modern.status, SubscriptionStatus.pastDue);
      expect(modern.subscriptionExpiresAt, timestamp.toDate());
      expect(modern.phoneVerified, isTrue);
      expect(modern.proVerified, isTrue);

      final historical = AppUserSubscriptionState.fromMap(<String, dynamic>{
        'subscriptionPlan': 'ilipro',
        'subscriptionStatus': 'cancelled',
        'subscriptionExpiresAt': '2026-08-01T12:00:00Z',
        'isPhoneVerified': true,
        'siretVerified': true,
      });
      expect(historical.plan, SubscriptionPlan.ilipro);
      expect(historical.status, SubscriptionStatus.canceled);
      expect(historical.subscriptionExpiresAt, DateTime.utc(2026, 8, 1, 12));
      expect(historical.phoneVerified, isTrue);
      expect(historical.proVerified, isTrue);

      final fromMilliseconds = AppUserSubscriptionState.fromMap(
        <String, dynamic>{'subscriptionExpiresAt': 1000},
      );
      expect(
        fromMilliseconds.subscriptionExpiresAt,
        DateTime.fromMillisecondsSinceEpoch(1000),
      );
    });

    test('retombe sur gratuit et sérialise les valeurs', () {
      final state = AppUserSubscriptionState.fromMap(<String, dynamic>{
        'subscriptionPlan': 'unknown',
        'subscriptionStatus': 'unknown',
        'subscriptionExpiresAt': 'not-a-date',
        'phoneNumberVerified': true,
      });
      expect(state.plan, SubscriptionPlan.free);
      expect(state.status, SubscriptionStatus.inactive);
      expect(state.subscriptionExpiresAt, isNull);
      expect(state.phoneVerified, isTrue);
      expect(state.proVerified, isFalse);

      final seed = state.toFirestoreSeedMap();
      expect(seed['subscriptionPlan'], 'free');
      expect(seed['subscriptionStatus'], 'inactive');
      expect(seed['phoneVerified'], isTrue);
      expect(seed['proVerified'], isFalse);
    });
  });

  group('clés, libellés et statuts', () {
    test('couvre toutes les variantes de parsing', () {
      expect(subscriptionPlanFromKey('ilipresto_plus'), SubscriptionPlan.iliprestoPlus);
      expect(subscriptionPlanFromKey('iliprestoplus'), SubscriptionPlan.iliprestoPlus);
      expect(subscriptionPlanFromKey('ilipresto+'), SubscriptionPlan.iliprestoPlus);
      expect(subscriptionPlanFromKey('ilipro'), SubscriptionPlan.ilipro);
      expect(subscriptionPlanFromKey(null), SubscriptionPlan.free);

      expect(subscriptionStatusFromKey('active'), SubscriptionStatus.active);
      expect(subscriptionStatusFromKey('past_due'), SubscriptionStatus.pastDue);
      expect(subscriptionStatusFromKey('pastdue'), SubscriptionStatus.pastDue);
      expect(subscriptionStatusFromKey('canceled'), SubscriptionStatus.canceled);
      expect(subscriptionStatusFromKey('cancelled'), SubscriptionStatus.canceled);
      expect(subscriptionStatusFromKey(null), SubscriptionStatus.inactive);
    });

    test('couvre toutes les clés et tous les libellés', () {
      expect(subscriptionPlanKey(SubscriptionPlan.free), 'free');
      expect(subscriptionPlanKey(SubscriptionPlan.iliprestoPlus), 'ilipresto_plus');
      expect(subscriptionPlanKey(SubscriptionPlan.ilipro), 'ilipro');
      expect(subscriptionPlanLabel(SubscriptionPlan.free), 'Gratuit');
      expect(subscriptionPlanLabel(SubscriptionPlan.iliprestoPlus), 'ilipresto+');
      expect(subscriptionPlanLabel(SubscriptionPlan.ilipro), 'ilipro');
      expect(subscriptionStatusKey(SubscriptionStatus.inactive), 'inactive');
      expect(subscriptionStatusKey(SubscriptionStatus.active), 'active');
      expect(subscriptionStatusKey(SubscriptionStatus.pastDue), 'past_due');
      expect(subscriptionStatusKey(SubscriptionStatus.canceled), 'canceled');
    });
  });

  group('droits et quotas', () {
    test('construit les champs utilisateur gratuits', () {
      final fields = buildDefaultSubscriptionUserFields(
        phoneVerified: true,
        proVerified: true,
      );
      expect(fields['subscriptionPlan'], 'free');
      expect(fields['subscriptionStatus'], 'inactive');
      expect(fields['subscriptionExpiresAt'], isNull);
      expect(fields['phoneVerified'], isTrue);
      expect(fields['proVerified'], isTrue);
    });

    test('couvre les droits fonctionnels des trois plans', () {
      final free = getFeaturesForPlan('free', freeAccessMode: false);
      expect(free.canUseDirectCall, isFalse);
      expect(free.canBoostOffer, isFalse);
      expect(free.maxActiveOffers, 3);
      expect(free.maxPhotosPerOffer, 1);
      expect(free.maxAiDraftsPerMonth, kFreeAiDraftQuotaPerMonth);
      expect(free.maxVoiceAiUsesPerMonth, kFreeVoiceAiQuotaPerMonth);
      expect(free.hasUnlimitedAiDrafts, isFalse);
      expect(free.hasUnlimitedVoiceAiUses, isFalse);

      final plus = getFeaturesForSubscriptionPlan(SubscriptionPlan.iliprestoPlus);
      expect(plus.canReceiveFavoriteAlerts, isTrue);
      expect(plus.hasVerifiedBadge, isTrue);
      expect(plus.maxActiveOffers, 10);
      expect(plus.maxPhotosPerOffer, 5);
      expect(plus.hasUnlimitedAiDrafts, isTrue);
      expect(plus.hasUnlimitedVoiceAiUses, isFalse);

      final pro = getFeaturesForSubscriptionPlan(SubscriptionPlan.ilipro);
      expect(pro.canAccessStats, isTrue);
      expect(pro.canCreateProProfile, isTrue);
      expect(pro.hasProBadge, isTrue);
      expect(pro.maxActiveOffers, 30);
      expect(pro.maxPhotosPerOffer, 10);
      expect(pro.hasUnlimitedAiDrafts, isTrue);
      expect(pro.hasUnlimitedVoiceAiUses, isTrue);
    });

    test('couvre les pièces jointes avec et sans accès libre', () {
      final freeAccess = getConversationAttachmentEntitlements(
        SubscriptionPlan.free,
      );
      expect(freeAccess.canSendDocuments, isTrue);
      expect(freeAccess.maxPhotosPerConversation, 999);
      expect(freeAccess.maxAudioPerConversation, 999);

      final free = getConversationAttachmentEntitlements(
        SubscriptionPlan.free,
        freeAccessMode: false,
      );
      expect(free.canSendDocuments, isFalse);
      expect(free.maxPhotosPerConversation, 1);
      expect(free.maxAudioPerConversation, 1);

      for (final plan in <SubscriptionPlan>[
        SubscriptionPlan.iliprestoPlus,
        SubscriptionPlan.ilipro,
      ]) {
        final paid = getConversationAttachmentEntitlements(
          plan,
          freeAccessMode: false,
        );
        expect(paid.canSendDocuments, isTrue);
        expect(paid.maxPhotosPerConversation, 999);
        expect(paid.maxAudioPerConversation, 999);
      }
    });

    test('couvre les droits parcours des trois plans', () {
      final free = getJourneyEntitlementsForPlan(SubscriptionPlan.free);
      expect(free.maxLocalSavesPerMonth, kFreeJourneyLocalSaveQuotaPerMonth);
      expect(free.canExportPdf, isFalse);
      expect(free.maxPdfExportsPerMonth, 0);
      expect(free.pdfRequiresLogo, isFalse);
      expect(free.pdfRequiresWatermark, isFalse);
      expect(free.hasUnlimitedLocalSaves, isFalse);
      expect(free.hasUnlimitedPdfExports, isFalse);

      final plus = getJourneyEntitlementsForPlan(SubscriptionPlan.iliprestoPlus);
      expect(plus.maxLocalSavesPerMonth, kIliPrestoPlusJourneyLocalSaveQuotaPerMonth);
      expect(plus.maxPdfExportsPerMonth, kIliPrestoPlusJourneyPdfExportQuotaPerMonth);
      expect(plus.canExportPdf, isTrue);
      expect(plus.pdfRequiresLogo, isTrue);
      expect(plus.pdfRequiresWatermark, isTrue);

      final pro = getJourneyEntitlementsForPlan(SubscriptionPlan.ilipro);
      expect(pro.maxLocalSavesPerMonth, kIliProJourneyLocalSaveQuotaPerMonth);
      expect(pro.maxPdfExportsPerMonth, kIliProJourneyPdfExportQuotaPerMonth);
      expect(pro.canExportPdf, isTrue);
    });

    test('reconnaît explicitement les quotas illimités', () {
      const features = SubscriptionFeatures(
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
        maxActiveOffers: 1,
        maxPhotosPerOffer: 1,
        maxAiDraftsPerMonth: kUnlimitedSubscriptionFeatureQuota,
        maxVoiceAiUsesPerMonth: kUnlimitedSubscriptionFeatureQuota,
      );
      expect(features.hasUnlimitedAiDrafts, isTrue);
      expect(features.hasUnlimitedVoiceAiUses, isTrue);

      const journey = JourneyEntitlements(
        maxLocalSavesPerMonth: kUnlimitedJourneyQuota,
        canExportPdf: true,
        maxPdfExportsPerMonth: kUnlimitedJourneyQuota,
        pdfRequiresLogo: true,
        pdfRequiresWatermark: true,
      );
      expect(journey.hasUnlimitedLocalSaves, isTrue);
      expect(journey.hasUnlimitedPdfExports, isTrue);
    });
  });
}

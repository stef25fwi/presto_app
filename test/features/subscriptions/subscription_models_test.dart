import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/subscriptions/subscription_models.dart';

void main() {
  group('configuration abonnement', () {
    test('defaults active le mode gratuit préparé', () {
      const config = SubscriptionAppConfig.defaults();

      expect(config.subscriptionSectionEnabled, isFalse);
      expect(config.subscriptionsPrepared, isTrue);
      expect(config.stripeEnabled, isFalse);
      expect(config.freeAccessMode, isTrue);
      expect(config.updatedAt, isNull);
      expect(config.updatedBy, isNull);
    });

    test('fromMap parse les valeurs et toFirestoreMap les restitue', () {
      final updatedAt = Timestamp.fromDate(DateTime.utc(2026, 7, 15));
      final config = SubscriptionAppConfig.fromMap(<String, dynamic>{
        'subscriptionSectionEnabled': true,
        'subscriptionsPrepared': false,
        'stripeEnabled': true,
        'freeAccessMode': false,
        'updatedAt': updatedAt,
        'updatedBy': '  admin  ',
      });

      expect(config.subscriptionSectionEnabled, isTrue);
      expect(config.subscriptionsPrepared, isFalse);
      expect(config.stripeEnabled, isTrue);
      expect(config.freeAccessMode, isFalse);
      expect(config.updatedAt, updatedAt);
      expect(config.updatedBy, 'admin');

      final map = config.toFirestoreMap(nextUpdatedBy: 'owner');
      expect(map['updatedAt'], updatedAt);
      expect(map['updatedBy'], 'owner');
      expect(
        config.toFirestoreMap(includeServerTimestamp: true)['updatedAt'],
        isA<FieldValue>(),
      );
    });

    test('fromMap null applique les replis', () {
      final config = SubscriptionAppConfig.fromMap(null);
      expect(config.subscriptionSectionEnabled, isFalse);
      expect(config.subscriptionsPrepared, isTrue);
      expect(config.stripeEnabled, isFalse);
      expect(config.freeAccessMode, isTrue);
    });
  });

  group('état utilisateur', () {
    test('free construit et sérialise l état initial', () {
      const state = AppUserSubscriptionState.free();
      final map = state.toFirestoreSeedMap();

      expect(state.plan, SubscriptionPlan.free);
      expect(state.status, SubscriptionStatus.inactive);
      expect(state.subscriptionExpiresAt, isNull);
      expect(map['subscriptionPlan'], 'free');
      expect(map['subscriptionStatus'], 'inactive');
      expect(map['phoneVerified'], isFalse);
      expect(map['proVerified'], isFalse);
    });

    test('fromMap accepte les alias et formats de date', () {
      final state = AppUserSubscriptionState.fromMap(<String, dynamic>{
        'subscriptionPlan': ' iliPresto+ ',
        'subscriptionStatus': 'pastdue',
        'subscriptionExpiresAt': '2026-08-01T12:00:00.000Z',
        'isPhoneVerified': true,
        'siretVerified': true,
      });

      expect(state.plan, SubscriptionPlan.iliprestoPlus);
      expect(state.status, SubscriptionStatus.pastDue);
      expect(state.phoneVerified, isTrue);
      expect(state.proVerified, isTrue);
      expect(
        state.subscriptionExpiresAt,
        DateTime.parse('2026-08-01T12:00:00.000Z'),
      );

      final timestampState = AppUserSubscriptionState.fromMap(<String, dynamic>{
        'subscriptionExpiresAt': Timestamp.fromMillisecondsSinceEpoch(1234),
      });
      final intState = AppUserSubscriptionState.fromMap(<String, dynamic>{
        'subscriptionExpiresAt': 5678,
      });
      final date = DateTime.utc(2026, 9, 1);
      final dateState = AppUserSubscriptionState.fromMap(<String, dynamic>{
        'subscriptionExpiresAt': date,
      });

      expect(timestampState.subscriptionExpiresAt?.millisecondsSinceEpoch, 1234);
      expect(intState.subscriptionExpiresAt?.millisecondsSinceEpoch, 5678);
      expect(dateState.subscriptionExpiresAt, date);
    });
  });

  test('normalise toutes les clés, labels et statuts', () {
    expect(subscriptionPlanFromKey(null), SubscriptionPlan.free);
    expect(subscriptionPlanFromKey('ilipresto_plus'), SubscriptionPlan.iliprestoPlus);
    expect(subscriptionPlanFromKey('iliprestoplus'), SubscriptionPlan.iliprestoPlus);
    expect(subscriptionPlanFromKey('ILIPRESTO+'), SubscriptionPlan.iliprestoPlus);
    expect(subscriptionPlanFromKey('ilipro'), SubscriptionPlan.ilipro);
    expect(subscriptionStatusFromKey(null), SubscriptionStatus.inactive);
    expect(subscriptionStatusFromKey('active'), SubscriptionStatus.active);
    expect(subscriptionStatusFromKey('past_due'), SubscriptionStatus.pastDue);
    expect(subscriptionStatusFromKey('pastdue'), SubscriptionStatus.pastDue);
    expect(subscriptionStatusFromKey('canceled'), SubscriptionStatus.canceled);
    expect(subscriptionStatusFromKey('cancelled'), SubscriptionStatus.canceled);

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

  test('buildDefaultSubscriptionUserFields conserve les vérifications', () {
    final map = buildDefaultSubscriptionUserFields(
      phoneVerified: true,
      proVerified: true,
    );
    expect(map['subscriptionPlan'], 'free');
    expect(map['subscriptionStatus'], 'inactive');
    expect(map['phoneVerified'], isTrue);
    expect(map['proVerified'], isTrue);
  });

  group('fonctionnalités par plan', () {
    test('gratuit applique le mode libre et le mode restreint', () {
      final open = getFeaturesForPlan('free');
      final restricted = getFeaturesForSubscriptionPlan(
        SubscriptionPlan.free,
        freeAccessMode: false,
      );

      expect(open.canUseDirectCall, isTrue);
      expect(open.canBoostOffer, isTrue);
      expect(open.maxActiveOffers, 3);
      expect(open.maxPhotosPerOffer, 1);
      expect(open.maxAiDraftsPerMonth, kFreeAiDraftQuotaPerMonth);
      expect(open.maxVoiceAiUsesPerMonth, kFreeVoiceAiQuotaPerMonth);
      expect(open.hasUnlimitedAiDrafts, isFalse);
      expect(open.hasUnlimitedVoiceAiUses, isFalse);
      expect(restricted.canUseDirectCall, isFalse);
      expect(restricted.canBoostOffer, isFalse);
    });

    test('ilipresto+ expose les avantages grand public', () {
      final features = getFeaturesForSubscriptionPlan(SubscriptionPlan.iliprestoPlus);
      expect(features.maxActiveOffers, 10);
      expect(features.maxPhotosPerOffer, 5);
      expect(features.hasUnlimitedAiDrafts, isTrue);
      expect(features.hasUnlimitedVoiceAiUses, isFalse);
      expect(features.hasVerifiedBadge, isTrue);
      expect(features.hasProBadge, isFalse);
      expect(features.canReceiveFavoriteAlerts, isTrue);
      expect(features.canAccessStats, isFalse);
    });

    test('ilipro expose les capacités professionnelles', () {
      final features = getFeaturesForSubscriptionPlan(SubscriptionPlan.ilipro);
      expect(features.maxActiveOffers, 30);
      expect(features.maxPhotosPerOffer, 10);
      expect(features.hasUnlimitedAiDrafts, isTrue);
      expect(features.hasUnlimitedVoiceAiUses, isTrue);
      expect(features.canAccessStats, isTrue);
      expect(features.canCreateProProfile, isTrue);
      expect(features.hasProBadge, isTrue);
    });
  });

  group('pièces jointes de conversation', () {
    test('mode libre ouvre les pièces jointes', () {
      final rights = getConversationAttachmentEntitlements(SubscriptionPlan.free);
      expect(rights.canSendDocuments, isTrue);
      expect(rights.maxPhotosPerConversation, 999);
      expect(rights.maxAudioPerConversation, 999);
    });

    test('gratuit est limité lorsque le mode libre est désactivé', () {
      final rights = getConversationAttachmentEntitlements(
        SubscriptionPlan.free,
        freeAccessMode: false,
      );
      expect(rights.canSendDocuments, isFalse);
      expect(rights.maxPhotosPerConversation, 1);
      expect(rights.maxAudioPerConversation, 1);
    });

    test('les plans payants autorisent les documents', () {
      for (final plan in <SubscriptionPlan>[
        SubscriptionPlan.iliprestoPlus,
        SubscriptionPlan.ilipro,
      ]) {
        final rights = getConversationAttachmentEntitlements(
          plan,
          freeAccessMode: false,
        );
        expect(rights.canSendDocuments, isTrue, reason: plan.name);
      }
    });
  });

  test('les droits parcours couvrent les trois plans et l illimité', () {
    final free = getJourneyEntitlementsForPlan(SubscriptionPlan.free);
    final plus = getJourneyEntitlementsForPlan(SubscriptionPlan.iliprestoPlus);
    final pro = getJourneyEntitlementsForPlan(SubscriptionPlan.ilipro);
    const unlimited = JourneyEntitlements(
      maxLocalSavesPerMonth: kUnlimitedJourneyQuota,
      canExportPdf: true,
      maxPdfExportsPerMonth: kUnlimitedJourneyQuota,
      pdfRequiresLogo: true,
      pdfRequiresWatermark: true,
    );

    expect(free.maxLocalSavesPerMonth, kFreeJourneyLocalSaveQuotaPerMonth);
    expect(free.canExportPdf, isFalse);
    expect(free.maxPdfExportsPerMonth, 0);
    expect(plus.maxLocalSavesPerMonth, kIliPrestoPlusJourneyLocalSaveQuotaPerMonth);
    expect(plus.maxPdfExportsPerMonth, kIliPrestoPlusJourneyPdfExportQuotaPerMonth);
    expect(pro.maxLocalSavesPerMonth, kIliProJourneyLocalSaveQuotaPerMonth);
    expect(pro.maxPdfExportsPerMonth, kIliProJourneyPdfExportQuotaPerMonth);
    expect(plus.pdfRequiresLogo, isTrue);
    expect(pro.pdfRequiresWatermark, isTrue);
    expect(unlimited.hasUnlimitedLocalSaves, isTrue);
    expect(unlimited.hasUnlimitedPdfExports, isTrue);
  });
}

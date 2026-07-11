import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/subscriptions/subscription_models.dart';

void main() {
  group('normalisation des plans et statuts', () {
    test('normalise les alias de plan existants', () {
      expect(subscriptionPlanFromKey('free'), SubscriptionPlan.free);
      expect(subscriptionPlanFromKey('ilipresto_plus'), SubscriptionPlan.iliprestoPlus);
      expect(subscriptionPlanFromKey('iliprestoplus'), SubscriptionPlan.iliprestoPlus);
      expect(subscriptionPlanFromKey('ilipresto+'), SubscriptionPlan.iliprestoPlus);
      expect(subscriptionPlanFromKey('ilipro'), SubscriptionPlan.ilipro);
      expect(subscriptionPlanFromKey('inconnu'), SubscriptionPlan.free);
    });

    test('normalise les statuts existants', () {
      expect(subscriptionStatusFromKey('active'), SubscriptionStatus.active);
      expect(subscriptionStatusFromKey('past_due'), SubscriptionStatus.pastDue);
      expect(subscriptionStatusFromKey('pastdue'), SubscriptionStatus.pastDue);
      expect(subscriptionStatusFromKey('cancelled'), SubscriptionStatus.canceled);
      expect(subscriptionStatusFromKey(null), SubscriptionStatus.inactive);
    });

    test('sérialise les clés stables', () {
      expect(subscriptionPlanKey(SubscriptionPlan.free), 'free');
      expect(subscriptionPlanKey(SubscriptionPlan.iliprestoPlus), 'ilipresto_plus');
      expect(subscriptionPlanKey(SubscriptionPlan.ilipro), 'ilipro');
      expect(subscriptionStatusKey(SubscriptionStatus.pastDue), 'past_due');
    });
  });

  group('fonctionnalités par plan', () {
    test('gratuit applique les quotas attendus', () {
      final features = getFeaturesForSubscriptionPlan(SubscriptionPlan.free);
      expect(features.maxActiveOffers, 3);
      expect(features.maxPhotosPerOffer, 1);
      expect(features.maxAiDraftsPerMonth, kFreeAiDraftQuotaPerMonth);
      expect(features.maxVoiceAiUsesPerMonth, kFreeVoiceAiQuotaPerMonth);
      expect(features.canReceiveFavoriteAlerts, isFalse);
      expect(features.canAccessStats, isFalse);
      expect(features.canCreateProProfile, isFalse);
    });

    test('iliprestō+ active les avantages grand public', () {
      final features = getFeaturesForSubscriptionPlan(SubscriptionPlan.iliprestoPlus);
      expect(features.maxActiveOffers, 10);
      expect(features.maxPhotosPerOffer, 5);
      expect(features.hasUnlimitedAiDrafts, isTrue);
      expect(features.maxVoiceAiUsesPerMonth, kIliPrestoPlusVoiceAiQuotaPerMonth);
      expect(features.canReceiveFavoriteAlerts, isTrue);
      expect(features.canAccessStats, isFalse);
      expect(features.canCreateProProfile, isFalse);
    });

    test('ilipro conserve les capacités professionnelles', () {
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

  group('droits du parcours entrepreneur', () {
    test('gratuit peut sauvegarder mais pas exporter en PDF', () {
      final rights = getJourneyEntitlementsForPlan(SubscriptionPlan.free);
      expect(rights.maxLocalSavesPerMonth, kFreeJourneyLocalSaveQuotaPerMonth);
      expect(rights.canExportPdf, isFalse);
      expect(rights.maxPdfExportsPerMonth, 0);
      expect(rights.pdfRequiresLogo, isFalse);
      expect(rights.pdfRequiresWatermark, isFalse);
    });

    test('iliprestō+ applique les quotas PDF et le branding', () {
      final rights = getJourneyEntitlementsForPlan(SubscriptionPlan.iliprestoPlus);
      expect(rights.maxLocalSavesPerMonth, kIliPrestoPlusJourneyLocalSaveQuotaPerMonth);
      expect(rights.maxPdfExportsPerMonth, kIliPrestoPlusJourneyPdfExportQuotaPerMonth);
      expect(rights.canExportPdf, isTrue);
      expect(rights.pdfRequiresLogo, isTrue);
      expect(rights.pdfRequiresWatermark, isTrue);
    });

    test('ilipro applique les quotas professionnels', () {
      final rights = getJourneyEntitlementsForPlan(SubscriptionPlan.ilipro);
      expect(rights.maxLocalSavesPerMonth, kIliProJourneyLocalSaveQuotaPerMonth);
      expect(rights.maxPdfExportsPerMonth, kIliProJourneyPdfExportQuotaPerMonth);
      expect(rights.canExportPdf, isTrue);
    });
  });

  group('pièces jointes de conversation', () {
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
}

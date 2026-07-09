import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/subscriptions/subscription_models.dart';

void main() {
  test('free plan is capped when subscriptions are restricted', () {
    final features = getFeaturesForSubscriptionPlan(
      SubscriptionPlan.free,
      freeAccessMode: false,
    );

    expect(features.maxMonthlyOfferReplies, 3);
    expect(features.maxFavorites, 5);
    expect(features.maxMonthlyAiAdDrafts, 1);
    expect(features.maxActiveOffers, 3);
    expect(features.maxPhotosPerOffer, 3);
    expect(features.canUseAiDraft, isTrue);
    expect(features.canUseDirectCall, isFalse);
    expect(features.hasInstantAlerts, isFalse);
    expect(features.hasCategoryAlerts, isFalse);
    expect(features.hasUnlimitedOfferReplies, isFalse);
    expect(features.hasUnlimitedFavorites, isFalse);
    expect(features.hasUnlimitedAiAdDrafts, isFalse);
  });

  test('ilipresto+ unlocks unlimited quotas when subscriptions are restricted', () {
    final features = getFeaturesForSubscriptionPlan(
      SubscriptionPlan.iliprestoPlus,
      freeAccessMode: false,
    );

    expect(features.hasUnlimitedOfferReplies, isTrue);
    expect(features.hasUnlimitedFavorites, isTrue);
    expect(features.hasUnlimitedAiAdDrafts, isTrue);
    expect(features.maxActiveOffers, 10);
    expect(features.maxPhotosPerOffer, 12);
    expect(features.hasInstantAlerts, isTrue);
    expect(features.hasCategoryAlerts, isTrue);
    expect(features.hasVerifiedBadge, isTrue);
    expect(features.hasProBadge, isFalse);
  });

  test('ilipro keeps 10 photos per offer even though it has fewer than ilipresto+', () {
    final features = getFeaturesForSubscriptionPlan(
      SubscriptionPlan.ilipro,
      freeAccessMode: false,
    );

    expect(features.maxPhotosPerOffer, 10);
    expect(features.maxActiveOffers, 50);
    expect(features.canAccessStats, isTrue);
    expect(features.canCreateProProfile, isTrue);
    expect(features.hasProBadge, isTrue);
    expect(features.hasUnlimitedOfferReplies, isTrue);
    expect(features.hasUnlimitedFavorites, isTrue);
    expect(features.hasUnlimitedAiAdDrafts, isTrue);
  });

  test('freeAccessMode=true removes every restriction regardless of plan', () {
    final features = getFeaturesForSubscriptionPlan(
      SubscriptionPlan.free,
      freeAccessMode: true,
    );

    expect(features.canUseAiDraft, isTrue);
    expect(features.canUseDirectCall, isTrue);
    expect(features.hasInstantAlerts, isTrue);
    expect(features.hasCategoryAlerts, isTrue);
    expect(features.hasUnlimitedOfferReplies, isTrue);
    expect(features.hasUnlimitedFavorites, isTrue);
    expect(features.hasUnlimitedAiAdDrafts, isTrue);
  });

  test('technical plan keys stay stable while the ilipresto+ display label carries the brand accent', () {
    expect(subscriptionPlanKey(SubscriptionPlan.free), 'free');
    expect(subscriptionPlanKey(SubscriptionPlan.iliprestoPlus), 'ilipresto_plus');
    expect(subscriptionPlanKey(SubscriptionPlan.ilipro), 'ilipro');
    expect(subscriptionPlanLabel(SubscriptionPlan.iliprestoPlus), 'iliprestō+');
  });
}

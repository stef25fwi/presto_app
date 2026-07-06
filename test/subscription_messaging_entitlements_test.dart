import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/subscriptions/subscription_models.dart';

void main() {
  test('free access mode keeps messaging attachments open for free users', () {
    final entitlements = getConversationAttachmentEntitlements(
      SubscriptionPlan.free,
      freeAccessMode: true,
    );

    expect(entitlements.canSendDocuments, isTrue);
    expect(entitlements.maxPhotosPerConversation, greaterThan(100));
    expect(entitlements.maxAudioPerConversation, greaterThan(100));
  });

  test('free plan is prepared with messaging limits when subscriptions activate', () {
    final entitlements = getConversationAttachmentEntitlements(
      SubscriptionPlan.free,
      freeAccessMode: false,
    );

    expect(entitlements.canSendDocuments, isFalse);
    expect(entitlements.maxPhotosPerConversation, 1);
    expect(entitlements.maxAudioPerConversation, 1);
  });

  test('ilipresto+ unlocks documents and extended messaging attachments', () {
    final entitlements = getConversationAttachmentEntitlements(
      SubscriptionPlan.iliprestoPlus,
      freeAccessMode: false,
    );

    expect(entitlements.canSendDocuments, isTrue);
    expect(entitlements.maxPhotosPerConversation, greaterThan(100));
    expect(entitlements.maxAudioPerConversation, greaterThan(100));
  });
}

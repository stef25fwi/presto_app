import 'package:flutter/material.dart';

import 'subscription_checkout_service.dart';
import 'subscription_models.dart';

const SubscriptionCheckoutService _checkoutService =
    SubscriptionCheckoutService();

Future<void> startSubscriptionCheckout(
  BuildContext context,
  String plan, {
  bool stripeEnabled = false,
  String source = 'subscription_ui',
}) async {
  await _checkoutService.handleAction(
    context,
    SubscriptionActionRequest(
      action: SubscriptionActionType.checkout,
      plan: subscriptionPlanFromKey(plan),
      source: source,
      stripeEnabled: stripeEnabled,
    ),
  );
}

Future<void> prefetchSubscriptionCheckout(
  String plan, {
  bool stripeEnabled = false,
  String source = 'subscription_prefetch',
}) async {
  if (!stripeEnabled) return;
  await _checkoutService.prefetchCheckout(
    subscriptionPlanFromKey(plan),
    source: source,
  );
}

Future<void> openSubscriptionManagement(
  BuildContext context, {
  bool stripeEnabled = false,
  String source = 'subscription_ui',
}) async {
  await _checkoutService.handleAction(
    context,
    SubscriptionActionRequest(
      action: SubscriptionActionType.manage,
      source: source,
      stripeEnabled: stripeEnabled,
    ),
  );
}

Future<void> notifySubscriptionLaunch(
  BuildContext context,
  String plan, {
  bool stripeEnabled = false,
  String source = 'subscription_ui',
}) async {
  await _checkoutService.handleAction(
    context,
    SubscriptionActionRequest(
      action: SubscriptionActionType.notify,
      plan: subscriptionPlanFromKey(plan),
      source: source,
      stripeEnabled: stripeEnabled,
    ),
  );
}

import 'package:flutter/material.dart';

import '../operating_mode/app_operating_mode.dart';
import 'subscription_checkout_service.dart';
import 'subscription_models.dart';

const SubscriptionCheckoutService _checkoutService =
    SubscriptionCheckoutService();

typedef SubscriptionCommercialModeResolver = Future<bool> Function();

@visibleForTesting
SubscriptionCommercialModeResolver? subscriptionCommercialModeResolverOverride;

@visibleForTesting
SubscriptionCheckoutService? subscriptionCheckoutServiceOverride;

SubscriptionCheckoutService get _resolvedCheckoutService =>
    subscriptionCheckoutServiceOverride ?? _checkoutService;

@visibleForTesting
void resetSubscriptionActionOverrides() {
  subscriptionCommercialModeResolverOverride = null;
  subscriptionCheckoutServiceOverride = null;
}

Future<bool> _isCommercialMode() async {
  final override = subscriptionCommercialModeResolverOverride;
  if (override != null) return override();
  try {
    return (await AppOperatingModeService().getState()).mode.isCommercial;
  } catch (_) {
    // Fail closed: une configuration indisponible ne doit jamais ouvrir Stripe.
    return false;
  }
}

@visibleForTesting
Future<bool> resolveSubscriptionCommercialModeForTesting() =>
    _isCommercialMode();

void _showFreeBetaMessage(BuildContext context) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    const SnackBar(
      content: Text(
        'Ilipresto est actuellement en bêta gratuite. Aucun abonnement ou paiement n’est actif.',
      ),
    ),
  );
}

Future<void> startSubscriptionCheckout(
  BuildContext context,
  String plan, {
  bool stripeEnabled = false,
  String source = 'subscription_ui',
}) async {
  final parsedPlan = subscriptionPlanFromKey(plan);
  if (parsedPlan == SubscriptionPlan.free) {
    await _resolvedCheckoutService.handleAction(
      context,
      SubscriptionActionRequest(
        action: SubscriptionActionType.checkout,
        plan: parsedPlan,
        source: source,
        stripeEnabled: false,
      ),
    );
    return;
  }
  if (!stripeEnabled || !await _isCommercialMode()) {
    if (context.mounted) _showFreeBetaMessage(context);
    return;
  }
  await _resolvedCheckoutService.handleAction(
    context,
    SubscriptionActionRequest(
      action: SubscriptionActionType.checkout,
      plan: parsedPlan,
      source: source,
      stripeEnabled: true,
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
  if (!stripeEnabled || !await _isCommercialMode()) {
    if (context.mounted) _showFreeBetaMessage(context);
    return;
  }
  await _resolvedCheckoutService.handleAction(
    context,
    SubscriptionActionRequest(
      action: SubscriptionActionType.manage,
      source: source,
      stripeEnabled: true,
    ),
  );
}

Future<void> notifySubscriptionLaunch(
  BuildContext context,
  String plan, {
  bool stripeEnabled = false,
  String source = 'subscription_ui',
}) async {
  await _resolvedCheckoutService.handleAction(
    context,
    SubscriptionActionRequest(
      action: SubscriptionActionType.notify,
      plan: subscriptionPlanFromKey(plan),
      source: source,
      stripeEnabled: stripeEnabled,
    ),
  );
}

import 'package:flutter/material.dart';

import 'subscription_models.dart';

enum SubscriptionActionType {
  checkout,
  manage,
  notify,
}

class SubscriptionActionRequest {
  final SubscriptionActionType action;
  final SubscriptionPlan? plan;
  final String source;
  final bool stripeEnabled;

  const SubscriptionActionRequest({
    required this.action,
    required this.source,
    required this.stripeEnabled,
    this.plan,
  });
}

class SubscriptionCheckoutService {
  const SubscriptionCheckoutService();

  Future<void> handleAction(
    BuildContext context,
    SubscriptionActionRequest request,
  ) async {
    switch (request.action) {
      case SubscriptionActionType.checkout:
        return _showSnackBar(
          context,
          request.stripeEnabled
              ? 'Le parcours de paiement sera branché prochainement.'
              : 'Le paiement sera bientôt disponible.',
        );
      case SubscriptionActionType.manage:
        return _showSnackBar(
          context,
          request.stripeEnabled
              ? 'La gestion des abonnements sera branchée prochainement.'
              : 'La gestion des abonnements sera bientôt disponible.',
        );
      case SubscriptionActionType.notify:
        return _showSnackBar(
          context,
          'Vous serez informé lorsque cette formule sera disponible.',
        );
    }
  }

  Future<void> _showSnackBar(BuildContext context, String message) async {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

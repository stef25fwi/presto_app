import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/firebase_functions_region.dart';
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
        if (!request.stripeEnabled) {
          return _showSnackBar(context, 'Le paiement sera bientôt disponible.');
        }
        return _startCheckout(context, request);
      case SubscriptionActionType.manage:
        if (!request.stripeEnabled) {
          return _showSnackBar(
            context,
            'La gestion des abonnements sera bientôt disponible.',
          );
        }
        return _openBillingPortal(context, request);
      case SubscriptionActionType.notify:
        return _showSnackBar(
          context,
          'Vous serez informé lorsque cette formule sera disponible.',
        );
    }
  }

  Future<void> _startCheckout(
    BuildContext context,
    SubscriptionActionRequest request,
  ) async {
    final plan = request.plan;
    if (plan == null || plan == SubscriptionPlan.free) {
      return _showSnackBar(context, 'Formule invalide pour le paiement.');
    }

    try {
      final result = await callPrestoFunction<Map<String, Object?>>(
        functions: prestoFirebaseFunctions,
        name: 'createCheckoutSession',
        timeout: const Duration(seconds: 20),
        parameters: <String, Object?>{'plan': subscriptionPlanKey(plan)},
        area: 'billing',
      );
      final url = result.data['url'] as String?;
      if (url == null || url.isEmpty) {
        if (!context.mounted) return;
        return _showSnackBar(
          context,
          "Impossible d'ouvrir le paiement pour le moment.",
        );
      }
      final uri = Uri.parse(url);
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        _showSnackBar(context, "Impossible d'ouvrir la page de paiement.");
      }
    } on FirebaseFunctionsException catch (error) {
      if (!context.mounted) return;
      _showSnackBar(
        context,
        _friendlyCheckoutError(error),
      );
    } catch (_) {
      if (!context.mounted) return;
      _showSnackBar(context, "Impossible d'ouvrir le paiement pour le moment.");
    }
  }

  Future<void> _openBillingPortal(
    BuildContext context,
    SubscriptionActionRequest request,
  ) async {
    try {
      final result = await callPrestoFunction<Map<String, Object?>>(
        functions: prestoFirebaseFunctions,
        name: 'createBillingPortalSession',
        timeout: const Duration(seconds: 20),
        area: 'billing',
      );
      final url = result.data['url'] as String?;
      if (url == null || url.isEmpty) {
        if (!context.mounted) return;
        return _showSnackBar(
          context,
          "Impossible d'ouvrir la gestion de l'abonnement.",
        );
      }
      final uri = Uri.parse(url);
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        _showSnackBar(context, "Impossible d'ouvrir la gestion de l'abonnement.");
      }
    } on FirebaseFunctionsException catch (error) {
      if (!context.mounted) return;
      if (error.code == 'failed-precondition') {
        return _showSnackBar(
          context,
          "Aucun abonnement actif à gérer pour le moment.",
        );
      }
      _showSnackBar(context, "Impossible d'ouvrir la gestion de l'abonnement.");
    } catch (_) {
      if (!context.mounted) return;
      _showSnackBar(context, "Impossible d'ouvrir la gestion de l'abonnement.");
    }
  }

  String _friendlyCheckoutError(FirebaseFunctionsException error) {
    if (error.code == 'failed-precondition') {
      return 'Cette formule n\'est pas encore disponible au paiement.';
    }
    return "Impossible d'ouvrir le paiement pour le moment.";
  }

  Future<void> _showSnackBar(BuildContext context, String message) async {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

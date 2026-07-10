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
    if (!request.stripeEnabled) {
      return _showSnackBar(
        context,
        request.action == SubscriptionActionType.manage
            ? 'La gestion des abonnements sera bientôt disponible.'
            : 'Le paiement sera bientôt disponible.',
      );
    }

    switch (request.action) {
      case SubscriptionActionType.checkout:
        final plan = request.plan;
        if (plan == null || plan == SubscriptionPlan.free) {
          return _showSnackBar(
            context,
            'Cette formule ne nécessite pas de paiement.',
          );
        }
        return _openStripeUrl(
          context,
          callableName: 'createSubscriptionCheckoutSession',
          payload: <String, dynamic>{
            'plan': subscriptionPlanKey(plan),
            'source': request.source,
          },
        );
      case SubscriptionActionType.manage:
        return _openStripeUrl(
          context,
          callableName: 'createSubscriptionPortalSession',
          payload: <String, dynamic>{
            'source': request.source,
          },
        );
      case SubscriptionActionType.notify:
        return _showSnackBar(
          context,
          'Vous serez informé lorsque cette formule sera disponible.',
        );
    }
  }

  Future<void> _openStripeUrl(
    BuildContext context, {
    required String callableName,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final callable = prestoFirebaseFunctions.httpsCallable(
        callableName,
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );
      final response = await callable.call<Map<dynamic, dynamic>>(payload);
      final data = Map<String, dynamic>.from(response.data);
      final rawUrl = (data['url'] ?? '').toString().trim();
      final uri = Uri.tryParse(rawUrl);
      if (uri == null || !uri.hasScheme) {
        throw const SubscriptionCheckoutException(
          'URL Stripe invalide ou manquante.',
        );
      }

      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_self',
      );
      if (!opened) {
        throw const SubscriptionCheckoutException(
          'Impossible d’ouvrir la page Stripe.',
        );
      }
    } on FirebaseFunctionsException catch (error) {
      if (!context.mounted) return;
      await _showSnackBar(
        context,
        error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'Impossible de lancer Stripe pour le moment.',
      );
    } catch (error) {
      if (!context.mounted) return;
      await _showSnackBar(
        context,
        error is SubscriptionCheckoutException
            ? error.message
            : 'Impossible de lancer Stripe pour le moment.',
      );
    }
  }

  Future<void> _showSnackBar(BuildContext context, String message) async {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class SubscriptionCheckoutException implements Exception {
  final String message;

  const SubscriptionCheckoutException(this.message);

  @override
  String toString() => message;
}

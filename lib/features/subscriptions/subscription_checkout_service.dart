import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/firebase_functions_region.dart';
import 'subscription_models.dart';
import 'subscription_return_history.dart';

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
        final plan = request.plan;
        if (plan == null || plan == SubscriptionPlan.free) {
          return _showSnackBar(
            context,
            'Cette formule ne nécessite pas de paiement.',
          );
        }
        return _openFirstWorkingStripeUrl(
          context,
          callableNames: _checkoutCallableNames,
          payload: <String, dynamic>{
            'plan': subscriptionPlanKey(plan),
            'subscriptionPlan': subscriptionPlanKey(plan),
            'source': request.source,
          },
          unavailableMessage: request.stripeEnabled
              ? 'Impossible de lancer Stripe pour le moment.'
              : 'Stripe n’est pas activé dans la configuration abonnement.',
        );
      case SubscriptionActionType.manage:
        return _openFirstWorkingStripeUrl(
          context,
          callableNames: _portalCallableNames,
          payload: <String, dynamic>{
            'source': request.source,
          },
          unavailableMessage: request.stripeEnabled
              ? 'Impossible d’ouvrir la gestion Stripe pour le moment.'
              : 'La gestion Stripe n’est pas activée dans la configuration abonnement.',
        );
      case SubscriptionActionType.notify:
        return _showSnackBar(
          context,
          'Vous serez informé lorsque cette formule sera disponible.',
        );
    }
  }

  static const List<String> _checkoutCallableNames = [
    // Nouvelle couche abonnement.
    'createSubscriptionCheckoutSession',
    // Noms compatibles avec les implémentations Stripe déjà testées.
    'createStripeCheckoutSession',
    'createCheckoutSession',
    'createSubscriptionCheckout',
    'createStripeSubscriptionCheckout',
    'createStripeSubscriptionCheckoutSession',
    'startSubscriptionCheckout',
    'createBillingCheckoutSession',
  ];

  static const List<String> _portalCallableNames = [
    // Nouvelle couche abonnement.
    'createSubscriptionPortalSession',
    // Noms compatibles avec les implémentations Stripe déjà testées.
    'createStripePortalSession',
    'createCustomerPortalSession',
    'createBillingPortalSession',
    'createPortalSession',
    'createStripeCustomerPortalSession',
  ];

  Future<void> _openFirstWorkingStripeUrl(
    BuildContext context, {
    required List<String> callableNames,
    required Map<String, dynamic> payload,
    required String unavailableMessage,
  }) async {
    FirebaseFunctionsException? lastFirebaseError;
    Object? lastGenericError;

    for (final callableName in callableNames) {
      try {
        final rawUrl = await _fetchStripeUrl(callableName, payload);
        final uri = Uri.tryParse(rawUrl.trim());
        if (uri == null || !uri.hasScheme) {
          throw const SubscriptionCheckoutException(
            'URL Stripe invalide ou manquante.',
          );
        }

        // Sur le Web, la navigation Flutter interne ne modifie pas toujours
        // l'URL du navigateur. On remplace donc l'entrée courante par la route
        // Compte/Abonnements avant d'ouvrir Stripe dans le même onglet. Le
        // bouton Retour du navigateur restaure ainsi la page des abonnements
        // au lieu de recharger la racine et le splash.
        prepareSubscriptionReturnHistory();

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
        return;
      } on FirebaseFunctionsException catch (error) {
        lastFirebaseError = error;
        // Si la callable n’existe pas, on essaie le nom compatible suivant.
        if (error.code == 'not-found' || error.code == 'unimplemented') {
          continue;
        }
        break;
      } catch (error) {
        lastGenericError = error;
        break;
      }
    }

    if (!context.mounted) return;
    await _showSnackBar(
      context,
      _messageForFailure(
        lastFirebaseError: lastFirebaseError,
        lastGenericError: lastGenericError,
        fallback: unavailableMessage,
      ),
    );
  }

  Future<String> _fetchStripeUrl(
    String callableName,
    Map<String, dynamic> payload,
  ) async {
    final callable = prestoFirebaseFunctions.httpsCallable(
      callableName,
      options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
    );
    final response = await callable.call<Map<dynamic, dynamic>>(payload);
    final data = Map<String, dynamic>.from(response.data);
    return _extractUrl(data);
  }

  String _extractUrl(Map<String, dynamic> data) {
    for (final key in const [
      'url',
      'checkoutUrl',
      'paymentUrl',
      'sessionUrl',
      'portalUrl',
    ]) {
      final value = (data[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }

    final session = data['session'];
    if (session is Map) {
      final value = (session['url'] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }

    throw const SubscriptionCheckoutException('URL Stripe introuvable.');
  }

  String _messageForFailure({
    required FirebaseFunctionsException? lastFirebaseError,
    required Object? lastGenericError,
    required String fallback,
  }) {
    if (lastFirebaseError != null) {
      final message = lastFirebaseError.message?.trim();
      if (message != null && message.isNotEmpty) return message;
      if (lastFirebaseError.code == 'unauthenticated') {
        return 'Connectez-vous pour gérer votre abonnement.';
      }
    }
    if (lastGenericError is SubscriptionCheckoutException) {
      return lastGenericError.message;
    }
    return fallback;
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

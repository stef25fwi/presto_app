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

  static bool _openingStripe = false;

  Future<void> handleAction(
    BuildContext context,
    SubscriptionActionRequest request,
  ) async {
    if (_openingStripe) {
      return _showSnackBar(
        context,
        'Ouverture de Stripe déjà en cours…',
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
            'subscriptionPlan': subscriptionPlanKey(plan),
            'source': request.source,
          },
          unavailableMessage: request.stripeEnabled
              ? 'Impossible de lancer Stripe pour le moment.'
              : 'Stripe n’est pas activé dans la configuration abonnement.',
        );
      case SubscriptionActionType.manage:
        return _openStripeUrl(
          context,
          callableName: 'createSubscriptionPortalSession',
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

  Future<void> _openStripeUrl(
    BuildContext context, {
    required String callableName,
    required Map<String, dynamic> payload,
    required String unavailableMessage,
  }) async {
    FirebaseFunctionsException? firebaseError;
    Object? genericError;

    _openingStripe = true;
    try {
      final rawUrl = await _fetchStripeUrl(callableName, payload);
      final uri = Uri.tryParse(rawUrl.trim());
      if (uri == null || !_isTrustedStripeUri(uri)) {
        throw const SubscriptionCheckoutException(
          'L’adresse de paiement retournée n’est pas une URL Stripe sécurisée.',
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
      firebaseError = error;
    } catch (error) {
      genericError = error;
    } finally {
      _openingStripe = false;
    }

    if (!context.mounted) return;
    await _showSnackBar(
      context,
      _messageForFailure(
        firebaseError: firebaseError,
        genericError: genericError,
        fallback: unavailableMessage,
      ),
    );
  }

  bool _isTrustedStripeUri(Uri uri) {
    if (uri.scheme.toLowerCase() != 'https') return false;
    final host = uri.host.toLowerCase();
    return host == 'stripe.com' || host.endsWith('.stripe.com');
  }

  Future<String> _fetchStripeUrl(
    String callableName,
    Map<String, dynamic> payload,
  ) async {
    final callable = prestoFirebaseFunctions.httpsCallable(
      callableName,
      options: HttpsCallableOptions(timeout: const Duration(seconds: 45)),
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
    required FirebaseFunctionsException? firebaseError,
    required Object? genericError,
    required String fallback,
  }) {
    if (firebaseError != null) {
      final message = firebaseError.message?.trim();
      if (message != null && message.isNotEmpty) return message;
      switch (firebaseError.code) {
        case 'unauthenticated':
          return 'Connectez-vous pour gérer votre abonnement.';
        case 'permission-denied':
          return 'Cette opération Stripe n’est pas autorisée.';
        case 'resource-exhausted':
          return 'Stripe reçoit trop de demandes. Réessayez dans un instant.';
        case 'unavailable':
          return 'Stripe est temporairement indisponible.';
      }
    }
    if (genericError is SubscriptionCheckoutException) {
      return genericError.message;
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

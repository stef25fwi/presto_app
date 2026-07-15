import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/firebase_functions_region.dart';
import 'subscription_models.dart';
import 'subscription_return_history.dart';

typedef SubscriptionStripeDataFetcher = Future<Map<String, dynamic>> Function(
  String callableName,
  Map<String, dynamic> payload,
);
typedef SubscriptionExternalLauncher = Future<bool> Function(Uri uri);
typedef SubscriptionClock = DateTime Function();
typedef SubscriptionReturnHistoryPreparer = void Function();

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
  const SubscriptionCheckoutService({
    SubscriptionStripeDataFetcher? stripeDataFetcher,
    SubscriptionExternalLauncher? externalLauncher,
    SubscriptionClock? clock,
    SubscriptionReturnHistoryPreparer? returnHistoryPreparer,
  })  : _stripeDataFetcherOverride = stripeDataFetcher,
        _externalLauncherOverride = externalLauncher,
        _clockOverride = clock,
        _returnHistoryPreparerOverride = returnHistoryPreparer;

  final SubscriptionStripeDataFetcher? _stripeDataFetcherOverride;
  final SubscriptionExternalLauncher? _externalLauncherOverride;
  final SubscriptionClock? _clockOverride;
  final SubscriptionReturnHistoryPreparer? _returnHistoryPreparerOverride;

  static bool _openingStripe = false;
  static final Map<String, _CachedStripeDestination> _checkoutCache =
      <String, _CachedStripeDestination>{};
  static final Map<String, Future<_CachedStripeDestination?>>
      _checkoutPrefetches = <String, Future<_CachedStripeDestination?>>{};

  @visibleForTesting
  static void resetForTesting() {
    _openingStripe = false;
    _checkoutCache.clear();
    _checkoutPrefetches.clear();
  }

  DateTime get _now => (_clockOverride ?? DateTime.now).call();

  Future<void> prefetchCheckout(
    SubscriptionPlan plan, {
    String source = 'subscription_prefetch',
  }) async {
    if (plan == SubscriptionPlan.free) return;
    final key = subscriptionPlanKey(plan);
    if (_readCachedCheckout(key) != null ||
        _checkoutPrefetches.containsKey(key)) {
      return;
    }

    final future = _fetchCheckoutDestination(
      key,
      source: source,
      swallowErrors: true,
    );
    _checkoutPrefetches[key] = future;
    try {
      final destination = await future;
      if (destination != null) _checkoutCache[key] = destination;
    } finally {
      _checkoutPrefetches.remove(key);
    }
  }

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
      final checkoutKey = callableName == 'createSubscriptionCheckoutSession'
          ? (payload['plan'] ?? '').toString().trim()
          : '';

      _CachedStripeDestination? destination;
      if (checkoutKey.isNotEmpty) {
        destination = _readCachedCheckout(checkoutKey);
        final pending = _checkoutPrefetches[checkoutKey];
        if (destination == null && pending != null) {
          destination = await pending;
        }
      }

      if (destination == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                duration: Duration(seconds: 8),
                content: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text('Ouverture sécurisée de Stripe…'),
                  ],
                ),
              ),
            );
        }
        final data = await _fetchStripeData(callableName, payload);
        final rawUrl = _extractUrl(data);
        destination = _destinationFromResponse(data, rawUrl);
        if (checkoutKey.isNotEmpty) _checkoutCache[checkoutKey] = destination;
      }

      final uri = Uri.tryParse(destination.url.trim());
      if (uri == null || !_isTrustedStripeUri(uri)) {
        throw const SubscriptionCheckoutException(
          'L’adresse de paiement retournée n’est pas une URL Stripe sécurisée.',
        );
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
      (_returnHistoryPreparerOverride ?? prepareSubscriptionReturnHistory)
          .call();

      final launcher = _externalLauncherOverride;
      final opened = launcher != null
          ? await launcher(uri)
          : await launchUrl(
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
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    await _showSnackBar(
      context,
      _messageForFailure(
        firebaseError: firebaseError,
        genericError: genericError,
        fallback: unavailableMessage,
      ),
    );
  }

  Future<_CachedStripeDestination?> _fetchCheckoutDestination(
    String planKey, {
    required String source,
    required bool swallowErrors,
  }) async {
    try {
      final data = await _fetchStripeData(
        'createSubscriptionCheckoutSession',
        <String, dynamic>{
          'plan': planKey,
          'subscriptionPlan': planKey,
          'source': source,
        },
      );
      final rawUrl = _extractUrl(data);
      final uri = Uri.tryParse(rawUrl.trim());
      if (uri == null || !_isTrustedStripeUri(uri)) {
        throw const SubscriptionCheckoutException(
          'L’adresse de paiement retournée n’est pas une URL Stripe sécurisée.',
        );
      }
      return _destinationFromResponse(data, rawUrl);
    } catch (_) {
      if (swallowErrors) return null;
      rethrow;
    }
  }

  _CachedStripeDestination _destinationFromResponse(
    Map<String, dynamic> data,
    String url,
  ) {
    final rawExpiresAt = data['expiresAt'] ?? data['expires_at'];
    final parsed = rawExpiresAt is num
        ? rawExpiresAt.toInt()
        : int.tryParse((rawExpiresAt ?? '').toString()) ?? 0;
    final expiresAtMs =
        parsed > 0 && parsed < 1000000000000 ? parsed * 1000 : parsed;
    final fallbackMs = _now.millisecondsSinceEpoch +
        const Duration(minutes: 20).inMilliseconds;
    return _CachedStripeDestination(
      url: url,
      expiresAtMs: expiresAtMs > 0 ? expiresAtMs : fallbackMs,
    );
  }

  _CachedStripeDestination? _readCachedCheckout(String key) {
    final cached = _checkoutCache[key];
    if (cached == null) return null;
    final now = _now.millisecondsSinceEpoch;
    if (cached.expiresAtMs <=
        now + const Duration(seconds: 20).inMilliseconds) {
      _checkoutCache.remove(key);
      return null;
    }
    return cached;
  }

  bool _isTrustedStripeUri(Uri uri) {
    if (uri.scheme.toLowerCase() != 'https') return false;
    final host = uri.host.toLowerCase();
    return host == 'stripe.com' || host.endsWith('.stripe.com');
  }

  Future<Map<String, dynamic>> _fetchStripeData(
    String callableName,
    Map<String, dynamic> payload,
  ) async {
    final override = _stripeDataFetcherOverride;
    if (override != null) {
      return override(callableName, payload);
    }
    final callable = prestoFirebaseFunctions.httpsCallable(
      callableName,
      options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
    );
    final response = await callable.call<Map<dynamic, dynamic>>(payload);
    return Map<String, dynamic>.from(response.data);
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

class _CachedStripeDestination {
  final String url;
  final int expiresAtMs;

  const _CachedStripeDestination({
    required this.url,
    required this.expiresAtMs,
  });
}

class SubscriptionCheckoutException implements Exception {
  final String message;

  const SubscriptionCheckoutException(this.message);

  @override
  String toString() => message;
}

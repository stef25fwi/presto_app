/// Erreur de checkout compréhensible par l'interface utilisateur.
class SubscriptionCheckoutException implements Exception {
  const SubscriptionCheckoutException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Destination Stripe mise en cache avec son expiration backend.
class StripeCheckoutDestination {
  const StripeCheckoutDestination({
    required this.url,
    required this.expiresAtMs,
  });

  final String url;
  final int expiresAtMs;

  bool isFresh({
    required int nowMs,
    Duration safetyWindow = const Duration(seconds: 20),
  }) {
    return url.trim().isNotEmpty &&
        expiresAtMs > nowMs + safetyWindow.inMilliseconds;
  }
}

/// Règles pures de validation et normalisation du checkout Stripe.
///
/// Ce composant ne dépend ni de Flutter, ni de Firebase, ni du navigateur. Il
/// peut donc être couvert exhaustivement sans appeler Stripe ou la production.
class SubscriptionCheckoutPolicy {
  const SubscriptionCheckoutPolicy({
    this.defaultTtl = const Duration(minutes: 20),
    this.safetyWindow = const Duration(seconds: 20),
  });

  final Duration defaultTtl;
  final Duration safetyWindow;

  static const Set<String> _trustedHosts = <String>{
    'stripe.com',
    'checkout.stripe.com',
    'billing.stripe.com',
  };

  StripeCheckoutDestination destinationFromResponse(
    Map<String, dynamic> data, {
    required int nowMs,
  }) {
    final uri = parseTrustedStripeUri(extractCheckoutUrl(data));
    return StripeCheckoutDestination(
      url: uri.toString(),
      expiresAtMs: parseExpiresAtMs(data, nowMs: nowMs),
    );
  }

  String extractCheckoutUrl(Map<String, dynamic> data) {
    final directCandidates = <dynamic>[
      data['url'],
      data['checkoutUrl'],
      data['checkout_url'],
      data['sessionUrl'],
      data['session_url'],
    ];
    for (final candidate in directCandidates) {
      final value = candidate?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }

    final session = data['session'];
    if (session is Map) {
      final sessionMap = Map<String, dynamic>.from(
        session.cast<String, dynamic>(),
      );
      for (final key in <String>[
        'url',
        'checkoutUrl',
        'checkout_url',
        'sessionUrl',
        'session_url',
      ]) {
        final value = sessionMap[key]?.toString().trim() ?? '';
        if (value.isNotEmpty) return value;
      }
    }

    throw const SubscriptionCheckoutException(
      'Le serveur n’a pas renvoyé de lien de paiement.',
    );
  }

  int parseExpiresAtMs(
    Map<String, dynamic> data, {
    required int nowMs,
  }) {
    final raw = data['expiresAtMs'] ??
        data['expires_at_ms'] ??
        data['expiresAt'] ??
        data['expires_at'];
    final numeric = raw is num ? raw.toInt() : int.tryParse('$raw');
    if (numeric == null || numeric <= 0) {
      return nowMs + defaultTtl.inMilliseconds;
    }
    if (numeric < 100000000000) {
      return numeric * 1000;
    }
    return numeric;
  }

  Uri parseTrustedStripeUri(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.trim().isEmpty ||
        !_isTrustedHost(uri.host)) {
      throw const SubscriptionCheckoutException(
        'Le lien de paiement reçu est invalide ou non sécurisé.',
      );
    }
    return uri;
  }

  bool isDestinationFresh(
    StripeCheckoutDestination destination, {
    required int nowMs,
  }) {
    return destination.isFresh(
      nowMs: nowMs,
      safetyWindow: safetyWindow,
    );
  }

  String messageForFirebaseFailure({
    required String code,
    String? message,
    required String fallback,
  }) {
    final normalized = code.trim().toLowerCase();
    switch (normalized) {
      case 'unauthenticated':
        return 'Reconnectez-vous pour continuer vers le paiement.';
      case 'permission-denied':
        return 'Vous n’êtes pas autorisé à ouvrir ce paiement.';
      case 'failed-precondition':
        return message?.trim().isNotEmpty == true
            ? message!.trim()
            : 'Ce plan n’est pas disponible pour le moment.';
      case 'invalid-argument':
        return message?.trim().isNotEmpty == true
            ? message!.trim()
            : 'Le plan ou la période de facturation est invalide.';
      case 'resource-exhausted':
        return 'Trop de tentatives. Réessayez dans quelques instants.';
      case 'deadline-exceeded':
      case 'unavailable':
        return 'Le service de paiement met trop de temps à répondre. Réessayez.';
      default:
        return message?.trim().isNotEmpty == true ? message!.trim() : fallback;
    }
  }

  bool _isTrustedHost(String host) {
    final normalized = host.trim().toLowerCase();
    if (_trustedHosts.contains(normalized)) return true;
    return normalized.endsWith('.stripe.com');
  }
}

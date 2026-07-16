const String subscriptionReturnPath =
    '/account?section=subscriptions&from=stripe';

/// Retourne la route à ajouter à l'historique avant l'ouverture de Stripe.
///
/// Une valeur nulle signifie que l'entrée de retour exacte est déjà active.
String? subscriptionReturnPathToPush(Uri current) {
  final alreadyPrepared = current.path == '/account' &&
      current.queryParameters['section'] == 'subscriptions' &&
      current.queryParameters['from'] == 'stripe';
  return alreadyPrepared ? null : subscriptionReturnPath;
}

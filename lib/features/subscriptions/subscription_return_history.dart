import 'subscription_return_history_stub.dart'
    if (dart.library.js_interop) 'subscription_return_history_web.dart' as impl;

/// Prépare l'entrée d'historique utilisée avant d'ouvrir Stripe.
///
/// Sur mobile, cette fonction ne fait rien. Sur le Web, elle remplace l'URL
/// courante par la route Compte/Abonnements sans reconstruire l'application.
void prepareSubscriptionReturnHistory() {
  impl.prepareSubscriptionReturnHistory();
}

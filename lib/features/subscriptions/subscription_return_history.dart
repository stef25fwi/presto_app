import 'subscription_return_history_stub.dart'
    if (dart.library.js_interop) 'subscription_return_history_web.dart' as impl;

/// Prépare l'entrée d'historique utilisée avant d'ouvrir Stripe.
///
/// Sur mobile, cette fonction ne fait rien. Sur le Web, elle ajoute une entrée
/// Compte/Abonnements afin que le retour depuis Stripe ne relance pas l'écran
/// initial de l'application.
void prepareSubscriptionReturnHistory() {
  impl.prepareSubscriptionReturnHistory();
}

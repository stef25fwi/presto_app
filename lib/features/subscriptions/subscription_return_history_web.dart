// ignore_for_file: avoid_web_libraries_in_flutter

import 'package:web/web.dart' as web;

import 'subscription_return_history_policy.dart';

void prepareSubscriptionReturnHistory() {
  final returnPath = subscriptionReturnPathToPush(Uri.base);
  if (returnPath == null) return;

  // Ajoute une vraie entrée d'historique avant la navigation plein écran vers
  // Stripe. L'icône retour du navigateur / WebView retrouve ainsi la page
  // Abonnements au lieu de revenir à l'entrée initiale de l'application.
  web.window.history.pushState(null, '', returnPath);
}

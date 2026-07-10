// ignore_for_file: avoid_web_libraries_in_flutter

import 'package:web/web.dart' as web;

const String _subscriptionReturnPath =
    '/account?section=subscriptions&from=stripe';

void prepareSubscriptionReturnHistory() {
  final current = Uri.base;
  final alreadyPrepared = current.path == '/account' &&
      current.queryParameters['section'] == 'subscriptions';
  if (alreadyPrepared) return;

  web.window.history.replaceState(null, '', _subscriptionReturnPath);
}

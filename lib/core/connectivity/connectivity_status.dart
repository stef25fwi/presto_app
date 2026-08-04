import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

typedef ConnectivityCheck = Future<List<ConnectivityResult>> Function();
typedef ConnectivityChanges = Stream<List<ConnectivityResult>> Function();

/// Source de vérité unique pour l'état réseau de l'app, utilisée pour
/// piloter la bannière hors-ligne globale et les gardes d'action réseau.
class ConnectivityStatus extends ChangeNotifier {
  ConnectivityStatus._({
    ConnectivityCheck? checkConnectivity,
    ConnectivityChanges? connectivityChanges,
  })  : _checkConnectivity =
            checkConnectivity ?? Connectivity().checkConnectivity,
        _connectivityChanges = connectivityChanges ??
            (() => Connectivity().onConnectivityChanged);

  @visibleForTesting
  factory ConnectivityStatus.forTesting({
    required ConnectivityCheck checkConnectivity,
    required ConnectivityChanges connectivityChanges,
  }) {
    return ConnectivityStatus._(
      checkConnectivity: checkConnectivity,
      connectivityChanges: connectivityChanges,
    );
  }

  static final ConnectivityStatus instance = ConnectivityStatus._();

  final ConnectivityCheck _checkConnectivity;
  final ConnectivityChanges _connectivityChanges;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOnline = true;
  bool _started = false;

  bool get isOnline => _isOnline;

  /// Démarre l'écoute réseau. Idempotent : peut être appelé plusieurs fois
  /// (par ex. depuis plusieurs écrans) sans dupliquer les abonnements.
  void start() {
    if (_started) return;
    _started = true;
    _subscription = _connectivityChanges().listen(_handle);
    unawaited(_checkInitialState());
  }

  Future<void> _checkInitialState() async {
    try {
      _handle(await _checkConnectivity());
    } catch (_) {
      // On garde l'état "en ligne" par défaut si la vérification échoue,
      // pour ne pas afficher une fausse alerte au démarrage.
    }
  }

  void _handle(List<ConnectivityResult> results) {
    final isOnline = results.any((r) => r != ConnectivityResult.none);
    if (isOnline == _isOnline) return;
    _isOnline = isOnline;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}

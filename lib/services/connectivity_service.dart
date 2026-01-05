import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service de gestion de la connectivité
/// Détecte si l'application est en ligne ou hors ligne
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final _isOnlineController = StreamController<bool>.broadcast();
  Stream<bool> get onlineStatusStream => _isOnlineController.stream;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  Timer? _checkTimer;
  
  /// Démarre la surveillance de la connectivité
  void startMonitoring() {
    // Vérification initiale
    checkConnectivity();
    
    // Vérification périodique toutes les 10 secondes
    _checkTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      checkConnectivity();
    });
  }

  /// Arrête la surveillance
  void stopMonitoring() {
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  /// Vérifie la connectivité
  Future<void> checkConnectivity() async {
    final wasOnline = _isOnline;
    _isOnline = await _hasInternetConnection();
    
    // Notifier seulement si le statut change
    if (wasOnline != _isOnline) {
      _isOnlineController.add(_isOnline);
      debugPrint('[Connectivity] Status changed: ${_isOnline ? "ONLINE" : "OFFLINE"}');
    }
  }

  /// Teste la connexion Internet
  Future<bool> _hasInternetConnection() async {
    try {
      if (kIsWeb) {
        // Sur Web, utiliser une requête HTTP simple
        final response = await http
            .get(Uri.parse('https://www.google.com'))
            .timeout(const Duration(seconds: 5));
        return response.statusCode == 200;
      } else {
        // Sur mobile, tester la résolution DNS
        final result = await InternetAddress.lookup('google.com')
            .timeout(const Duration(seconds: 5));
        return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      }
    } catch (e) {
      debugPrint('[Connectivity] Check failed: $e');
      return false;
    }
  }

  /// Force une vérification immédiate
  Future<bool> forceCheck() async {
    await checkConnectivity();
    return _isOnline;
  }

  void dispose() {
    stopMonitoring();
    _isOnlineController.close();
  }
}

/// État global de connectivité accessible partout
class ConnectivityState {
  static final ConnectivityService _service = ConnectivityService();
  
  static bool get isOnline => _service.isOnline;
  static Stream<bool> get onlineStream => _service.onlineStatusStream;
  
  static void startMonitoring() => _service.startMonitoring();
  static void stopMonitoring() => _service.stopMonitoring();
  static Future<void> checkNow() => _service.checkConnectivity();
  static Future<bool> forceCheck() => _service.forceCheck();
}

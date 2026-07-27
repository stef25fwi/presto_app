import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Metrics pour monitorer le système de cache des journeys boîte à outils
class CacheMetrics {
  int totalRequests = 0; // Total de requêtes
  int cacheHits = 0; // Nombre de hits (trouvé en cache)
  int cacheMisses = 0; // Nombre de misses (pas en cache, généré)
  int cacheErrors = 0; // Nombre d'erreurs d'accès cache

  Duration totalAccessTime = Duration.zero;
  Duration avgAccessTime = Duration.zero;

  /// Hit rate en pourcentage
  double get hitRate =>
      totalRequests == 0 ? 0 : (cacheHits / totalRequests) * 100;

  /// Miss rate en pourcentage
  double get missRate =>
      totalRequests == 0 ? 0 : (cacheMisses / totalRequests) * 100;

  /// Résumé en JSON pour logging
  Map<String, dynamic> toJson() => {
        'total_requests': totalRequests,
        'cache_hits': cacheHits,
        'cache_misses': cacheMisses,
        'cache_errors': cacheErrors,
        'hit_rate_percent': hitRate.toStringAsFixed(2),
        'miss_rate_percent': missRate.toStringAsFixed(2),
        'avg_access_time_ms': avgAccessTime.inMilliseconds,
      };

  @override
  String toString() => '''
╔════════════════════════════════════╗
║ CACHE METRICS - Boîte à Outils     ║
╠════════════════════════════════════╣
║ Total Requests:    ${totalRequests.toString().padRight(15)} ║
║ Cache Hits:        ${cacheHits.toString().padRight(15)} ║
║ Cache Misses:      ${cacheMisses.toString().padRight(15)} ║
║ Cache Errors:      ${cacheErrors.toString().padRight(15)} ║
║ ──────────────────────────────────── ║
║ Hit Rate:          ${hitRate.toStringAsFixed(1).padRight(12)}%  ║
║ Miss Rate:         ${missRate.toStringAsFixed(1).padRight(12)}%  ║
║ Avg Access Time:   ${avgAccessTime.inMilliseconds.toString().padRight(10)} ms ║
╚════════════════════════════════════╝
''';
}

/// Service de monitoring pour le cache
class CacheMonitoringService {
  static final CacheMonitoringService _instance =
      CacheMonitoringService._internal();

  CacheMonitoringService._internal({FirebaseFirestore? firestore})
      : _firestoreOverride = firestore;

  @visibleForTesting
  factory CacheMonitoringService.forTest({
    required FirebaseFirestore firestore,
  }) {
    return CacheMonitoringService._internal(firestore: firestore);
  }

  final CacheMetrics metrics = CacheMetrics();
  final FirebaseFirestore? _firestoreOverride;

  FirebaseFirestore get _db =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  // Stockage des infos pour calcul avgAccessTime
  final List<Duration> _accessTimes = [];
  static const int _maxStoredTimes = 100;

  factory CacheMonitoringService() {
    return _instance;
  }

  /// Enregistrer une tentative d'accès au cache
  void recordCacheHit(Duration accessTime) {
    metrics.totalRequests++;
    metrics.cacheHits++;
    _recordAccessTime(accessTime);

    debugPrint('✅ Cache HIT (${accessTime.inMilliseconds}ms)');
  }

  /// Enregistrer un miss (pas en cache)
  void recordCacheMiss(Duration accessTime) {
    metrics.totalRequests++;
    metrics.cacheMisses++;
    _recordAccessTime(accessTime);

    debugPrint(
        '⚠️ Cache MISS (${accessTime.inMilliseconds}ms) - Génération lancée');
  }

  /// Enregistrer une erreur d'accès
  void recordCacheError(String reason) {
    metrics.totalRequests++;
    metrics.cacheErrors++;

    debugPrint('❌ Cache ERROR: $reason');
  }

  /// Enregistrer le temps d'accès pour calcul moyenne
  void _recordAccessTime(Duration time) {
    _accessTimes.add(time);
    if (_accessTimes.length > _maxStoredTimes) {
      _accessTimes.removeAt(0);
    }

    // Calcul de la moyenne
    if (_accessTimes.isNotEmpty) {
      final sum = _accessTimes.fold<int>(
        0,
        (prev, current) => prev + current.inMilliseconds,
      );
      metrics.avgAccessTime =
          Duration(milliseconds: sum ~/ _accessTimes.length);
    }
  }

  /// Afficher les metrics actuelles
  void printMetrics() {
    debugPrint(metrics.toString());
  }

  /// Sauvegarder les metrics en Firestore pour analyse
  Future<void> saveMetricsToFirestore() async {
    try {
      await _db.collection('cache_analytics').add({
        'timestamp': FieldValue.serverTimestamp(),
        'metrics': metrics.toJson(),
        'session_duration': DateTime.now().toIso8601String(),
      });
      debugPrint('📊 Metrics sauvegardées en Firestore');
    } catch (e) {
      debugPrint('❌ Erreur sauvegarde metrics: $e');
    }
  }

  /// Récupérer les stats des dernières 24h depuis Firestore
  Future<Map<String, dynamic>?> getLast24hStats() async {
    try {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      final snapshot = await _db
          .collection('cache_analytics')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(yesterday))
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      // Calculer les stats agrégées
      int totalHits = 0, totalMisses = 0, totalErrors = 0, totalRequests = 0;

      for (final doc in snapshot.docs) {
        final metrics = doc.data()['metrics'] as Map<String, dynamic>? ?? {};
        totalHits += (metrics['cache_hits'] as int?) ?? 0;
        totalMisses += (metrics['cache_misses'] as int?) ?? 0;
        totalErrors += (metrics['cache_errors'] as int?) ?? 0;
        totalRequests += (metrics['total_requests'] as int?) ?? 0;
      }

      return {
        'period': 'Last 24 hours',
        'total_requests': totalRequests,
        'total_hits': totalHits,
        'total_misses': totalMisses,
        'total_errors': totalErrors,
        'hit_rate': totalRequests == 0 ? 0 : (totalHits / totalRequests * 100),
        'samples': snapshot.docs.length,
      };
    } catch (e) {
      debugPrint('❌ Erreur récupération stats: $e');
      return null;
    }
  }

  /// Reset des metrics (pour tests)
  void reset() {
    metrics.totalRequests = 0;
    metrics.cacheHits = 0;
    metrics.cacheMisses = 0;
    metrics.cacheErrors = 0;
    _accessTimes.clear();
    debugPrint('🔄 Metrics réinitialisées');
  }
}

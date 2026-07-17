import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/cache_monitoring_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  late CacheMonitoringService service;
  late DebugPrintCallback originalDebugPrint;
  late List<String> logs;

  setUp(() {
    logs = <String>[];
    originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) logs.add(message);
    };
    service = CacheMonitoringService();
    service.reset();
    logs.clear();
  });

  tearDown(() {
    service.reset();
    debugPrint = originalDebugPrint;
  });

  test('CacheMetrics calcule les taux et expose un résumé stable', () {
    final metrics = CacheMetrics();

    expect(metrics.hitRate, 0);
    expect(metrics.missRate, 0);
    expect(metrics.toJson(), <String, dynamic>{
      'total_requests': 0,
      'cache_hits': 0,
      'cache_misses': 0,
      'cache_errors': 0,
      'hit_rate_percent': '0.00',
      'miss_rate_percent': '0.00',
      'avg_access_time_ms': 0,
    });

    metrics
      ..totalRequests = 8
      ..cacheHits = 5
      ..cacheMisses = 2
      ..cacheErrors = 1
      ..avgAccessTime = const Duration(milliseconds: 37);

    expect(metrics.hitRate, 62.5);
    expect(metrics.missRate, 25);
    expect(metrics.toJson(), <String, dynamic>{
      'total_requests': 8,
      'cache_hits': 5,
      'cache_misses': 2,
      'cache_errors': 1,
      'hit_rate_percent': '62.50',
      'miss_rate_percent': '25.00',
      'avg_access_time_ms': 37,
    });

    final summary = metrics.toString();
    expect(summary, contains('CACHE METRICS'));
    expect(summary, contains('Total Requests:    8'));
    expect(summary, contains('Hit Rate:          62.5'));
    expect(summary, contains('Avg Access Time:   37'));
  });

  test('enregistre hits, misses, erreurs et moyenne d accès', () {
    expect(identical(CacheMonitoringService(), service), isTrue);

    service.recordCacheHit(const Duration(milliseconds: 10));
    service.recordCacheMiss(const Duration(milliseconds: 30));
    service.recordCacheError('document absent');
    service.printMetrics();

    expect(service.metrics.totalRequests, 3);
    expect(service.metrics.cacheHits, 1);
    expect(service.metrics.cacheMisses, 1);
    expect(service.metrics.cacheErrors, 1);
    expect(service.metrics.avgAccessTime, const Duration(milliseconds: 20));
    expect(service.metrics.hitRate, closeTo(100 / 3, 0.0001));
    expect(service.metrics.missRate, closeTo(100 / 3, 0.0001));

    expect(logs, contains('✅ Cache HIT (10ms)'));
    expect(
      logs,
      contains('⚠️ Cache MISS (30ms) - Génération lancée'),
    );
    expect(logs, contains('❌ Cache ERROR: document absent'));
    expect(logs.any((entry) => entry.contains('CACHE METRICS')), isTrue);
  });

  test('conserve une fenêtre glissante de cent temps d accès', () {
    for (var milliseconds = 1; milliseconds <= 101; milliseconds++) {
      service.recordCacheHit(Duration(milliseconds: milliseconds));
    }

    expect(service.metrics.totalRequests, 101);
    expect(service.metrics.cacheHits, 101);
    expect(service.metrics.cacheMisses, 0);
    expect(service.metrics.avgAccessTime, const Duration(milliseconds: 51));
  });

  test('reset remet les compteurs et les taux à zéro', () {
    service.recordCacheHit(const Duration(milliseconds: 12));
    service.recordCacheMiss(const Duration(milliseconds: 18));
    service.recordCacheError('timeout');

    service.reset();

    expect(service.metrics.totalRequests, 0);
    expect(service.metrics.cacheHits, 0);
    expect(service.metrics.cacheMisses, 0);
    expect(service.metrics.cacheErrors, 0);
    expect(service.metrics.hitRate, 0);
    expect(service.metrics.missRate, 0);
    expect(logs.last, '🔄 Metrics réinitialisées');
  });

  test('les opérations Firestore restent best effort sans plugin natif',
      () async {
    await expectLater(service.saveMetricsToFirestore(), completes);
    final stats = await service.getLast24hStats();

    expect(stats, isNull);
    expect(
      logs.any((entry) => entry.startsWith('❌ Erreur sauvegarde metrics:')),
      isTrue,
    );
    expect(
      logs.any((entry) => entry.startsWith('❌ Erreur récupération stats:')),
      isTrue,
    );
  });
}

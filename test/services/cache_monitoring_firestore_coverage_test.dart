import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/cache_monitoring_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('saves the current cache metrics in Firestore', () async {
    final firestore = FakeFirebaseFirestore();
    final service = CacheMonitoringService.forTest(firestore: firestore);

    service.recordCacheHit(const Duration(milliseconds: 100));
    service.recordCacheMiss(const Duration(milliseconds: 300));
    service.recordCacheError('cache unavailable');

    await service.saveMetricsToFirestore();

    final snapshot = await firestore.collection('cache_analytics').get();
    expect(snapshot.docs, hasLength(1));
    final data = snapshot.docs.single.data();
    expect(data['timestamp'], isA<Timestamp>());
    expect(data['session_duration'], isA<String>());
    expect(data['metrics'], <String, dynamic>{
      'total_requests': 3,
      'cache_hits': 1,
      'cache_misses': 1,
      'cache_errors': 1,
      'hit_rate_percent': '33.33',
      'miss_rate_percent': '33.33',
      'avg_access_time_ms': 200,
    });
  });

  test('returns null when no recent cache sample exists', () async {
    final service = CacheMonitoringService.forTest(
      firestore: FakeFirebaseFirestore(),
    );

    expect(await service.getLast24hStats(), isNull);
  });

  test('aggregates only cache samples from the last 24 hours', () async {
    final firestore = FakeFirebaseFirestore();
    final service = CacheMonitoringService.forTest(firestore: firestore);
    final recent = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(hours: 1)),
    );
    final old = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(days: 2)),
    );

    await firestore.collection('cache_analytics').add(<String, dynamic>{
      'timestamp': recent,
      'metrics': <String, dynamic>{
        'cache_hits': 2,
        'cache_misses': 1,
        'cache_errors': 1,
        'total_requests': 4,
      },
    });
    await firestore.collection('cache_analytics').add(<String, dynamic>{
      'timestamp': recent,
      'metrics': <String, dynamic>{
        'cache_hits': 3,
        'cache_misses': 2,
        'cache_errors': 0,
        'total_requests': 5,
      },
    });
    await firestore.collection('cache_analytics').add(<String, dynamic>{
      'timestamp': old,
      'metrics': <String, dynamic>{
        'cache_hits': 100,
        'cache_misses': 100,
        'cache_errors': 100,
        'total_requests': 300,
      },
    });

    final stats = await service.getLast24hStats();

    expect(stats, isNotNull);
    expect(stats?['period'], 'Last 24 hours');
    expect(stats?['total_requests'], 9);
    expect(stats?['total_hits'], 5);
    expect(stats?['total_misses'], 3);
    expect(stats?['total_errors'], 1);
    expect(stats?['hit_rate'], closeTo(55.5555, 0.001));
    expect(stats?['samples'], 2);
  });

  test('reports a zero hit rate when samples contain no request', () async {
    final firestore = FakeFirebaseFirestore();
    final service = CacheMonitoringService.forTest(firestore: firestore);

    await firestore.collection('cache_analytics').add(<String, dynamic>{
      'timestamp': Timestamp.now(),
      'metrics': <String, dynamic>{},
    });

    final stats = await service.getLast24hStats();

    expect(stats?['total_requests'], 0);
    expect(stats?['hit_rate'], 0);
    expect(stats?['samples'], 1);
  });
}

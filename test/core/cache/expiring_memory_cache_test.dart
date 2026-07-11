import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/core/cache/expiring_memory_cache.dart';

void main() {
  late DateTime now;

  setUp(() {
    now = DateTime.utc(2026, 7, 11, 12);
  });

  test('retourne une valeur fraîche puis l expire au TTL', () {
    final cache = ExpiringMemoryCache<String, int>(
      defaultTtl: const Duration(minutes: 5),
      clock: () => now,
    );

    cache.put('categories', 42);
    expect(cache.get('categories'), 42);

    now = now.add(const Duration(minutes: 5));
    expect(cache.get('categories'), isNull);
    expect(cache.length, 0);
  });

  test('getOrLoad évite un second chargement tant que la valeur est fraîche',
      () async {
    var loadCount = 0;
    final cache = ExpiringMemoryCache<String, String>(
      defaultTtl: const Duration(hours: 1),
      clock: () => now,
    );

    Future<String> loader() async {
      loadCount += 1;
      return 'ilipresto';
    }

    expect(await cache.getOrLoad('brand', loader), 'ilipresto');
    expect(await cache.getOrLoad('brand', loader), 'ilipresto');
    expect(loadCount, 1);
  });

  test('évince la valeur la moins récemment utilisée au dépassement', () {
    final cache = ExpiringMemoryCache<String, int>(
      defaultTtl: const Duration(hours: 1),
      maximumEntries: 2,
      clock: () => now,
    );

    cache.put('a', 1);
    cache.put('b', 2);
    expect(cache.get('a'), 1); // a devient la plus récente.
    cache.put('c', 3);

    expect(cache.get('a'), 1);
    expect(cache.get('b'), isNull);
    expect(cache.get('c'), 3);
  });

  test('invalidation et purge sont explicites', () {
    final cache = ExpiringMemoryCache<String, int>(
      defaultTtl: const Duration(minutes: 1),
      clock: () => now,
    );

    cache
      ..put('profile', 1)
      ..put('plans', 2);
    cache.invalidate('profile');
    expect(cache.get('profile'), isNull);

    now = now.add(const Duration(minutes: 2));
    expect(cache.purgeExpired(), 1);
    expect(cache.length, 0);
  });

  test('refuse un TTL négatif', () {
    final cache = ExpiringMemoryCache<String, int>(
      defaultTtl: Duration.zero,
      clock: () => now,
    );

    expect(
      () => cache.put('invalid', 1, ttl: const Duration(seconds: -1)),
      throwsArgumentError,
    );
  });
}

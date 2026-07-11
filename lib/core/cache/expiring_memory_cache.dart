/// Cache mémoire borné avec expiration explicite.
///
/// Ce cache ne constitue jamais la source de vérité métier. Il sert à éviter
/// des lectures répétées pour des données courtes et réutilisables telles que
/// les catégories, la configuration distante, le profil courant ou les plans
/// d'abonnement.
class ExpiringMemoryCache<K, V> {
  ExpiringMemoryCache({
    required this.defaultTtl,
    this.maximumEntries = 100,
    DateTime Function()? clock,
  }) : assert(!defaultTtl.isNegative),
       assert(maximumEntries > 0),
       _clock = clock ?? DateTime.now;

  final Duration defaultTtl;
  final int maximumEntries;
  final DateTime Function() _clock;
  final Map<K, _CacheEntry<V>> _entries = <K, _CacheEntry<V>>{};
  final Map<K, Future<V>> _inFlight = <K, Future<V>>{};
  final Map<K, int> _versions = <K, int>{};
  int _generation = 0;

  int get length {
    purgeExpired();
    return _entries.length;
  }

  bool containsFresh(K key) => get(key) != null;

  V? get(K key) {
    final entry = _entries[key];
    if (entry == null) return null;
    if (!entry.expiresAt.isAfter(_clock())) {
      _entries.remove(key);
      return null;
    }

    // Réinsérer permet une éviction simple de type LRU grâce à l'ordre du Map.
    _entries
      ..remove(key)
      ..[key] = entry;
    return entry.value;
  }

  void put(K key, V value, {Duration? ttl}) {
    _bumpVersion(key);
    _inFlight.remove(key);
    _putValue(key, value, ttl: ttl);
  }

  Future<V> getOrLoad(K key, Future<V> Function() loader, {Duration? ttl}) {
    final cached = get(key);
    if (cached != null) return Future<V>.value(cached);

    final existingLoad = _inFlight[key];
    if (existingLoad != null) return existingLoad;

    final version = _versions[key] ?? 0;
    final generation = _generation;
    late final Future<V> loadFuture;
    loadFuture = Future<V>.sync(loader)
        .then((loaded) {
          if (_generation == generation && (_versions[key] ?? 0) == version) {
            _putValue(key, loaded, ttl: ttl);
          }
          return loaded;
        })
        .whenComplete(() {
          if (identical(_inFlight[key], loadFuture)) {
            _inFlight.remove(key);
          }
        });
    _inFlight[key] = loadFuture;
    return loadFuture;
  }

  void invalidate(K key) {
    _entries.remove(key);
    _inFlight.remove(key);
    _bumpVersion(key);
  }

  void clear() {
    _entries.clear();
    _inFlight.clear();
    _versions.clear();
    _generation += 1;
  }

  int purgeExpired() {
    final now = _clock();
    final expiredKeys = _entries.entries
        .where((entry) => !entry.value.expiresAt.isAfter(now))
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final key in expiredKeys) {
      _entries.remove(key);
    }
    return expiredKeys.length;
  }

  void _putValue(K key, V value, {Duration? ttl}) {
    final effectiveTtl = ttl ?? defaultTtl;
    if (effectiveTtl.isNegative) {
      throw ArgumentError.value(
        ttl,
        'ttl',
        'La durée ne peut pas être négative',
      );
    }

    purgeExpired();
    _entries.remove(key);
    _entries[key] = _CacheEntry<V>(
      value: value,
      expiresAt: _clock().add(effectiveTtl),
    );
    _evictOverflow();
  }

  void _bumpVersion(K key) {
    _versions[key] = (_versions[key] ?? 0) + 1;
  }

  void _evictOverflow() {
    while (_entries.length > maximumEntries) {
      _entries.remove(_entries.keys.first);
    }
  }
}

class _CacheEntry<V> {
  const _CacheEntry({required this.value, required this.expiresAt});

  final V value;
  final DateTime expiresAt;
}

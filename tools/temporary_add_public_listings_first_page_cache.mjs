import { readFile, writeFile } from 'node:fs/promises';

const path = 'lib/data/marketplace/listing_repository.dart';
let source = await readFile(path, 'utf8');

const replaceOnce = (before, after, label) => {
  if (!source.includes(before)) {
    throw new Error(`Bloc introuvable: ${label}`);
  }
  source = source.replace(before, after);
};

replaceOnce(
  "import 'package:cloud_functions/cloud_functions.dart';\n\n",
  "import 'package:cloud_functions/cloud_functions.dart';\n\nimport '../../core/cache/expiring_memory_cache.dart';\n",
  'cache import',
);

replaceOnce(
  `int normalizePublicListingsPageSize(int value) {\n  if (value < 1) return 1;\n  if (value > 100) return 100;\n  return value;\n}\n`,
  `int normalizePublicListingsPageSize(int value) {\n  if (value < 1) return 1;\n  if (value > 100) return 100;\n  return value;\n}\n\nString publicListingsFirstPageCacheKey({\n  String? categoryId,\n  String? cityId,\n  required int limit,\n}) {\n  return <String>[\n    categoryId?.trim().toLowerCase() ?? '',\n    cityId?.trim().toLowerCase() ?? '',\n    normalizePublicListingsPageSize(limit).toString(),\n  ].join('|');\n}\n`,
  'cache key',
);

replaceOnce(
  `  ListingRepository({\n    FirebaseFirestore? firestore,\n    FirebaseFunctions? functions,\n    ProductAnalyticsService? analytics,\n  })  : _firestore = firestore ?? FirebaseFirestore.instance,\n        _functions = functions ?? prestoFirebaseFunctions,\n        _analytics = analytics ?? ProductAnalyticsService();`,
  `  ListingRepository({\n    FirebaseFirestore? firestore,\n    FirebaseFunctions? functions,\n    ProductAnalyticsService? analytics,\n    ExpiringMemoryCache<String, PublicListingsPage>? publicListingsCache,\n  })  : _firestore = firestore ?? FirebaseFirestore.instance,\n        _functions = functions ?? prestoFirebaseFunctions,\n        _analytics = analytics ?? ProductAnalyticsService(),\n        _publicListingsCache = publicListingsCache ??\n            ExpiringMemoryCache<String, PublicListingsPage>(\n              defaultTtl: const Duration(seconds: 30),\n              maximumEntries: 30,\n            );`,
  'constructor cache injection',
);

replaceOnce(
  `  final FirebaseFirestore _firestore;\n  final FirebaseFunctions _functions;\n  final ProductAnalyticsService _analytics;`,
  `  final FirebaseFirestore _firestore;\n  final FirebaseFunctions _functions;\n  final ProductAnalyticsService _analytics;\n  final ExpiringMemoryCache<String, PublicListingsPage> _publicListingsCache;`,
  'cache field',
);

replaceOnce(
  `    final result = ListingSubmissionResult.fromMap(data);\n    await _analytics`,
  `    final result = ListingSubmissionResult.fromMap(data);\n    _publicListingsCache.clear();\n    await _analytics`,
  'cache invalidation after submit',
);

replaceOnce(
  `  Future<PublicListingsPage> fetchPublicListingsPage({\n    String? categoryId,\n    String? cityId,\n    int limit = 50,\n    QueryDocumentSnapshot<Map<String, dynamic>>? startAfter,\n  }) async {\n    final pageSize = normalizePublicListingsPageSize(limit);\n    Query<Map<String, dynamic>> query = _publicListingsQuery(\n      categoryId: categoryId,\n      cityId: cityId,\n    );\n    if (startAfter != null) {\n      query = query.startAfterDocument(startAfter);\n    }\n\n    final snapshot = await query.limit(pageSize + 1).get();\n    final hasMore = snapshot.docs.length > pageSize;\n    final visibleDocs = hasMore\n        ? snapshot.docs.take(pageSize).toList(growable: false)\n        : snapshot.docs;\n\n    return PublicListingsPage(\n      items: visibleDocs\n          .map(MarketplaceListing.fromFirestore)\n          .toList(growable: false),\n      lastDocument: visibleDocs.isEmpty ? null : visibleDocs.last,\n      hasMore: hasMore,\n    );\n  }`,
  `  Future<PublicListingsPage> fetchPublicListingsPage({\n    String? categoryId,\n    String? cityId,\n    int limit = 50,\n    QueryDocumentSnapshot<Map<String, dynamic>>? startAfter,\n  }) {\n    final pageSize = normalizePublicListingsPageSize(limit);\n    if (startAfter != null) {\n      return _loadPublicListingsPage(\n        categoryId: categoryId,\n        cityId: cityId,\n        pageSize: pageSize,\n        startAfter: startAfter,\n      );\n    }\n\n    final cacheKey = publicListingsFirstPageCacheKey(\n      categoryId: categoryId,\n      cityId: cityId,\n      limit: pageSize,\n    );\n    return _publicListingsCache.getOrLoad(\n      cacheKey,\n      () => _loadPublicListingsPage(\n        categoryId: categoryId,\n        cityId: cityId,\n        pageSize: pageSize,\n      ),\n    );\n  }\n\n  Future<void> preloadPublicListings({\n    String? categoryId,\n    String? cityId,\n    int limit = 20,\n  }) async {\n    await fetchPublicListingsPage(\n      categoryId: categoryId,\n      cityId: cityId,\n      limit: limit,\n    );\n  }\n\n  void invalidatePublicListingsCache() => _publicListingsCache.clear();\n\n  Future<PublicListingsPage> _loadPublicListingsPage({\n    String? categoryId,\n    String? cityId,\n    required int pageSize,\n    QueryDocumentSnapshot<Map<String, dynamic>>? startAfter,\n  }) async {\n    Query<Map<String, dynamic>> query = _publicListingsQuery(\n      categoryId: categoryId,\n      cityId: cityId,\n    );\n    if (startAfter != null) {\n      query = query.startAfterDocument(startAfter);\n    }\n\n    final snapshot = await query.limit(pageSize + 1).get();\n    final hasMore = snapshot.docs.length > pageSize;\n    final visibleDocs = hasMore\n        ? snapshot.docs.take(pageSize).toList(growable: false)\n        : snapshot.docs;\n\n    return PublicListingsPage(\n      items: visibleDocs\n          .map(MarketplaceListing.fromFirestore)\n          .toList(growable: false),\n      lastDocument: visibleDocs.isEmpty ? null : visibleDocs.last,\n      hasMore: hasMore,\n    );\n  }`,
  'cached page loader',
);

await writeFile(path, source, 'utf8');
console.log('public listings first-page cache applied');

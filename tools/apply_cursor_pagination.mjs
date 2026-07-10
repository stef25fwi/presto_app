#!/usr/bin/env node

import fs from 'node:fs/promises';

function replaceOnce(content, before, after, label) {
  if (content.includes(after)) return content;
  const count = content.split(before).length - 1;
  if (count !== 1) {
    throw new Error(`${label}: expected exactly one occurrence, found ${count}`);
  }
  return content.replace(before, after);
}

async function patchQueryHelper() {
  const path = 'lib/services/public_offers_query_helpers.dart';
  let content = await fs.readFile(path, 'utf8');

  content = replaceOnce(
    content,
    "  String? categoryId,\n  String? cityId,\n}) {",
    "  String? categoryId,\n  String? cityId,\n  DocumentSnapshot<Map<String, dynamic>>? startAfterDocument,\n}) {",
    'query cursor parameter',
  );

  content = replaceOnce(
    content,
    "  final canonicalQuery = latestFirst\n      ? filteredQuery.orderBy('createdAt', descending: true)\n      : filteredQuery;\n  return <Query<Map<String, dynamic>>>[canonicalQuery.limit(limit)];",
    "  Query<Map<String, dynamic>> canonicalQuery = latestFirst\n      ? filteredQuery.orderBy('createdAt', descending: true)\n      : filteredQuery;\n  if (startAfterDocument != null) {\n    canonicalQuery = canonicalQuery.startAfterDocument(startAfterDocument);\n  }\n  return <Query<Map<String, dynamic>>>[canonicalQuery.limit(limit)];",
    'query cursor application',
  );

  await fs.writeFile(path, content, 'utf8');
}

async function patchConsultPage() {
  const path = 'lib/pages/consult_offers_page.dart';
  let content = await fs.readFile(path, 'utf8');

  content = replaceOnce(
    content,
    "  // Pagination / loading state\n  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;\n\n  // + Pagination progressive (moins brutale: 10 par page au lieu de 20)\n  static const int _initialLimit = 10;\n  static const int _pageSize = 10;\n  static const int _maxLimit = 100;\n  int _pageLimit = _initialLimit;",
    "  // Pagination par curseur : chaque page ne relit plus les documents déjà\n  // affichés. La limite maximale borne aussi le coût d'une session.\n  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;\n  List<QueryDocumentSnapshot<Map<String, dynamic>>> _paginationDocs =\n      <QueryDocumentSnapshot<Map<String, dynamic>>>[];\n  String? _paginationKey;\n  bool _isLoadingNextPage = false;\n  bool _hasMorePages = true;\n\n  static const int _initialLimit = 20;\n  static const int _pageSize = 20;\n  static const int _maxLimit = 100;\n  int _pageLimit = _initialLimit;",
    'pagination state',
  );

  content = replaceOnce(
    content,
    "  List<Query<Map<String, dynamic>>> _buildCurrentListingsQueries({\n    required int limit,\n  }) {\n    return buildMarketplaceListingsBrowseQueries(\n      limit: limit,\n      latestFirst: true,\n      categoryId: _effectiveListingsCategoryId(),\n      cityId: _effectiveListingsCityId(),\n    );\n  }",
    "  List<Query<Map<String, dynamic>>> _buildCurrentListingsQueries({\n    required int limit,\n    DocumentSnapshot<Map<String, dynamic>>? startAfterDocument,\n  }) {\n    return buildMarketplaceListingsBrowseQueries(\n      limit: limit,\n      latestFirst: true,\n      categoryId: _effectiveListingsCategoryId(),\n      cityId: _effectiveListingsCityId(),\n      startAfterDocument: startAfterDocument,\n    );\n  }",
    'current listing cursor query',
  );

  content = replaceOnce(
    content,
    "  void _maybeLoadMore() {\n    if (!_scrollController.hasClients) return;\n    if (_hasActiveClientFilters) return;\n    if (_pageLimit >= _maxLimit) return;\n    if (_lastSnapshotRawCount < _pageLimit) return;\n\n    final position = _scrollController.position;\n    // Seuil : quand on approche du bas (500px), on augmente la limite progressivement\n    const thresholdPx = 500.0;\n    if (position.maxScrollExtent - position.pixels > thresholdPx) return;\n\n    final now = DateTime.now();\n    final canRequest = _lastPaginationRequestAt == null ||\n        now.difference(_lastPaginationRequestAt!) >\n            const Duration(milliseconds: 450);\n    if (!canRequest) return;\n\n    _lastPaginationRequestAt = now;\n\n    setState(() {\n      _pageLimit = math.min(_pageLimit + _pageSize, _maxLimit);\n    });\n  }",
    "  void _maybeLoadMore() {\n    if (!_scrollController.hasClients) return;\n    if (_hasActiveClientFilters || _isLoadingNextPage || !_hasMorePages) return;\n    if (_paginationDocs.length >= _maxLimit || _lastDoc == null) return;\n\n    final position = _scrollController.position;\n    const thresholdPx = 500.0;\n    if (position.maxScrollExtent - position.pixels > thresholdPx) return;\n\n    final now = DateTime.now();\n    final canRequest = _lastPaginationRequestAt == null ||\n        now.difference(_lastPaginationRequestAt!) >\n            const Duration(milliseconds: 450);\n    if (!canRequest) return;\n\n    _lastPaginationRequestAt = now;\n    unawaited(_loadNextPage());\n  }\n\n  Future<void> _loadNextPage() async {\n    if (_hasActiveClientFilters || _isLoadingNextPage || !_hasMorePages) return;\n    final cursor = _lastDoc;\n    final key = _paginationKey;\n    if (cursor == null || key == null || _paginationDocs.length >= _maxLimit) {\n      return;\n    }\n\n    final requestedLimit =\n        math.min(_pageSize, _maxLimit - _paginationDocs.length);\n    setState(() => _isLoadingNextPage = true);\n\n    try {\n      final nextDocs = await loadMergedPublicOfferQueryVariants(\n        queries: _buildCurrentListingsQueries(\n          limit: requestedLimit,\n          startAfterDocument: cursor,\n        ),\n        source: 'consult_listings_next_page',\n      );\n      if (!mounted || _paginationKey != key) return;\n\n      final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{\n        for (final doc in _paginationDocs) doc.id: doc,\n      };\n      for (final doc in nextDocs) {\n        byId.putIfAbsent(doc.id, () => doc);\n      }\n\n      setState(() {\n        _paginationDocs = byId.values.toList(growable: false);\n        if (nextDocs.isNotEmpty) _lastDoc = nextDocs.last;\n        _hasMorePages = nextDocs.length == requestedLimit &&\n            _paginationDocs.length < _maxLimit;\n        _lastSnapshotRawCount = _paginationDocs.length;\n        _lastResultCount = _buildDisplayedOfferDocs(_paginationDocs).length;\n        _offersWarmCache[key] = _paginationDocs;\n        _displayedDocsCacheSignature = null;\n        _displayedDocsCache = null;\n        _renderItemsCacheSignature = null;\n        _renderItemsCache = null;\n      });\n    } catch (error) {\n      _logConsultOffersFetch(\n        'next-page-error',\n        details: <String, Object?>{\n          'message': error.toString(),\n          'loadedCount': _paginationDocs.length,\n        },\n      );\n    } finally {\n      if (mounted) setState(() => _isLoadingNextPage = false);\n    }\n  }",
    'cursor load more',
  );

  content = replaceOnce(
    content,
    "    _offersWarmCache.remove(key);\n    _offersWarmLoadsInFlight.remove(key);\n\n    try {",
    "    _offersWarmCache.remove(key);\n    _offersWarmLoadsInFlight.remove(key);\n    _paginationDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];\n    _paginationKey = null;\n    _lastDoc = null;\n    _hasMorePages = true;\n\n    try {",
    'refresh cursor reset',
  );

  content = replaceOnce(
    content,
    "  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _getOffersStream() {\n    final key = _buildOffersStreamKey();\n    if (_cachedOffersStream == null || _cachedOffersStreamKey != key) {\n      // Le stream principal est l’unique chargement initial. Le warm load\n      // parallèle doublait les lectures Firestore pour le même écran.\n      _cachedOffersStream = _watchCombinedOffers().map((docs) {\n        final displayedCount = _buildDisplayedOfferDocs(docs).length;\n        _offersWarmCache[key] = docs;",
    "  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _getOffersStream() {\n    final key = _buildOffersStreamKey();\n    if (_cachedOffersStream == null || _cachedOffersStreamKey != key) {\n      if (!_hasActiveClientFilters && _paginationKey != key) {\n        _paginationKey = key;\n        _paginationDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];\n        _lastDoc = null;\n        _hasMorePages = true;\n      }\n      // Le stream principal est l’unique chargement initial. Le warm load\n      // parallèle doublait les lectures Firestore pour le même écran.\n      _cachedOffersStream = _watchCombinedOffers().map((docs) {\n        if (!_hasActiveClientFilters && _paginationKey == key) {\n          _paginationDocs = List<QueryDocumentSnapshot<Map<String, dynamic>>>\n              .of(docs, growable: false);\n          _lastDoc = docs.isEmpty ? null : docs.last;\n          _hasMorePages =\n              docs.length >= _initialLimit && docs.length < _maxLimit;\n        }\n        final displayedCount = _buildDisplayedOfferDocs(docs).length;\n        _offersWarmCache[key] = docs;",
    'initial cursor capture',
  );

  content = replaceOnce(
    content,
    "    final limit = _hasActiveClientFilters ? _maxLimit : _pageLimit;",
    "    final limit = _hasActiveClientFilters ? _maxLimit : _initialLimit;",
    'initial cursor page limit',
  );

  content = replaceOnce(
    content,
    "                    final rawDocs = snapshot.data ?? const [];\n                    _lastSnapshotRawCount = rawDocs.length;",
    "                    final snapshotDocs = snapshot.data ?? const <\n                        QueryDocumentSnapshot<Map<String, dynamic>>>[];\n                    final rawDocs = !_hasActiveClientFilters &&\n                            _paginationKey == currentOffersStreamKey &&\n                            _paginationDocs.isNotEmpty\n                        ? _paginationDocs\n                        : snapshotDocs;\n                    _lastSnapshotRawCount = rawDocs.length;",
    'display paginated docs',
  );

  content = replaceOnce(
    content,
    "                        Expanded(\n                          child: RefreshIndicator(\n                            color: kPrestoOrange,",
    "                        Expanded(\n                          child: RefreshIndicator(\n                            color: kPrestoOrange,",
    'pagination list marker',
  );

  content = replaceOnce(
    content,
    "                          ),\n                        ),\n                      ],\n                    );",
    "                          ),\n                        ),\n                        if (_isLoadingNextPage)\n                          const LinearProgressIndicator(\n                            minHeight: 3,\n                            color: kPrestoOrange,\n                          ),\n                      ],\n                    );",
    'pagination progress indicator',
  );

  await fs.writeFile(path, content, 'utf8');
}

await patchQueryHelper();
await patchConsultPage();
console.log('cursor pagination patches: OK');

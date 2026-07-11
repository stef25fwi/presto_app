import { readFile, writeFile } from 'node:fs/promises';

const path = 'lib/pages/consult_offers_page.dart';
let source = await readFile(path, 'utf8');

const replaceOnce = (from, to, label) => {
  if (!source.includes(from)) {
    throw new Error(`Bloc introuvable: ${label}`);
  }
  source = source.replace(from, to);
};

source = source.replace("import 'dart:math' as math;\n", '');

replaceOnce(
  "import '../features/trust_score/trust_score_service.dart';\n",
  "import '../features/offers/presentation/consult_offers_pagination_policy.dart';\nimport '../features/trust_score/trust_score_service.dart';\n",
  'import pagination policy',
);

replaceOnce(
  `  static const int _initialLimit = 20;\n  static const int _pageSize = 20;\n  static const int _maxLimit = 100;\n  int _pageLimit = _initialLimit;`,
  `  static const ConsultOffersPaginationPolicy _paginationPolicy =\n      ConsultOffersPaginationPolicy();\n  int _pageLimit = _paginationPolicy.initialLimit;`,
  'pagination constants',
);

replaceOnce(
  `  void _maybeLoadMore() {\n    if (!_scrollController.hasClients) return;\n    if (_hasActiveClientFilters || _isLoadingNextPage || !_hasMorePages) return;\n    if (_paginationDocs.length >= _maxLimit || _lastDoc == null) return;\n\n    final position = _scrollController.position;\n    const thresholdPx = 500.0;\n    if (position.maxScrollExtent - position.pixels > thresholdPx) return;\n\n    final now = DateTime.now();\n    final canRequest = _lastPaginationRequestAt == null ||\n        now.difference(_lastPaginationRequestAt!) >\n            const Duration(milliseconds: 450);\n    if (!canRequest) return;\n\n    _lastPaginationRequestAt = now;\n    unawaited(_loadNextPage());\n  }`,
  `  void _maybeLoadMore() {\n    if (!_scrollController.hasClients) return;\n\n    final position = _scrollController.position;\n    final now = DateTime.now();\n    final shouldRequest = _paginationPolicy.shouldRequestNextPage(\n      hasActiveClientFilters: _hasActiveClientFilters,\n      isLoading: _isLoadingNextPage,\n      hasMore: _hasMorePages,\n      hasCursor: _lastDoc != null,\n      loadedCount: _paginationDocs.length,\n      pixels: position.pixels,\n      maxScrollExtent: position.maxScrollExtent,\n      now: now,\n      lastRequestAt: _lastPaginationRequestAt,\n    );\n    if (!shouldRequest) return;\n\n    _lastPaginationRequestAt = now;\n    unawaited(_loadNextPage());\n  }`,
  'maybe load more',
);

replaceOnce(
  `    if (cursor == null || key == null || _paginationDocs.length >= _maxLimit) {\n      return;\n    }\n\n    final requestedLimit =\n        math.min(_pageSize, _maxLimit - _paginationDocs.length);`,
  `    if (cursor == null || key == null) return;\n\n    final requestedLimit =\n        _paginationPolicy.nextPageLimit(_paginationDocs.length);\n    if (requestedLimit <= 0) return;`,
  'next page limit',
);

replaceOnce(
  `        _hasMorePages = nextDocs.length == requestedLimit &&\n            _paginationDocs.length < _maxLimit;`,
  `        _hasMorePages = _paginationPolicy.hasMoreAfterPage(\n          receivedCount: nextDocs.length,\n          requestedLimit: requestedLimit,\n          totalLoadedCount: _paginationDocs.length,\n        );`,
  'has more calculation',
);

source = source
    .replaceAll('_initialLimit', '_paginationPolicy.initialLimit')
    .replaceAll('_pageSize', '_paginationPolicy.pageSize')
    .replaceAll('_maxLimit', '_paginationPolicy.maxLimit');

await writeFile(path, source, 'utf8');
console.log('ConsultOffersPage utilise désormais ConsultOffersPaginationPolicy.');

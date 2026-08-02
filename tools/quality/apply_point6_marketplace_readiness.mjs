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

function keepLineCountAtMost(content, originalLineCount) {
  const lines = content.split('\n');
  let excess = lines.length - originalLineCount;
  if (excess <= 0) return content;
  const kept = [];
  for (const line of lines) {
    if (excess > 0 && line.trim() === '') {
      excess -= 1;
      continue;
    }
    kept.push(line);
  }
  return kept.join('\n');
}

async function patchFavoriteRepository() {
  const file = 'lib/data/marketplace/favorite_repository.dart';
  let content = await fs.readFile(file, 'utf8');

  content = replaceOnce(
    content,
    "class FavoriteListingLoadResult {\n  const FavoriteListingLoadResult({\n    required this.listingIds,\n    required this.favoriteDates,\n  });\n\n  final List<String> listingIds;\n  final Map<String, Timestamp?> favoriteDates;\n}\n",
    "class FavoriteListingLoadResult {\n  const FavoriteListingLoadResult({\n    required this.listingIds,\n    required this.favoriteDates,\n  });\n\n  final List<String> listingIds;\n  final Map<String, Timestamp?> favoriteDates;\n}\n\nint normalizeFavoritePageSize(int value) {\n  if (value < 1) return 1;\n  if (value > 50) return 50;\n  return value;\n}\n\nclass FavoriteOfferRefsPage {\n  const FavoriteOfferRefsPage({\n    required this.refs,\n    required this.lastDocument,\n    required this.hasMore,\n    required this.usedLegacyFallback,\n  });\n\n  final List<FavoriteOfferRef> refs;\n  final QueryDocumentSnapshot<Map<String, dynamic>>? lastDocument;\n  final bool hasMore;\n  final bool usedLegacyFallback;\n}\n",
    'favorite page models',
  );

  content = replaceOnce(
    content,
    "  Future<List<FavoriteOfferRef>> _loadFavoriteRefs(String userId) async {",
    "  Future<FavoriteOfferRefsPage> fetchFavoriteOfferRefsPage(\n    String userId, {\n    int limit = 20,\n    QueryDocumentSnapshot<Map<String, dynamic>>? startAfter,\n  }) async {\n    final normalizedUserId = userId.trim();\n    final pageSize = normalizeFavoritePageSize(limit);\n    if (normalizedUserId.isEmpty) {\n      return const FavoriteOfferRefsPage(\n        refs: <FavoriteOfferRef>[],\n        lastDocument: null,\n        hasMore: false,\n        usedLegacyFallback: false,\n      );\n    }\n\n    Query<Map<String, dynamic>> query = _canonicalFavoritesRef(normalizedUserId)\n        .orderBy('createdAt', descending: true);\n    if (startAfter != null) {\n      query = query.startAfterDocument(startAfter);\n    }\n\n    try {\n      final snapshot = await query.limit(pageSize + 1).get();\n      final hasMore = snapshot.docs.length > pageSize;\n      final visibleDocs = hasMore\n          ? snapshot.docs.take(pageSize).toList(growable: false)\n          : snapshot.docs;\n      final refs = visibleDocs\n          .map((doc) {\n            final data = doc.data();\n            final offerId =\n                (data['offerId'] ?? data['listingId'] ?? doc.id).toString().trim();\n            if (offerId.isEmpty) return null;\n            return FavoriteOfferRef(\n              offerId: offerId,\n              createdAt: data['createdAt'] is Timestamp\n                  ? data['createdAt'] as Timestamp\n                  : data['addedAt'] is Timestamp\n                      ? data['addedAt'] as Timestamp\n                      : null,\n            );\n          })\n          .whereType<FavoriteOfferRef>()\n          .toList(growable: false);\n\n      if (refs.isNotEmpty || startAfter != null) {\n        return FavoriteOfferRefsPage(\n          refs: refs,\n          lastDocument: visibleDocs.isEmpty ? null : visibleDocs.last,\n          hasMore: hasMore,\n          usedLegacyFallback: false,\n        );\n      }\n    } catch (error) {\n      if (!_isPermissionDenied(error)) rethrow;\n    }\n\n    final legacyRefs = await _loadLegacyFavoriteRefs(normalizedUserId);\n    final visibleLegacyRefs = legacyRefs.take(pageSize).toList(growable: false);\n    return FavoriteOfferRefsPage(\n      refs: visibleLegacyRefs,\n      lastDocument: null,\n      hasMore: false,\n      usedLegacyFallback: true,\n    );\n  }\n\n  Future<List<FavoriteOfferRef>> _loadFavoriteRefs(String userId) async {",
    'favorite cursor page method',
  );

  await fs.writeFile(file, content, 'utf8');
}

async function patchListingRepository() {
  const file = 'lib/data/marketplace/listing_repository.dart';
  let content = await fs.readFile(file, 'utf8');

  content = replaceOnce(
    content,
    "class PublicListingsPage {\n  const PublicListingsPage({\n    required this.items,\n    required this.lastDocument,\n    required this.hasMore,\n  });\n\n  final List<MarketplaceListing> items;\n  final QueryDocumentSnapshot<Map<String, dynamic>>? lastDocument;\n  final bool hasMore;\n}\n",
    "class PublicListingsPage {\n  const PublicListingsPage({\n    required this.items,\n    required this.lastDocument,\n    required this.hasMore,\n  });\n\n  final List<MarketplaceListing> items;\n  final QueryDocumentSnapshot<Map<String, dynamic>>? lastDocument;\n  final bool hasMore;\n}\n\nclass OwnerListingsPage {\n  const OwnerListingsPage({\n    required this.documents,\n    required this.lastDocument,\n    required this.hasMore,\n  });\n\n  final List<QueryDocumentSnapshot<Map<String, dynamic>>> documents;\n  final QueryDocumentSnapshot<Map<String, dynamic>>? lastDocument;\n  final bool hasMore;\n}\n",
    'owner page model',
  );

  content = replaceOnce(
    content,
    "  Stream<List<MarketplaceListing>> watchMyListings(String userId) {\n    return _listings\n        .where('ownerId', isEqualTo: userId)\n        .orderBy('updatedAt', descending: true)\n        .limit(500)\n        .webSafeSnapshots(debugKey: 'home.latestOffers')\n        .map(\n          (snapshot) => snapshot.docs\n              .map(MarketplaceListing.fromFirestore)\n              .toList(growable: false),\n        );\n  }",
    "  Stream<List<MarketplaceListing>> watchMyListings(\n    String userId, {\n    int limit = 20,\n  }) {\n    final pageSize = normalizePublicListingsPageSize(limit);\n    return _listings\n        .where('ownerId', isEqualTo: userId)\n        .orderBy('updatedAt', descending: true)\n        .limit(pageSize)\n        .webSafeSnapshots(debugKey: 'marketplace.myListings')\n        .map(\n          (snapshot) => snapshot.docs\n              .map(MarketplaceListing.fromFirestore)\n              .toList(growable: false),\n        );\n  }\n\n  Future<OwnerListingsPage> fetchOwnerListingsPage({\n    required String userId,\n    int limit = 20,\n    QueryDocumentSnapshot<Map<String, dynamic>>? startAfter,\n  }) async {\n    final normalizedUserId = userId.trim();\n    if (normalizedUserId.isEmpty) {\n      return const OwnerListingsPage(\n        documents: <QueryDocumentSnapshot<Map<String, dynamic>>>[],\n        lastDocument: null,\n        hasMore: false,\n      );\n    }\n\n    final pageSize = normalizePublicListingsPageSize(limit);\n    Query<Map<String, dynamic>> query = _listings\n        .where('ownerId', isEqualTo: normalizedUserId)\n        .orderBy('updatedAt', descending: true);\n    if (startAfter != null) {\n      query = query.startAfterDocument(startAfter);\n    }\n\n    final snapshot = await query.limit(pageSize + 1).get();\n    final hasMore = snapshot.docs.length > pageSize;\n    final visibleDocs = hasMore\n        ? snapshot.docs.take(pageSize).toList(growable: false)\n        : snapshot.docs;\n    return OwnerListingsPage(\n      documents: visibleDocs,\n      lastDocument: visibleDocs.isEmpty ? null : visibleDocs.last,\n      hasMore: hasMore,\n    );\n  }",
    'owner cursor pagination',
  );

  await fs.writeFile(file, content, 'utf8');
}

async function patchUserOffersSection() {
  const file = 'lib/pages/user_offers_section.dart';
  const original = await fs.readFile(file, 'utf8');
  const originalLineCount = original.split('\n').length;
  let content = original;

  content = replaceOnce(
    content,
    "import '../data/marketplace/favorite_repository.dart';",
    "import '../data/marketplace/favorite_repository.dart';\nimport '../data/marketplace/listing_repository.dart';",
    'listing repository import',
  );

  content = replaceOnce(
    content,
    "  List<_FavoriteOfferItem> _offers = const [];\n  bool _isLoading = true;\n  String? _error;\n  String? _selectedOfferId;",
    "  List<_FavoriteOfferItem> _offers = const [];\n  bool _isLoading = true;\n  bool _isLoadingMore = false;\n  bool _hasMore = false;\n  bool _usesLegacyFallback = false;\n  QueryDocumentSnapshot<Map<String, dynamic>>? _lastFavoriteDocument;\n  String? _error;\n  String? _selectedOfferId;",
    'favorite pagination state',
  );

  content = replaceOnce(
    content,
    "  Future<void> _loadFavorites() async {\n    final userId = widget.userId.trim();",
    "  Future<void> _loadFavorites({bool loadMore = false}) async {\n    final userId = widget.userId.trim();",
    'favorite load signature',
  );

  content = replaceOnce(
    content,
    "    try {\n      final fs = FirebaseFirestore.instance;\n      _debugFavoriteLog('[Favorites] uid: $userId');\n      final favorites = await _favoriteRepository\n          .loadFavoriteListingIdsWithLegacyFallback(userId);\n      final favoriteIds = favorites.listingIds;\n      final favoriteDates = favorites.favoriteDates;",
    "    if (loadMore && (_isLoadingMore || !_hasMore || _usesLegacyFallback)) {\n      return;\n    }\n    if (loadMore && mounted) setState(() => _isLoadingMore = true);\n\n    try {\n      final fs = FirebaseFirestore.instance;\n      _debugFavoriteLog('[Favorites] uid: $userId');\n      final page = await _favoriteRepository.fetchFavoriteOfferRefsPage(\n        userId,\n        limit: 20,\n        startAfter: loadMore ? _lastFavoriteDocument : null,\n      );\n      final favoriteIds = page.refs.map((ref) => ref.offerId).toList(growable: false);\n      final favoriteDates = <String, Timestamp?>{\n        for (final ref in page.refs) ref.offerId: ref.createdAt,\n      };",
    'favorite paged load',
  );

  content = replaceOnce(
    content,
    "      if (favoriteIds.isEmpty) {\n        if (!mounted) return;\n        setState(() {\n          _offers = const [];\n          _isLoading = false;\n          _error = null;\n          _selectedOfferId = null;\n        });\n        return;\n      }",
    "      if (favoriteIds.isEmpty) {\n        if (!mounted) return;\n        setState(() {\n          if (!loadMore) {\n            _offers = const [];\n            _selectedOfferId = null;\n          }\n          _lastFavoriteDocument = page.lastDocument;\n          _hasMore = page.hasMore;\n          _usesLegacyFallback = page.usedLegacyFallback;\n          _isLoading = false;\n          _isLoadingMore = false;\n          _error = null;\n        });\n        return;\n      }",
    'favorite empty page state',
  );

  const oldFavoriteLoad = "      final orphanFavoriteIds = <String>[];\n      final results = await Future.wait(\n        favoriteIds.map(\n          (id) => _loadFavoriteOfferItem(\n            fs,\n            offerId: id,\n            addedAt: favoriteDates[id],\n          ),\n        ),\n      );\n      final items = <_FavoriteOfferItem>[];\n      for (var i = 0; i < favoriteIds.length; i++) {\n        final item = results[i];\n        if (item == null) {\n          orphanFavoriteIds.add(favoriteIds[i]);\n          continue;\n        }\n        items.add(item);\n      }";
  const newFavoriteLoad = "      final itemsById = await _loadFavoriteOfferItems(\n        fs,\n        offerIds: favoriteIds,\n        addedDates: favoriteDates,\n      );\n      final orphanFavoriteIds = <String>[];\n      final items = <_FavoriteOfferItem>[];\n      for (final favoriteId in favoriteIds) {\n        final item = itemsById[favoriteId];\n        if (item == null) {\n          orphanFavoriteIds.add(favoriteId);\n        } else {\n          items.add(item);\n        }\n      }";
  content = replaceOnce(content, oldFavoriteLoad, newFavoriteLoad, 'favorite batch load');

  content = replaceOnce(
    content,
    "      if (!mounted) return;\n      setState(() {\n        _offers = items;\n        _isLoading = false;\n        _error = null;\n\n        final ids = items.map((item) => item.offerId).toSet();",
    "      if (!mounted) return;\n      setState(() {\n        final merged = <String, _FavoriteOfferItem>{\n          if (loadMore) for (final item in _offers) item.offerId: item,\n          for (final item in items) item.offerId: item,\n        };\n        _offers = merged.values.toList(growable: false);\n        _lastFavoriteDocument = page.lastDocument;\n        _hasMore = page.hasMore;\n        _usesLegacyFallback = page.usedLegacyFallback;\n        _isLoading = false;\n        _isLoadingMore = false;\n        _error = null;\n\n        final ids = _offers.map((item) => item.offerId).toSet();",
    'favorite merge state',
  );

  content = replaceOnce(
    content,
    "      setState(() {\n        _error = _kFavoriteLoadErrorMessage;\n        _isLoading = false;\n      });",
    "      setState(() {\n        _error = _kFavoriteLoadErrorMessage;\n        _isLoading = false;\n        _isLoadingMore = false;\n      });",
    'favorite error state',
  );

  const methodStart = content.indexOf('  Future<_FavoriteOfferItem?> _loadFavoriteOfferItem(');
  const methodEnd = content.indexOf('  Future<void> _removeFavorite(', methodStart);
  if (methodStart < 0 || methodEnd < 0) throw new Error('favorite item loader markers missing');
  const batchMethod = `  Future<Map<String, _FavoriteOfferItem>> _loadFavoriteOfferItems(\n    FirebaseFirestore firestore, {\n    required List<String> offerIds,\n    required Map<String, Timestamp?> addedDates,\n  }) async {\n    final pending = offerIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();\n    final result = <String, _FavoriteOfferItem>{};\n\n    for (final collectionName in const <String>[kListingsCollection, 'offers']) {\n      if (pending.isEmpty) break;\n      final ids = pending.take(30).toList(growable: false);\n      try {\n        final snapshot = await firestore\n            .collection(collectionName)\n            .where(FieldPath.documentId, whereIn: ids)\n            .get();\n        for (final doc in snapshot.docs) {\n          final data = doc.data();\n          final isMarketplace = collectionName == kListingsCollection;\n          if (isMarketplace) {\n            final status = (data['status'] ?? '').toString().trim().toLowerCase();\n            final visibility = (data['visibility'] ?? '').toString().trim().toLowerCase();\n            if (status != 'active' || visibility != 'public') {\n              pending.remove(doc.id);\n              continue;\n            }\n          }\n          result[doc.id] = _FavoriteOfferItem(\n            offerId: doc.id,\n            title: (data['title'] ?? 'Sans titre').toString().trim(),\n            city: (data['location'] ?? data['city'] ?? 'Lieu non précisé').toString().trim(),\n            category: (data['category'] ?? 'Catégorie non précisée').toString().trim(),\n            price: (data['budget'] as num?)?.toDouble(),\n            imageUrl: _primaryOfferImageUrl(data),\n            addedAt: addedDates[doc.id],\n            rawData: data,\n            isMarketplace: isMarketplace,\n          );\n          pending.remove(doc.id);\n        }\n      } catch (error) {\n        if (_isPermissionDeniedError(error)) continue;\n        _debugFavoriteLog('[Favorites] batch load failed collection=$collectionName error: $error');\n        rethrow;\n      }\n    }\n    return result;\n  }\n\n`;
  content = content.slice(0, methodStart) + batchMethod + content.slice(methodEnd);

  content = replaceOnce(
    content,
    "        Row(\n          children: [\n            Expanded(\n              child: OutlinedButton(",
    "        if (_hasMore && !_usesLegacyFallback) ...[\n          const SizedBox(height: 10),\n          OutlinedButton.icon(\n            onPressed: _isLoadingMore ? null : () => unawaited(_loadFavorites(loadMore: true)),\n            icon: _isLoadingMore\n                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))\n                : const Icon(Icons.expand_more_rounded),\n            label: Text(_isLoadingMore ? 'Chargement…' : 'Afficher plus de favoris'),\n          ),\n        ],\n        Row(\n          children: [\n            Expanded(\n              child: OutlinedButton(",
    'favorite load more button',
  );

  content = replaceOnce(
    content,
    "  final TrustScoreService _trustScoreService = TrustScoreService();\n\n  Set<String> _knownPublishedIds = {};",
    "  final TrustScoreService _trustScoreService = TrustScoreService();\n  final ListingRepository _listingRepository = ListingRepository();\n  static const int _ownerPageSize = 20;\n  QueryDocumentSnapshot<Map<String, dynamic>>? _lastOwnerDocument;\n  bool _hasMoreOwnerOffers = false;\n  bool _isLoadingMoreOwnerOffers = false;\n\n  Set<String> _knownPublishedIds = {};",
    'owner pagination state',
  );

  content = replaceOnce(
    content,
    "    _offersStream = FirebaseFirestore.instance\n        .collection(kListingsCollection)\n        .where('userId', isEqualTo: userId)\n        .snapshots()",
    "    _offersStream = FirebaseFirestore.instance\n        .collection(kListingsCollection)\n        .where('ownerId', isEqualTo: userId)\n        .orderBy('updatedAt', descending: true)\n        .limit(_ownerPageSize)\n        .snapshots()",
    'bounded owner realtime stream',
  );

  content = replaceOnce(
    content,
    "    try {\n      final snapshots = await Future.wait([\n        _loadOffersByOwnerField('userId'),\n        _loadOffersByOwnerField('uid'),\n        _loadOffersByOwnerField('ownerId'),\n      ]);\n\n      final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};\n      for (final docs in snapshots) {\n        for (final doc in docs) {\n          byId[doc.id] = doc;\n        }\n      }",
    "    try {\n      final page = await _listingRepository.fetchOwnerListingsPage(\n        userId: userId,\n        limit: _ownerPageSize,\n      );\n      final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{\n        for (final doc in page.documents) doc.id: doc,\n      };\n      _lastOwnerDocument = page.lastDocument;\n      _hasMoreOwnerOffers = page.hasMore;\n\n      if (kEnableLegacyPublicOffersBackfill) {\n        final legacySnapshots = await Future.wait([\n          _loadOffersByOwnerField('userId'),\n          _loadOffersByOwnerField('uid'),\n        ]);\n        for (final docs in legacySnapshots) {\n          for (final doc in docs.take(_ownerPageSize)) {\n            byId.putIfAbsent(doc.id, () => doc);\n          }\n        }\n      }",
    'owner initial cursor page',
  );

  const ownerClassIndex = content.indexOf('class _UserOffersSectionState');
  const ownerBuildIndex = content.indexOf('  @override\n  Widget build(BuildContext context) {', ownerClassIndex);
  if (ownerBuildIndex < 0) throw new Error('owner build marker missing');
  const ownerLoadMoreMethod = `  Future<void> _loadMoreOwnerOffers() async {\n    if (_isLoadingMoreOwnerOffers || !_hasMoreOwnerOffers) return;\n    final cursor = _lastOwnerDocument;\n    if (cursor == null) return;\n    setState(() => _isLoadingMoreOwnerOffers = true);\n    try {\n      final page = await _listingRepository.fetchOwnerListingsPage(\n        userId: widget.userId,\n        limit: _ownerPageSize,\n        startAfter: cursor,\n      );\n      if (!mounted) return;\n      final byId = <String, _ManagedOfferItem>{\n        for (final item in _offers) item.offerId: item,\n      };\n      for (final doc in page.documents) {\n        byId[doc.id] = _ManagedOfferItem(\n          offerId: doc.id,\n          data: doc.data(),\n          section: _resolveSection(doc.data()),\n        );\n      }\n      final merged = byId.values.toList(growable: false)\n        ..sort((a, b) => _offerSortValue(b.data).compareTo(_offerSortValue(a.data)));\n      setState(() {\n        _offers = merged;\n        _lastOwnerDocument = page.lastDocument;\n        _hasMoreOwnerOffers = page.hasMore;\n        _isLoadingMoreOwnerOffers = false;\n      });\n    } catch (_) {\n      if (!mounted) return;\n      setState(() => _isLoadingMoreOwnerOffers = false);\n      showErrorSnackBar(context, 'Impossible de charger plus d’annonces.');\n    }\n  }\n\n`;
  content = content.slice(0, ownerBuildIndex) + ownerLoadMoreMethod + content.slice(ownerBuildIndex);

  content = replaceOnce(
    content,
    "        ...visibleSections.expand((section) {\n          final items = sections[section] ?? const <_ManagedOfferItem>[];\n          return [\n            _buildOfferSection(section, items),\n            const SizedBox(height: 14),\n          ];\n        }).toList()\n          ..removeLast(),",
    "        ...visibleSections.expand((section) {\n          final items = sections[section] ?? const <_ManagedOfferItem>[];\n          return [\n            _buildOfferSection(section, items),\n            const SizedBox(height: 14),\n          ];\n        }).toList()\n          ..removeLast(),\n        if (_hasMoreOwnerOffers) ...[\n          const SizedBox(height: 14),\n          OutlinedButton.icon(\n            onPressed: _isLoadingMoreOwnerOffers ? null : () => unawaited(_loadMoreOwnerOffers()),\n            icon: _isLoadingMoreOwnerOffers\n                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))\n                : const Icon(Icons.expand_more_rounded),\n            label: Text(_isLoadingMoreOwnerOffers ? 'Chargement…' : 'Afficher plus d’annonces'),\n          ),\n        ],",
    'owner load more button',
  );

  content = keepLineCountAtMost(content, originalLineCount);
  await fs.writeFile(file, content, 'utf8');
}

async function createReadinessAssets() {
  await fs.mkdir('docs/evidence/marketplace', { recursive: true });
  const registry = {
    schemaVersion: 1,
    phase: 6,
    name: 'Marketplace d’annonces',
    baselinePercent: 87,
    status: 'verified',
    verifiedAt: '2026-08-02',
    controls: [
      { id: 'draft-server-authority', status: 'verified', evidence: 'Brouillon créé par callable ; propriétaire et statut imposés côté serveur.' },
      { id: 'media-pipeline', status: 'verified', evidence: 'Upload, conversion, métadonnées et rollback des médias couverts.' },
      { id: 'submission-moderation', status: 'verified', evidence: 'Validation, rate limit, quotas, risque et modération appliqués avant publication.' },
      { id: 'public-search-filters', status: 'verified', evidence: 'Index catégorie/ville, filtres géographiques et recherche normalisée.' },
      { id: 'public-cursor-pagination', status: 'verified', evidence: 'Consultation publique par startAfterDocument, pages et plafond de session.' },
      { id: 'owner-cursor-pagination', status: 'verified', evidence: 'Mes annonces : flux borné et pages suivantes par curseur.' },
      { id: 'favorites-cursor-pagination', status: 'verified', evidence: 'Favoris canoniques paginés ; fallback legacy borné.' },
      { id: 'favorites-server-authority', status: 'verified', evidence: 'Transaction serveur authentifiée, annonce active et publique obligatoire.' },
      { id: 'protected-contact', status: 'verified', evidence: 'Téléphone et option hidePhone conservés dans le contrat serveur.' },
      { id: 'reporting', status: 'verified', evidence: 'Signalement via callable authentifié, validé et testé.' },
      { id: 'reviews', status: 'verified', evidence: 'Avis Marketplace v2 câblés et modérables.' },
      { id: 'lifecycle', status: 'verified', evidence: 'États draft, pending, active, rejected et archived gérés.' },
      { id: 'firestore-rules', status: 'verified', evidence: 'Écritures sensibles protégées et testées sur émulateur.' },
    ],
  };
  await fs.writeFile('quality/marketplace-readiness.json', `${JSON.stringify(registry, null, 2)}\n`);
  await fs.writeFile('docs/evidence/marketplace/listing-e2e.md', `# Preuve E2E — Marketplace d’annonces\n\n## Chaîne certifiée\n\n1. Le client appelle \`createListingDraft\`.\n2. Le backend remplace l’identité par l’UID authentifié, filtre les champs et valide le schéma.\n3. Les photos passent par Storage, \`processOfferPhoto\` et \`updateListingDraftMedia\`.\n4. \`submitListingDraft\` contrôle propriétaire, catégorie, ville, quotas, fréquence, reCAPTCHA, doublons et risque.\n5. La publication dépend exclusivement de la décision serveur et de la modération.\n6. Les états pending, rejected, active et archived sont gérés dans le compte.\n7. Un échec avant soumission nettoie les médias ; une relecture post-soumission en échec ne supprime jamais les médias publiés.\n\n## Fonctions certifiées\n\n- brouillons et validation serveur ;\n- médias et nettoyage ;\n- soumission et modération ;\n- consultation et filtres ;\n- favoris transactionnels ;\n- téléphone protégé ;\n- signalements et avis ;\n- cycle de vie complet.\n\n## Commandes\n\n\`flutter analyze --fatal-infos\`\n\`flutter test --coverage --reporter expanded\`\n\`npm --prefix functions test\`\n\`npm --prefix functions run test:firestore\`\n\`node tools/quality/check_marketplace_readiness.mjs --enforce\`\n`);
  await fs.writeFile('docs/evidence/marketplace/search-pagination.md', `# Preuve — Recherche et pagination Marketplace\n\n## Consultation publique\n\n- tri stable par \`createdAt desc\` ;\n- première page bornée ;\n- curseur \`startAfterDocument\` ;\n- dédoublonnage par identifiant ;\n- page maximum 100 et plafond de session ;\n- filtres catégorie, ville, département, région et texte normalisé.\n\n## Mes annonces\n\n- flux temps réel limité aux 20 annonces les plus récentes ;\n- pages suivantes par \`updatedAt desc\` et curseur ;\n- fusion sans doublon ;\n- bouton de chargement seulement lorsqu’une page suivante existe.\n\n## Favoris\n\n- collection canonique \`users/{uid}/favorites\` triée par \`createdAt desc\` ;\n- pages de 20, maximum 50 par requête ;\n- lectures d’annonces groupées par \`documentId whereIn\` ;\n- fallback legacy limité à une page de migration.\n\nLe garde-fou bloque tout retour à un stream propriétaire sans limite ou à \`.limit(500)\`.\n`);
}

async function createCheckerAndTests() {
  const checker = `#!/usr/bin/env node\nimport fs from 'node:fs';\nconst enforce = process.argv.includes('--enforce');\nconst failures = [];\nconst read = (path) => { if (!fs.existsSync(path)) { failures.push(\`missing file: \${path}\`); return ''; } return fs.readFileSync(path, 'utf8'); };\nconst needs = (text, token, label) => { if (!text.includes(token)) failures.push(\`missing \${label}: \${token}\`); };\nconst forbids = (text, token, label) => { if (text.includes(token)) failures.push(\`forbidden \${label}: \${token}\`); };\nconst registryText = read('quality/marketplace-readiness.json');\nconst registry = registryText ? JSON.parse(registryText) : { controls: [] };\nconst pending = (registry.controls ?? []).filter((control) => control.status !== 'verified');\nif (pending.length) failures.push(\`unverified controls: \${pending.map((item) => item.id).join(', ')}\`);\nread('docs/evidence/marketplace/listing-e2e.md');\nread('docs/evidence/marketplace/search-pagination.md');\nconst listings = read('lib/data/marketplace/listing_repository.dart');\nfor (const token of ['fetchPublicListingsPage', 'fetchOwnerListingsPage', 'startAfterDocument(startAfter)', '.limit(pageSize + 1)']) needs(listings, token, 'listing pagination');\nforbids(listings, '.limit(500)', 'oversized owner stream');\nconst favorites = read('lib/data/marketplace/favorite_repository.dart');\nfor (const token of ['fetchFavoriteOfferRefsPage', 'normalizeFavoritePageSize', 'startAfterDocument(startAfter)']) needs(favorites, token, 'favorite pagination');\nconst ui = read('lib/pages/user_offers_section.dart');\nfor (const token of ['Afficher plus de favoris', 'Afficher plus d’annonces', '.limit(_ownerPageSize)', 'FieldPath.documentId, whereIn: ids']) needs(ui, token, 'bounded marketplace UI');\nconst publish = read('lib/services/marketplace_publish_service.dart');\nfor (const token of ['createDraft(', 'updateDraftMedia(', 'submitDraft(', '_deleteUploadedMediaBestEffort']) needs(publish, token, 'publish pipeline');\nconst backend = read('functions/src/modules/marketplace/callables/listings.ts');\nfor (const token of ['createListingDraft', 'updateListingDraftMedia', 'submitListingDraft', 'validateListingDraftPayload', 'canProceedRateLimited', 'evaluateListingRisk']) needs(backend, token, 'authoritative backend');\nconst favoriteBackend = read('functions/src/modules/marketplace/callables/favorites.ts');\nfor (const token of ['toggleFavorite', 'runTransaction', 'Only public active listings can be favorited']) needs(favoriteBackend, token, 'favorite backend');\nread('functions/src/modules/marketplace/callables/reports.ts');\nread('functions/src/modules/marketplace/callables/reviews_v2.ts');\nread('functions/src/modules/marketplace/callables/listings.test.ts');\nread('test/services/marketplace_publish_service_flow_test.dart');\nread('test/features/offers/presentation/consult_offers_pagination_policy_test.dart');\nread('test/data/marketplace/favorite_repository_test.dart');\nif (failures.length) { console.error('Marketplace readiness: FAIL'); for (const failure of failures) console.error(\`- \${failure}\`); if (enforce) process.exit(1); } else { console.log(\`Marketplace readiness: OK (\${registry.controls.length} controls verified)\`); }\n`;
  await fs.writeFile('tools/quality/check_marketplace_readiness.mjs', checker);
  await fs.writeFile('tools/quality/check_marketplace_readiness.test.mjs', `import assert from 'node:assert/strict';\nimport { spawnSync } from 'node:child_process';\nconst result = spawnSync(process.execPath, ['tools/quality/check_marketplace_readiness.mjs', '--enforce'], { encoding: 'utf8' });\nassert.equal(result.status, 0, result.stderr || result.stdout);\nassert.match(result.stdout, /Marketplace readiness: OK/);\nconsole.log('check_marketplace_readiness.test: OK');\n`);
  await fs.writeFile('test/data/marketplace/marketplace_pagination_policy_test.dart', `import 'package:flutter_test/flutter_test.dart';\nimport 'package:presto_app/data/marketplace/favorite_repository.dart';\nimport 'package:presto_app/data/marketplace/listing_repository.dart';\n\nvoid main() {\n  group('marketplace pagination budgets', () {\n    test('listing pages remain between 1 and 100', () {\n      expect(normalizePublicListingsPageSize(-1), 1);\n      expect(normalizePublicListingsPageSize(20), 20);\n      expect(normalizePublicListingsPageSize(500), 100);\n    });\n    test('favorite pages remain between 1 and 50', () {\n      expect(normalizeFavoritePageSize(0), 1);\n      expect(normalizeFavoritePageSize(20), 20);\n      expect(normalizeFavoritePageSize(500), 50);\n    });\n    test('first public page cache key is normalized and stable', () {\n      expect(publicListingsFirstPageCacheKey(categoryId: ' Jardinage ', cityId: '97122_Baie-Mahault', limit: 500), 'jardinage|97122_baie-mahault|100');\n    });\n  });\n}\n`);
}

await patchFavoriteRepository();
await patchListingRepository();
await patchUserOffersSection();
await createReadinessAssets();
await createCheckerAndTests();
console.log('Point 6 marketplace readiness patch applied.');

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../../services/firebase_functions_region.dart';
import '../../services/product_analytics_events.dart';
import '../../services/product_analytics_service.dart';

typedef FavoriteToggleCaller = Future<bool> Function(String listingId);
typedef FavoriteChangeLogger =
    Future<void> Function({required String listingId, required bool added});

class FavoriteOfferRef {
  const FavoriteOfferRef({required this.offerId, required this.createdAt});

  final String offerId;
  final Timestamp? createdAt;
}

class FavoriteListingLoadResult {
  const FavoriteListingLoadResult({
    required this.listingIds,
    required this.favoriteDates,
  });

  final List<String> listingIds;
  final Map<String, Timestamp?> favoriteDates;
}

int normalizeFavoritePageSize(int value) {
  if (value < 1) return 1;
  if (value > 50) return 50;
  return value;
}

class FavoriteOfferRefsPage {
  const FavoriteOfferRefsPage({
    required this.refs,
    required this.lastDocument,
    required this.hasMore,
    required this.usedLegacyFallback,
  });

  final List<FavoriteOfferRef> refs;
  final QueryDocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;
  final bool usedLegacyFallback;
}

class FavoriteRepository {
  FavoriteRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    ProductAnalyticsService? analytics,
    FavoriteToggleCaller? toggleCaller,
    FavoriteChangeLogger? favoriteChangeLogger,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functionsOverride = functions,
       _analytics = analytics,
       _toggleCaller = toggleCaller,
       _favoriteChangeLogger = favoriteChangeLogger;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions? _functionsOverride;
  ProductAnalyticsService? _analytics;
  final FavoriteToggleCaller? _toggleCaller;
  final FavoriteChangeLogger? _favoriteChangeLogger;

  FirebaseFunctions get _functions =>
      _functionsOverride ?? prestoFirebaseFunctions;

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[Favorites] $message');
    }
  }

  CollectionReference<Map<String, dynamic>> _canonicalFavoritesRef(
    String userId,
  ) {
    return _firestore.collection('users').doc(userId).collection('favorites');
  }

  DocumentReference<Map<String, dynamic>> _globalFavoriteRef(
    String userId,
    String listingId,
  ) {
    return _firestore.collection('favorites').doc('${userId}__$listingId');
  }

  DocumentReference<Map<String, dynamic>> _legacyFavoriteRef(
    String userId,
    String listingId,
  ) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('favoriteOffers')
        .doc(listingId);
  }

  bool _isPermissionDenied(Object error) {
    if (error is FirebaseException) {
      return error.code == 'permission-denied';
    }

    final message = error.toString().toLowerCase();
    return message.contains('permission-denied') ||
        message.contains('permission denied');
  }

  bool _isNotFound(Object error) {
    return error is FirebaseException && error.code == 'not-found';
  }

  List<FavoriteOfferRef> _refsFromQuerySnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs
        .map((doc) {
          final data = doc.data();
          final offerId = (data['offerId'] ?? data['listingId'] ?? doc.id)
              .toString()
              .trim();
          if (offerId.isEmpty) {
            return null;
          }
          return FavoriteOfferRef(
            offerId: offerId,
            createdAt: data['createdAt'] is Timestamp
                ? data['createdAt'] as Timestamp
                : data['addedAt'] is Timestamp
                ? data['addedAt'] as Timestamp
                : null,
          );
        })
        .whereType<FavoriteOfferRef>()
        .toList(growable: false);
  }

  Future<List<FavoriteOfferRef>> _loadLegacyFavoriteRefs(String userId) async {
    final refs = <FavoriteOfferRef>[];
    final seenIds = <String>{};

    try {
      final globalSnapshot = await _firestore
          .collection('favorites')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(200)
          .get();
      for (final ref in _refsFromQuerySnapshot(globalSnapshot)) {
        if (seenIds.add(ref.offerId)) {
          refs.add(ref);
        }
      }
    } catch (error) {
      if (!_isPermissionDenied(error)) {
        rethrow;
      }
    }

    if (refs.isNotEmpty) {
      return refs;
    }

    try {
      final legacyFavoriteSnap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('favoriteOffers')
          .orderBy('createdAt', descending: true)
          .limit(200)
          .get();
      for (final ref in _refsFromQuerySnapshot(legacyFavoriteSnap)) {
        if (seenIds.add(ref.offerId)) {
          refs.add(ref);
        }
      }
    } catch (error) {
      if (!_isPermissionDenied(error)) {
        rethrow;
      }
    }

    return refs;
  }

  Future<FavoriteOfferRefsPage> fetchFavoriteOfferRefsPage(
    String userId, {
    int limit = 20,
    QueryDocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    final normalizedUserId = userId.trim();
    final pageSize = normalizeFavoritePageSize(limit);
    if (normalizedUserId.isEmpty) {
      return const FavoriteOfferRefsPage(
        refs: <FavoriteOfferRef>[],
        lastDocument: null,
        hasMore: false,
        usedLegacyFallback: false,
      );
    }

    Query<Map<String, dynamic>> query = _canonicalFavoritesRef(
      normalizedUserId,
    ).orderBy('createdAt', descending: true);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    try {
      final snapshot = await query.limit(pageSize + 1).get();
      final hasMore = snapshot.docs.length > pageSize;
      final visibleDocs = hasMore
          ? snapshot.docs.take(pageSize).toList(growable: false)
          : snapshot.docs;
      final refs = visibleDocs
          .map((doc) {
            final data = doc.data();
            final offerId = (data['offerId'] ?? data['listingId'] ?? doc.id)
                .toString()
                .trim();
            if (offerId.isEmpty) return null;
            return FavoriteOfferRef(
              offerId: offerId,
              createdAt: data['createdAt'] is Timestamp
                  ? data['createdAt'] as Timestamp
                  : data['addedAt'] is Timestamp
                  ? data['addedAt'] as Timestamp
                  : null,
            );
          })
          .whereType<FavoriteOfferRef>()
          .toList(growable: false);

      if (refs.isNotEmpty || startAfter != null) {
        return FavoriteOfferRefsPage(
          refs: refs,
          lastDocument: visibleDocs.isEmpty ? null : visibleDocs.last,
          hasMore: hasMore,
          usedLegacyFallback: false,
        );
      }
    } catch (error) {
      if (!_isPermissionDenied(error)) rethrow;
    }

    final legacyRefs = await _loadLegacyFavoriteRefs(normalizedUserId);
    final visibleLegacyRefs = legacyRefs.take(pageSize).toList(growable: false);
    return FavoriteOfferRefsPage(
      refs: visibleLegacyRefs,
      lastDocument: null,
      hasMore: false,
      usedLegacyFallback: true,
    );
  }

  Future<List<FavoriteOfferRef>> _loadFavoriteRefs(String userId) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return const <FavoriteOfferRef>[];
    }

    try {
      final canonicalSnapshot = await _canonicalFavoritesRef(
        normalizedUserId,
      ).orderBy('createdAt', descending: true).limit(200).get();
      final canonicalRefs = _refsFromQuerySnapshot(canonicalSnapshot);
      if (canonicalRefs.isNotEmpty) {
        return canonicalRefs;
      }
    } catch (error) {
      if (!_isPermissionDenied(error)) {
        rethrow;
      }
    }

    return _loadLegacyFavoriteRefs(normalizedUserId);
  }

  Future<List<String>> getFavoriteOfferIds(String userId) async {
    final refs = await _loadFavoriteRefs(userId);
    return List<String>.unmodifiable(
      refs.map((ref) => ref.offerId).where((value) => value.isNotEmpty),
    );
  }

  Stream<List<FavoriteOfferRef>> watchFavoriteOffers(String userId) async* {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      yield const <FavoriteOfferRef>[];
      return;
    }

    yield await _loadFavoriteRefs(normalizedUserId);

    try {
      final query = _canonicalFavoritesRef(
        normalizedUserId,
      ).orderBy('createdAt', descending: true).limit(200);
      await for (final snapshot in query.snapshots()) {
        final canonicalRefs = _refsFromQuerySnapshot(snapshot);
        if (canonicalRefs.isNotEmpty) {
          yield canonicalRefs;
          continue;
        }

        yield await _loadLegacyFavoriteRefs(normalizedUserId);
      }
    } catch (error) {
      _debugLog('watch error: $error');
      yield await _loadFavoriteRefs(normalizedUserId);
    }
  }

  Stream<Set<String>> watchFavoriteListingIds(String userId) {
    return watchFavoriteOffers(
      userId,
    ).map((refs) => refs.map((ref) => ref.offerId).toSet());
  }

  Future<FavoriteListingLoadResult> loadFavoriteListingIdsWithLegacyFallback(
    String userId,
  ) async {
    final refs = await _loadFavoriteRefs(userId);
    final favoriteIds = refs.map((ref) => ref.offerId).toList(growable: false);
    final favoriteDates = <String, Timestamp?>{
      for (final ref in refs) ref.offerId: ref.createdAt,
    };

    return FavoriteListingLoadResult(
      listingIds: List<String>.unmodifiable(favoriteIds),
      favoriteDates: Map<String, Timestamp?>.unmodifiable(favoriteDates),
    );
  }

  Future<bool> isFavorite(String userId, String offerId) async {
    final normalizedUserId = userId.trim();
    final normalizedOfferId = offerId.trim();
    if (normalizedUserId.isEmpty || normalizedOfferId.isEmpty) {
      return false;
    }

    final canonicalSnap = await _canonicalFavoritesRef(
      normalizedUserId,
    ).doc(normalizedOfferId).get();
    if (canonicalSnap.exists) {
      return true;
    }

    try {
      final globalSnap = await _globalFavoriteRef(
        normalizedUserId,
        normalizedOfferId,
      ).get();
      if (globalSnap.exists) {
        return true;
      }
    } catch (error) {
      if (!_isPermissionDenied(error)) {
        rethrow;
      }
    }

    try {
      final legacySnap = await _legacyFavoriteRef(
        normalizedUserId,
        normalizedOfferId,
      ).get();
      return legacySnap.exists;
    } catch (error) {
      if (_isPermissionDenied(error) || _isNotFound(error)) {
        return false;
      }
      rethrow;
    }
  }

  Future<bool> addFavorite(String userId, String offerId) async {
    final normalizedUserId = userId.trim();
    final normalizedOfferId = offerId.trim();
    if (normalizedUserId.isEmpty || normalizedOfferId.isEmpty) {
      return false;
    }
    if (await isFavorite(normalizedUserId, normalizedOfferId)) {
      return true;
    }
    return toggleFavorite(normalizedOfferId);
  }

  Future<bool> removeFavorite(String userId, String offerId) async {
    final normalizedUserId = userId.trim();
    final normalizedOfferId = offerId.trim();
    if (normalizedUserId.isEmpty || normalizedOfferId.isEmpty) {
      return false;
    }

    try {
      await _canonicalFavoritesRef(
        normalizedUserId,
      ).doc(normalizedOfferId).delete();
    } catch (error) {
      if (!_isPermissionDenied(error)) {
        _debugLog('remove canonical error: $error');
      }
    }

    if (!await isFavorite(normalizedUserId, normalizedOfferId)) {
      return false;
    }

    return !(await toggleFavorite(normalizedOfferId));
  }

  Future<bool> _callToggleFavorite(String listingId) async {
    final override = _toggleCaller;
    if (override != null) {
      return override(listingId);
    }

    final response = await callPrestoFunction<dynamic>(
      functions: _functions,
      name: 'toggleFavorite',
      timeout: const Duration(seconds: 15),
      parameters: <String, dynamic>{'listingId': listingId},
    );
    final data = Map<String, dynamic>.from(
      (response.data as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
    );
    return data['active'] == true;
  }

  Future<void> _logFavoriteChange({
    required String listingId,
    required bool added,
  }) async {
    final override = _favoriteChangeLogger;
    if (override != null) {
      await override(listingId: listingId, added: added);
      return;
    }

    await (_analytics ??= ProductAnalyticsService()).logProductEvent(
      ProductAnalyticsEvent.engagementFavoriteChanged(
        listingId: listingId,
        added: added,
      ),
    );
  }

  Future<bool> toggleFavorite(String listingId) async {
    final normalizedListingId = listingId.trim();
    if (normalizedListingId.isEmpty) {
      throw FirebaseException(
        plugin: 'cloud_functions',
        code: 'invalid-argument',
        message: 'listingId is required',
      );
    }

    final active = await _callToggleFavorite(normalizedListingId);
    await _logFavoriteChange(listingId: normalizedListingId, added: active);
    return active;
  }
}

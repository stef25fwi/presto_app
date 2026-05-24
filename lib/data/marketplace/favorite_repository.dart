import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../services/firebase_functions_region.dart';
import '../../services/product_analytics_service.dart';

class FavoriteListingLoadResult {
  const FavoriteListingLoadResult({
    required this.listingIds,
    required this.favoriteDates,
  });

  final List<String> listingIds;
  final Map<String, Timestamp?> favoriteDates;
}

class FavoriteRepository {
  FavoriteRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    ProductAnalyticsService? analytics,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
      _functions = functions ?? prestoFirebaseFunctions,
        _analytics = analytics ?? ProductAnalyticsService();

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final ProductAnalyticsService _analytics;

  bool _isPermissionDenied(Object error) {
    if (error is FirebaseException) {
      return error.code == 'permission-denied';
    }

    final message = error.toString().toLowerCase();
    return message.contains('permission-denied') ||
        message.contains('permission denied');
  }

  Stream<Set<String>> watchFavoriteListingIds(String userId) {
    return _firestore
        .collection('favorites')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(1000)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => (doc.data()['listingId'] ?? '').toString().trim())
              .where((value) => value.isNotEmpty)
              .toSet(),
        );
  }

  Future<FavoriteListingLoadResult> loadFavoriteListingIdsWithLegacyFallback(
    String userId,
  ) async {
    final favoriteSnap = await _firestore
        .collection('favorites')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(200)
        .get();

    final favoriteIds = favoriteSnap.docs
        .map((doc) => (doc.data()['listingId'] ?? '').toString().trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: true);

    final favoriteDates = <String, Timestamp?>{};
    for (final doc in favoriteSnap.docs) {
      final data = doc.data();
      final listingId = (data['listingId'] ?? '').toString().trim();
      if (listingId.isEmpty) continue;
      favoriteDates[listingId] =
          data['createdAt'] is Timestamp ? data['createdAt'] as Timestamp : null;
    }

    if (favoriteIds.isEmpty) {
      try {
        final legacyFavoriteSnap = await _firestore
            .collection('users')
            .doc(userId)
            .collection('favoriteOffers')
            .orderBy('createdAt', descending: true)
            .limit(200)
            .get();

        for (final doc in legacyFavoriteSnap.docs) {
          final data = doc.data();
          final listingId = (data['listingId'] ?? data['offerId'] ?? doc.id)
              .toString()
              .trim();
          if (listingId.isEmpty || favoriteDates.containsKey(listingId)) {
            continue;
          }
          favoriteIds.add(listingId);
          favoriteDates[listingId] = data['createdAt'] is Timestamp
              ? data['createdAt'] as Timestamp
              : data['addedAt'] is Timestamp
                  ? data['addedAt'] as Timestamp
                  : null;
        }
      } catch (error) {
        if (!_isPermissionDenied(error)) {
          rethrow;
        }
      }
    }

    return FavoriteListingLoadResult(
      listingIds: List<String>.unmodifiable(favoriteIds),
      favoriteDates: Map<String, Timestamp?>.unmodifiable(favoriteDates),
    );
  }

  Future<bool> toggleFavorite(String listingId) async {
    final callable = _functions.httpsCallable(
      'toggleFavorite',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
    );
    final response = await callable.call(<String, dynamic>{
      'listingId': listingId,
    });
    final data = Map<String, dynamic>.from(
      (response.data as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
    );
    final active = data['active'] == true;
    await _analytics.logEvent(
      active ? 'listing_favorite_added' : 'listing_favorite_removed',
      parameters: <String, Object?>{'listing_id': listingId},
    );
    return active;
  }
}
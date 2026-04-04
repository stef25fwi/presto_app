import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../services/firebase_functions_region.dart';
import '../../services/product_analytics_service.dart';

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

  Stream<Set<String>> watchFavoriteListingIds(String userId) {
    return _firestore
        .collection('favorites')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => (doc.data()['listingId'] ?? '').toString().trim())
              .where((value) => value.isNotEmpty)
              .toSet(),
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
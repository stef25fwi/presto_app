import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../models/marketplace_enums.dart';
import '../../models/marketplace_listing.dart';
import '../../models/marketplace_listing_draft.dart';
import '../../services/firebase_functions_region.dart';
import '../../services/product_analytics_service.dart';

class ListingRepository {
  ListingRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    ProductAnalyticsService? analytics,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? prestoFirebaseFunctions,
        _analytics = analytics ?? ProductAnalyticsService();

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final ProductAnalyticsService _analytics;

  CollectionReference<Map<String, dynamic>> get _drafts =>
      _firestore.collection('listingDrafts');

  CollectionReference<Map<String, dynamic>> get _listings =>
      _firestore.collection('listings');

  Future<String> createDraft(MarketplaceListingDraft draft) async {
    await _analytics
        .logEvent('listing_create_started', parameters: <String, Object?>{
      'category_id': draft.categoryId,
      'city_id': draft.cityId,
    });

    final payload = <String, dynamic>{
      'draft': draft.toFirestore(),
    };
    final response = await callPrestoFunction<dynamic>(
      functions: _functions,
      name: 'createListingDraft',
      timeout: const Duration(seconds: 30),
      parameters: payload,
    );
    final data = Map<String, dynamic>.from(
      (response.data as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
    );
    final draftId = (data['draftId'] ?? '').toString().trim();
    if (draftId.isEmpty) {
      throw StateError(
          'Le serveur n’a pas renvoyé d’identifiant de brouillon.');
    }

    await _analytics
        .logEvent('listing_create_completed', parameters: <String, Object?>{
      'draft_id': draftId,
      'category_id': draft.categoryId,
      'media_count': draft.media.length,
    });
    return draftId;
  }

  Future<void> updateDraft(
      String draftId, MarketplaceListingDraft draft) async {
    await _drafts.doc(draftId).set(<String, dynamic>{
      ...draft.toFirestore(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateDraftMedia({
    required String draftId,
    required List<ListingMediaInput> media,
  }) async {
    await callPrestoFunction<dynamic>(
      functions: _functions,
      name: 'updateListingDraftMedia',
      timeout: const Duration(seconds: 30),
      parameters: <String, dynamic>{
      'draftId': draftId,
      'media': media.map((e) => e.toMap()).toList(growable: false),
      },
    );
  }

  Future<ListingSubmissionResult> submitDraft({
    required String draftId,
    required String recaptchaToken,
  }) async {
    final response = await callPrestoFunction<dynamic>(
      functions: _functions,
      name: 'submitListingDraft',
      timeout: const Duration(seconds: 45),
      parameters: <String, dynamic>{
      'draftId': draftId,
      'recaptchaToken': recaptchaToken,
      },
    );
    final data = Map<String, dynamic>.from(
      (response.data as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
    );
    final result = ListingSubmissionResult.fromMap(data);
    await _analytics
        .logEvent('listing_submitted', parameters: <String, Object?>{
      'listing_id': result.listingId,
      'status': result.status.value,
      'moderation_status': result.moderationStatus.value,
      'risk_score': result.riskScore,
    });
    return result;
  }

  Stream<List<MarketplaceListing>> watchMyListings(String userId) {
    return _listings
        .where('ownerId', isEqualTo: userId)
        .orderBy('updatedAt', descending: true)
        .limit(500)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(MarketplaceListing.fromFirestore)
              .toList(growable: false),
        );
  }

  Stream<List<MarketplaceListing>> watchPublicListings({
    String? categoryId,
    String? cityId,
  }) {
    Query<Map<String, dynamic>> query = _listings
        .where('status', isEqualTo: 'active')
        .where('visibility', isEqualTo: 'public');
    if (categoryId != null && categoryId.trim().isNotEmpty) {
      query = query.where('categoryId', isEqualTo: categoryId.trim());
    }
    if (cityId != null && cityId.trim().isNotEmpty) {
      query = query.where('cityId', isEqualTo: cityId.trim());
    }

    return query.orderBy('createdAt', descending: true).snapshots().map(
          (snapshot) => snapshot.docs
              .map(MarketplaceListing.fromFirestore)
              .toList(growable: false),
        );
  }

  Future<List<MarketplaceListing>> fetchPublicListings({
    String? categoryId,
    String? cityId,
    int limit = 50,
  }) async {
    Query<Map<String, dynamic>> query = _listings
        .where('status', isEqualTo: 'active')
        .where('visibility', isEqualTo: 'public');
    if (categoryId != null && categoryId.trim().isNotEmpty) {
      query = query.where('categoryId', isEqualTo: categoryId.trim());
    }
    if (cityId != null && cityId.trim().isNotEmpty) {
      query = query.where('cityId', isEqualTo: cityId.trim());
    }

    final snapshot = await query
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs
        .map(MarketplaceListing.fromFirestore)
        .toList(growable: false);
  }

  Future<void> incrementView({
    required String listingId,
    required String viewerKey,
    String source = 'listing_detail',
  }) async {
    await callPrestoFunction<dynamic>(
      functions: _functions,
      name: 'incrementListingView',
      timeout: const Duration(seconds: 15),
      parameters: <String, dynamic>{
      'listingId': listingId,
      'viewerKey': viewerKey,
      'source': source,
      },
    );
  }
}

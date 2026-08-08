import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../core/cache/expiring_memory_cache.dart';
import '../../models/marketplace_enums.dart';
import '../../models/marketplace_listing.dart';
import '../../models/marketplace_listing_draft.dart';
import '../../services/firebase_functions_region.dart';
import '../../services/product_analytics_service.dart';
import '../../services/firestore_web_safe_reads.dart';
import '../firestore/firestore_schema.dart';

int normalizePublicListingsPageSize(int value) {
  if (value < 1) return 1;
  if (value > 100) return 100;
  return value;
}

String publicListingsFirstPageCacheKey({
  String? categoryId,
  String? cityId,
  required int limit,
}) {
  return <String>[
    categoryId?.trim().toLowerCase() ?? '',
    cityId?.trim().toLowerCase() ?? '',
    normalizePublicListingsPageSize(limit).toString(),
  ].join('|');
}

class PublicListingsPage {
  const PublicListingsPage({
    required this.items,
    required this.lastDocument,
    required this.hasMore,
  });

  final List<MarketplaceListing> items;
  final QueryDocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;
}

class ListingRepository {
  ListingRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    ProductAnalyticsService? analytics,
    ExpiringMemoryCache<String, PublicListingsPage>? publicListingsCache,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? prestoFirebaseFunctions,
        _analytics = analytics ?? ProductAnalyticsService(),
        _publicListingsCache = publicListingsCache ??
            ExpiringMemoryCache<String, PublicListingsPage>(
              defaultTtl: const Duration(seconds: 30),
              maximumEntries: 30,
            );

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final ProductAnalyticsService _analytics;
  final ExpiringMemoryCache<String, PublicListingsPage> _publicListingsCache;

  CollectionReference<Map<String, dynamic>> get _listings =>
      _firestore.collection(FirestoreCollections.listings);

  Future<String> createDraft(MarketplaceListingDraft draft) async {
    await _analytics.logEvent(
      'listing_create_started',
      parameters: <String, Object?>{
        'category_id': draft.categoryId,
        'city_id': draft.cityId,
      },
    );
    final payload = <String, dynamic>{'draft': draft.toFirestore()};
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
        'Le serveur n’a pas renvoyé d’identifiant de brouillon.',
      );
    }

    await _analytics.logEvent(
      'listing_create_completed',
      parameters: <String, Object?>{
        'draft_id': draftId,
        'category_id': draft.categoryId,
        'media_count': draft.media.length,
      },
    );
    return draftId;
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
    _publicListingsCache.clear();
    await _analytics.logEvent(
      'listing_submitted',
      parameters: <String, Object?>{
        'listing_id': result.listingId,
        'status': result.status.value,
        'moderation_status': result.moderationStatus.value,
        'risk_score': result.riskScore,
      },
    );
    return result;
  }

  Stream<List<MarketplaceListing>> watchMyListings(String userId) {
    return _listings
        .where(ListingFields.ownerId, isEqualTo: userId)
        .orderBy(ListingFields.updatedAt, descending: true)
        .limit(500)
        .webSafeSnapshots(debugKey: 'home.latestOffers')
        .map(
          (snapshot) => snapshot.docs
              .map(MarketplaceListing.fromFirestore)
              .toList(growable: false),
        );
  }

  Query<Map<String, dynamic>> _publicListingsQuery({
    String? categoryId,
    String? cityId,
  }) {
    Query<Map<String, dynamic>> query = _listings
        .where(ListingFields.status, isEqualTo: 'active')
        .where(ListingFields.visibility, isEqualTo: 'public');
    if (categoryId != null && categoryId.trim().isNotEmpty) {
      query = query.where(
        ListingFields.categoryId,
        isEqualTo: categoryId.trim(),
      );
    }
    if (cityId != null && cityId.trim().isNotEmpty) {
      query = query.where(ListingFields.cityId, isEqualTo: cityId.trim());
    }
    return query.orderBy(ListingFields.createdAt, descending: true);
  }

  Stream<List<MarketplaceListing>> watchPublicListings({
    String? categoryId,
    String? cityId,
    int limit = 100,
  }) {
    final pageSize = normalizePublicListingsPageSize(limit);
    return _publicListingsQuery(categoryId: categoryId, cityId: cityId)
        .limit(pageSize)
        .webSafeSnapshots(debugKey: 'home.latestOffers')
        .map(
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
    final page = await fetchPublicListingsPage(
      categoryId: categoryId,
      cityId: cityId,
      limit: limit,
    );
    return page.items;
  }

  Future<PublicListingsPage> fetchPublicListingsPage({
    String? categoryId,
    String? cityId,
    int limit = 50,
    QueryDocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) {
    final pageSize = normalizePublicListingsPageSize(limit);
    if (startAfter != null) {
      return _loadPublicListingsPage(
        categoryId: categoryId,
        cityId: cityId,
        pageSize: pageSize,
        startAfter: startAfter,
      );
    }

    final cacheKey = publicListingsFirstPageCacheKey(
      categoryId: categoryId,
      cityId: cityId,
      limit: pageSize,
    );
    return _publicListingsCache.getOrLoad(
      cacheKey,
      () => _loadPublicListingsPage(
        categoryId: categoryId,
        cityId: cityId,
        pageSize: pageSize,
      ),
    );
  }

  Future<void> preloadPublicListings({
    String? categoryId,
    String? cityId,
    int limit = 20,
  }) async {
    await fetchPublicListingsPage(
      categoryId: categoryId,
      cityId: cityId,
      limit: limit,
    );
  }

  void invalidatePublicListingsCache() => _publicListingsCache.clear();

  Future<PublicListingsPage> _loadPublicListingsPage({
    String? categoryId,
    String? cityId,
    required int pageSize,
    QueryDocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    Query<Map<String, dynamic>> query = _publicListingsQuery(
      categoryId: categoryId,
      cityId: cityId,
    );
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.limit(pageSize + 1).get();
    final hasMore = snapshot.docs.length > pageSize;
    final visibleDocs = hasMore
        ? snapshot.docs.take(pageSize).toList(growable: false)
        : snapshot.docs;

    return PublicListingsPage(
      items: visibleDocs
          .map(MarketplaceListing.fromFirestore)
          .toList(growable: false),
      lastDocument: visibleDocs.isEmpty ? null : visibleDocs.last,
      hasMore: hasMore,
    );
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

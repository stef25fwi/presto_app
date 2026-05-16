import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/public_offers_query_helpers.dart';
import 'marketplace_listing_ui_mapper.dart';

class ListingReadRepository {
  ListingReadRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _listings =>
      _firestore.collection(kListingsCollection);

  Future<DocumentSnapshot<Map<String, dynamic>>> getListingSnapshot(
    String listingId,
  ) {
    return _listings.doc(listingId.trim()).get();
  }

  Future<Map<String, dynamic>?> getListingData(String listingId) async {
    final snapshot = await getListingSnapshot(listingId);
    if (!snapshot.exists) return null;
    return snapshot.data();
  }

  Future<Map<String, dynamic>?> getPublicListingData(String listingId) async {
    final data = await getListingData(listingId);
    if (data == null || !isPublicActiveListingData(data)) return null;
    return data;
  }

  Future<Map<String, dynamic>?> getPublicOfferUiData(String listingId) async {
    final data = await getPublicListingData(listingId);
    if (data == null) return null;
    return mapMarketplaceListingToOfferUi(listingId: listingId, data: data);
  }

  List<Query<Map<String, dynamic>>> buildLatestPublicQueries({
    int limit = 200,
  }) {
    return buildLatestPublicListingsQueryVariants(
      firestore: _firestore,
      limit: limit,
    );
  }

  List<Query<Map<String, dynamic>>> buildBrowseQueries({
    int limit = 200,
    bool latestFirst = true,
    String? categoryId,
    String? cityId,
  }) {
    return buildMarketplaceListingsBrowseQueries(
      firestore: _firestore,
      limit: limit,
      latestFirst: latestFirst,
      categoryId: categoryId,
      cityId: cityId,
    );
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      loadLatestPublicListingDocs({
    int limit = 200,
    required String source,
  }) {
    return loadMergedPublicOfferQueryVariants(
      queries: buildLatestPublicQueries(limit: limit),
      source: source,
    );
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      loadBrowsePublicListingDocs({
    int limit = 200,
    bool latestFirst = true,
    String? categoryId,
    String? cityId,
    required String source,
  }) {
    return loadMergedPublicOfferQueryVariants(
      queries: buildBrowseQueries(
        limit: limit,
        latestFirst: latestFirst,
        categoryId: categoryId,
        cityId: cityId,
      ),
      source: source,
    );
  }

  Query<Map<String, dynamic>> publicListingsBaseQuery() {
    return _listings
        .where('status', isEqualTo: 'active')
        .where('visibility', isEqualTo: 'public');
  }
}

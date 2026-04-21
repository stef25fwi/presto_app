import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/app_check_state.dart';
import '../features/offers/public_offers_read_diagnostics.dart';
import 'package:flutter/material.dart';

const String kListingsCollection = 'listings';

enum PublicListingsBrowseFilterField {
  none,
  categoryId,
  cityId,
  cityCategoryKey,
}

/// Backfill legacy temporaire en lecture seule pour les annonces publiques.
const bool kEnableLegacyPublicOffersBackfill = false;


/// Collection legacy des annonces (ancienne architecture, en lecture seule).
const String kOffersCollection = 'offers';

PublicListingsBrowseFilterField pickPublicListingsBrowseFilterField({
  String? categoryId,
  String? cityId,
}) {
  final normalizedCityId = cityId?.trim() ?? '';
  final normalizedCategoryId = categoryId?.trim() ?? '';
  if (normalizedCityId.isNotEmpty && normalizedCategoryId.isNotEmpty) {
    return PublicListingsBrowseFilterField.cityCategoryKey;
  }
  if (normalizedCityId.isNotEmpty) {
    return PublicListingsBrowseFilterField.cityId;
  }

  if (normalizedCategoryId.isNotEmpty) {
    return PublicListingsBrowseFilterField.categoryId;
  }

  return PublicListingsBrowseFilterField.none;
}

Filter publicListingsFilter() {
  return Filter.and(
    Filter('status', isEqualTo: 'active'),
    Filter('visibility', isEqualTo: 'public'),
  );
}

Filter publicOffersFilter() {
  return Filter.or(
    Filter('visibility.isPublic', isEqualTo: true),
    Filter('status', isEqualTo: 'active'),
    Filter('status', isEqualTo: 'published'),
    Filter('isActive', isEqualTo: true),
    Filter('isPublished', isEqualTo: true),
  );
}

List<QueryDocumentSnapshot<Map<String, dynamic>>> mergeOfferDocsById(
  Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> primaryDocs,
  Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> secondaryDocs,
) {
  final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

  for (final doc in primaryDocs) {
    byId[doc.id] = doc;
  }
  for (final doc in secondaryDocs) {
    byId.putIfAbsent(doc.id, () => doc);
  }

  return byId.values.toList(growable: false);
}

Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
    loadLegacyPublicOffersBackfill({
  required Query<Map<String, dynamic>> query,
  required String source,
}) async {
  if (!kEnableLegacyPublicOffersBackfill) {
    return const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  }

  try {
    final snapshot = await query.get();
    if (kDebugMode) {
      debugPrint(
        '[PUBLIC_OFFERS][$source] legacy_backfill=${snapshot.docs.length}',
      );
    }
    return snapshot.docs;
  } catch (error, stackTrace) {
    logPublicOffersReadErrorWithAppCheck(source, error, stackTrace);
    return const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  }
}

String publicOffersAppCheckStateLabel() {
  if (!appCheckActivationAttempted) return 'not-attempted';
  if (appCheckActivationSucceeded) return 'ok';
  return 'failed';
}

PublicOffersReadIssue mergePublicOffersReadIssuesWithAppCheck({
  required String source,
  required PublicOffersReadIssue primary,
  required PublicOffersReadIssue secondary,
}) {
  return mergePublicOffersReadIssues(
    source: source,
    primary: primary,
    secondary: secondary,
    appCheckState: publicOffersAppCheckStateLabel(),
  );
}

PublicOffersReadIssue diagnosePublicOffersReadIssueWithAppCheck(
  Object error, {
  required String source,
}) {
  return diagnosePublicOffersReadIssue(
    error,
    source: source,
    appCheckState: publicOffersAppCheckStateLabel(),
  );
}

String friendlyPublicOffersReadErrorWithAppCheck(
  Object error, {
  bool debug = kDebugMode,
}) {
  return friendlyPublicOffersReadError(
    error,
    source: 'public_offers_read',
    appCheckState: publicOffersAppCheckStateLabel(),
    debug: debug,
  );
}

void logPublicOffersReadErrorWithAppCheck(
  String source,
  Object error, [
  StackTrace? stackTrace,
]) {
  logPublicOffersReadError(
    source,
    error,
    appCheckState: publicOffersAppCheckStateLabel(),
    stackTrace: stackTrace,
  );
}

Widget buildPublicOffersDebugCardWithAppCheck(
  Object error, {
  required String source,
}) {
  return buildPublicOffersDebugCard(
    error,
    source: source,
    appCheckState: publicOffersAppCheckStateLabel(),
  );
}

// ---------------------------------------------------------------------------
// Robust multi-variant query helpers (no OR filters)
// ---------------------------------------------------------------------------

/// Builds canonical public-listing queries against [kListingsCollection].
///
/// The current marketplace contract is `status == 'active' && visibility ==
/// 'public'` for every listing exposed anonymously.
List<Query<Map<String, dynamic>>> buildPublicListingsQueryVariants({
  FirebaseFirestore? firestore,
  int limit = 200,
}) {
  final fs = firestore ?? FirebaseFirestore.instance;
  final col = fs.collection(kListingsCollection);
  return <Query<Map<String, dynamic>>>[
    col
        .where('status', isEqualTo: 'active')
        .where('visibility', isEqualTo: 'public')
        .limit(limit),
  ];
}

/// Builds the same public-listing variants, but ordered by newest creation date.
///
/// This is required for screens that explicitly claim to show the latest
/// listings. Sorting client-side after a plain limit() only reorders a partial
/// sample and can miss newer documents that were never fetched.
List<Query<Map<String, dynamic>>> buildLatestPublicListingsQueryVariants({
  FirebaseFirestore? firestore,
  int limit = 200,
}) {
  final fs = firestore ?? FirebaseFirestore.instance;
  final col = fs.collection(kListingsCollection);
  return <Query<Map<String, dynamic>>>[
    col
        .where('status', isEqualTo: 'active')
        .where('visibility', isEqualTo: 'public')
        .orderBy('createdAt', descending: true)
        .limit(limit),
  ];
}

/// Builds queries against [kOffersCollection] that satisfy `isPublicOffer()`
/// for unauthenticated users. `status == 'active'` alone is rejected by
/// Firestore list-query rules (branch 1 also requires visibility == 'public').
/// It is removed and its data is already covered by `isActive == true` or
/// `visibility.isPublic == true`.
List<Query<Map<String, dynamic>>> buildPublicOffersQueryVariants({
  FirebaseFirestore? firestore,
  int limit = 200,
}) {
  final fs = firestore ?? FirebaseFirestore.instance;
  final col = fs.collection(kOffersCollection);
  return <Query<Map<String, dynamic>>>[
    col.where('status', isEqualTo: 'active').limit(limit),
    col.where('status', isEqualTo: 'published').limit(limit),
    col.where('isActive', isEqualTo: true).limit(limit),
    col.where('isPublished', isEqualTo: true).limit(limit),
    col.where('visibility', isEqualTo: 'public').limit(limit),
    col.where('visibility.isPublic', isEqualTo: true).limit(limit),
  ];
}

/// Builds the same public-offer variants, but ordered by newest creation date.
List<Query<Map<String, dynamic>>> buildLatestPublicOffersQueryVariants({
  FirebaseFirestore? firestore,
  int limit = 200,
}) {
  final fs = firestore ?? FirebaseFirestore.instance;
  final col = fs.collection(kOffersCollection);
  return <Query<Map<String, dynamic>>>[
    col
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .limit(limit),
    col
        .where('status', isEqualTo: 'published')
        .orderBy('createdAt', descending: true)
        .limit(limit),
    col
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(limit),
    col
        .where('isPublished', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(limit),
    col
        .where('visibility', isEqualTo: 'public')
        .orderBy('createdAt', descending: true)
        .limit(limit),
    col
        .where('visibility.isPublic', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(limit),
  ];
}

/// Builds the nominal modern marketplace browse query for listings.
///
/// This path targets the current production schema written by Cloud Functions:
/// active + public listings. It can safely apply indexed server-side filters
/// for category or city and keep newest-first ordering.
List<Query<Map<String, dynamic>>> buildMarketplaceListingsBrowseQueries({
  FirebaseFirestore? firestore,
  int limit = 200,
  bool latestFirst = true,
  String? categoryId,
  String? cityId,
}) {
  final fs = firestore ?? FirebaseFirestore.instance;
  final col = fs.collection(kListingsCollection);
  Query<Map<String, dynamic>> query = col
      .where('status', isEqualTo: 'active')
      .where('visibility', isEqualTo: 'public');

  switch (pickPublicListingsBrowseFilterField(
    categoryId: categoryId,
    cityId: cityId,
  )) {
    case PublicListingsBrowseFilterField.cityCategoryKey:
      query = query.where(
        'cityCategoryKey',
        isEqualTo: '${cityId!.trim()}_${categoryId!.trim()}',
      );
      break;
    case PublicListingsBrowseFilterField.cityId:
      query = query.where('cityId', isEqualTo: cityId!.trim());
      break;
    case PublicListingsBrowseFilterField.categoryId:
      query = query.where('categoryId', isEqualTo: categoryId!.trim());
      break;
    case PublicListingsBrowseFilterField.none:
      break;
  }

  if (latestFirst) {
    query = query.orderBy('createdAt', descending: true);
  }

  return <Query<Map<String, dynamic>>>[query.limit(limit)];
}

/// Executes every [queries] variant, merges results by document ID and returns
/// the deduplicated list. Individual query failures are logged but do not abort
/// the whole operation — only when *all* queries fail is the first error
/// rethrown.
Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
    loadMergedPublicOfferQueryVariants({
  required List<Query<Map<String, dynamic>>> queries,
  required String source,
}) async {
  final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
  Object? firstError;
  StackTrace? firstStackTrace;

  final results = await Future.wait(
    queries.asMap().entries.map((entry) async {
      final index = entry.key;
      final query = entry.value;
      try {
        final snapshot = await query.get();
        if (kDebugMode) {
          debugPrint(
            '[PUBLIC_OFFERS][$source#$index] docs=${snapshot.docs.length}',
          );
        }
        return (index: index, docs: snapshot.docs, error: null, stackTrace: null);
      } catch (error, stackTrace) {
        logPublicOffersReadErrorWithAppCheck(
          '$source#$index',
          error,
          stackTrace,
        );
        return (
          index: index,
          docs: const <QueryDocumentSnapshot<Map<String, dynamic>>>[],
          error: error,
          stackTrace: stackTrace,
        );
      }
    }),
  );

  for (final result in results) {
    if (result.error != null) {
      firstError ??= result.error;
      firstStackTrace ??= result.stackTrace;
      continue;
    }
    for (final doc in result.docs) {
      byId.putIfAbsent(doc.id, () => doc);
    }
  }

  if (byId.isEmpty && firstError != null) {
    Error.throwWithStackTrace(firstError, firstStackTrace!);
  }

  return byId.values.toList(growable: false);
}


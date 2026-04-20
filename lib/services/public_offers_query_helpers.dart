import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/app_check_state.dart';
import '../features/offers/public_offers_read_diagnostics.dart';
import 'package:flutter/material.dart';

const String kListingsCollection = 'listings';

/// Backfill legacy temporaire en lecture seule pour les annonces publiques.
const bool kEnableLegacyPublicOffersBackfill = true;


/// Collection legacy des annonces (ancienne architecture, en lecture seule).
const String kOffersCollection = 'offers';

Filter publicListingsFilter() {
  return Filter.or(
    // Format marketplace nominal
    Filter.and(
      Filter('status', isEqualTo: 'active'),
      Filter('visibility', isEqualTo: 'public'),
    ),
    // Variantes legacy couvertes par isPublicListingData() dans firestore.rules
    Filter('status', isEqualTo: 'published'),
    Filter('isPublished', isEqualTo: true),
    // Note: isActive==true et visibility.isPublic==true sont des formats
    // propres à la collection `offers` (legacy). Ils ne sont pas utilisés
    // dans `listings` et causaient des refus de query pour les anonymes
    // car non couverts par isPublicListingData() dans les règles Firestore.
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

/// Builds compound and single-field queries against [kListingsCollection].
///
/// Each query is guaranteed to satisfy the Firestore security rule
/// `isPublicListingData()` for unauthenticated users. Simple `status ==
/// 'active'` or `visibility == 'public'` alone cannot be statically verified
/// by Firestore rules for list operations, so they are replaced with compound
/// queries or nested-field variants that map 1-to-1 to a rule branch.
List<Query<Map<String, dynamic>>> buildPublicListingsQueryVariants({
  FirebaseFirestore? firestore,
  int limit = 200,
}) {
  final fs = firestore ?? FirebaseFirestore.instance;
  final col = fs.collection(kListingsCollection);
  return <Query<Map<String, dynamic>>>[
    // Branch 1: nominal marketplace format — both fields required by rule
    col.where('status', isEqualTo: 'active').where('visibility', isEqualTo: 'public').limit(limit),
    // Branch 2
    col.where('status', isEqualTo: 'published').limit(limit),
    // Branch 3
    col.where('isPublished', isEqualTo: true).limit(limit),
    // Branch 4
    col.where('isActive', isEqualTo: true).limit(limit),
    // Branch 5: visibility stored as nested object {isPublic: true}
    col.where('visibility.isPublic', isEqualTo: true).limit(limit),
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
    // Branch 5: visibility as nested object {isPublic: true}
    col.where('visibility.isPublic', isEqualTo: true).limit(limit),
    // Branch 2
    col.where('status', isEqualTo: 'published').limit(limit),
    // Branch 4
    col.where('isActive', isEqualTo: true).limit(limit),
    // Branch 3
    col.where('isPublished', isEqualTo: true).limit(limit),
  ];
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

  for (var i = 0; i < queries.length; i++) {
    try {
      final snapshot = await queries[i].get();
      for (final doc in snapshot.docs) {
        byId.putIfAbsent(doc.id, () => doc);
      }
      if (kDebugMode) {
        debugPrint(
          '[PUBLIC_OFFERS][$source#$i] docs=${snapshot.docs.length}',
        );
      }
    } catch (error, stackTrace) {
      firstError ??= error;
      firstStackTrace ??= stackTrace;
      logPublicOffersReadErrorWithAppCheck('$source#$i', error, stackTrace);
    }
  }

  if (byId.isEmpty && firstError != null) {
    Error.throwWithStackTrace(firstError, firstStackTrace!);
  }

  return byId.values.toList(growable: false);
}

/// Watches every [queries] variant via `snapshots()`, merges results by
/// document ID and emits deduplicated lists. Individual stream errors are
/// logged; the merged error is only forwarded when *all* variants are empty.
Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
    watchMergedPublicOfferQueryVariants({
  required List<Query<Map<String, dynamic>>> queries,
  required String source,
}) {
  return Stream.multi((controller) {
    final latestDocs =
        List<List<QueryDocumentSnapshot<Map<String, dynamic>>>>.filled(
      queries.length,
      const [],
    );
    final subscriptions = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
    Object? lastError;
    StackTrace? lastStackTrace;

    void _emit() {
      final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
      for (final docs in latestDocs) {
        for (final doc in docs) {
          byId.putIfAbsent(doc.id, () => doc);
        }
      }
      if (byId.isEmpty && lastError != null) {
        controller.addError(lastError!, lastStackTrace);
      } else {
        controller.add(byId.values.toList(growable: false));
      }
    }

    for (var i = 0; i < queries.length; i++) {
      final index = i;
      subscriptions.add(
        queries[i].snapshots().listen(
          (snapshot) {
            latestDocs[index] = snapshot.docs;
            if (kDebugMode) {
              debugPrint(
                '[PUBLIC_OFFERS][$source#$index] stream docs=${snapshot.docs.length}',
              );
            }
            _emit();
          },
          onError: (Object error, StackTrace stackTrace) {
            lastError = error;
            lastStackTrace = stackTrace;
            logPublicOffersReadErrorWithAppCheck(
              '$source#$index',
              error,
              stackTrace,
            );
            _emit();
          },
        ),
      );
    }

    controller.onCancel = () {
      for (final sub in subscriptions) {
        sub.cancel();
      }
    };
  });
}

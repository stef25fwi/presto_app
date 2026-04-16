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

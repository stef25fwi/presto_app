#!/usr/bin/env node

import fs from 'node:fs/promises';

async function read(path) {
  return fs.readFile(path, 'utf8');
}

async function write(path, content) {
  await fs.writeFile(path, content, 'utf8');
}

function replaceOnce(content, before, after, label) {
  if (after && content.includes(after)) return content;
  const count = content.split(before).length - 1;
  if (count !== 1) {
    throw new Error(`${label}: expected exactly one source occurrence, found ${count}`);
  }
  return content.replace(before, after);
}

function replaceRegexOnce(content, pattern, replacement, marker, label) {
  if (marker && content.includes(marker)) return content;
  const matches = [...content.matchAll(new RegExp(pattern.source, pattern.flags.includes('g') ? pattern.flags : `${pattern.flags}g`))];
  if (matches.length !== 1) {
    throw new Error(`${label}: expected exactly one regex match, found ${matches.length}`);
  }
  return content.replace(pattern, replacement);
}

async function patchFirestoreRules() {
  const path = 'firestore.rules';
  let content = await read(path);

  content = replaceOnce(
    content,
    "        'trustScore'\n      ];",
    "        'trustScore',\n        'accountStatus',\n        'emailVerified',\n        'phoneVerified',\n        'proVerified',\n        'siretVerified',\n        'subscriptionPlan',\n        'subscriptionStatus',\n        'subscriptionExpiresAt',\n        'subscriptionCancelAtPeriodEnd',\n        'stripeCustomerId',\n        'stripe_customer_id',\n        'stripeSubscriptionId',\n        'stripe_subscription_id',\n        'stripePriceId',\n        'stripe_price_id',\n        'stripeUpdatedAt',\n        'lastStripeEventId',\n        'deletionRequestedAt',\n        'deletionCompletedAt',\n        'deletedAt'\n      ];",
    'firestore protected user fields',
  );

  content = replaceOnce(
    content,
    '      allow delete: if isSignedIn() && userId == uid();',
    '      // La suppression de compte passe exclusivement par requestAccountDeletion.\n      allow delete: if false;',
    'firestore direct user delete',
  );

  await write(path, content);
}

async function patchPublicOffersQueries() {
  const path = 'lib/services/public_offers_query_helpers.dart';
  let content = await read(path);

  content = replaceOnce(
    content,
    "  final hasServerFilter = (categoryId?.trim().isNotEmpty ?? false) ||\n      (cityId?.trim().isNotEmpty ?? false);\n",
    '',
    'remove public query fallback flag',
  );

  content = replaceRegexOnce(
    content,
    /  final queries = <Query<Map<String, dynamic>>>\[\];\n  if \(latestFirst\) \{[\s\S]*?\n  return queries;\n\}/,
    "  // Une seule requête canonique indexée. Les anciens fallbacks parallèles\n  // multipliaient les lectures Firestore et pouvaient charger des résultats non\n  // filtrés côté client. Un index manquant doit désormais être détecté en CI.\n  final canonicalQuery = latestFirst\n      ? filteredQuery.orderBy('createdAt', descending: true)\n      : filteredQuery;\n  return <Query<Map<String, dynamic>>>[canonicalQuery.limit(limit)];\n}",
    'Une seule requête canonique indexée.',
    'canonical public listings query',
  );

  await write(path, content);
}

async function patchConsultOffersWarmLoad() {
  const path = 'lib/pages/consult_offers_page.dart';
  let content = await read(path);

  content = replaceOnce(
    content,
    '      unawaited(_primeOffersWarmCache(key));\n      _cachedOffersStream = _watchCombinedOffers().map((docs) {',
    '      // Le stream principal est l’unique chargement initial. Le warm load\n      // parallèle doublait les lectures Firestore pour le même écran.\n      _cachedOffersStream = _watchCombinedOffers().map((docs) {',
    'consult offers duplicate warm load',
  );

  await write(path, content);
}

async function patchAdminFetchOnce() {
  const path = 'lib/pages/admin_space_page.dart';
  let content = await read(path);

  const exactCollections = [
    "_usersStream = FirebaseFirestore.instance\n        .collection('users')\n        .where('createdAt', isGreaterThanOrEqualTo: startTimestamp)\n        .snapshots();",
    "_activeUsersStream = FirebaseFirestore.instance\n        .collection('users')\n        .where('lastSeenAt', isGreaterThanOrEqualTo: startTimestamp)\n        .snapshots();",
    "_listingsStream = FirebaseFirestore.instance\n        .collection('listings')\n        .where('createdAt', isGreaterThanOrEqualTo: startTimestamp)\n        .snapshots();",
    "_subscriptionsStream = FirebaseFirestore.instance\n        .collection('subscriptions')\n        .where('updatedAt', isGreaterThanOrEqualTo: startTimestamp)\n        .snapshots();",
    "_billingInvoicesStream = FirebaseFirestore.instance\n        .collection('billing_invoices')\n        .where('updatedAt', isGreaterThanOrEqualTo: startTimestamp)\n        .snapshots();",
    "_analyticsStream = FirebaseFirestore.instance\n        .collection('analyticsSnapshots')\n        .where('dateKey', isGreaterThanOrEqualTo: _dateKey(start))\n        .snapshots();",
  ];

  for (const block of exactCollections) {
    const replacement = block.replace('.snapshots();', '.get().asStream();');
    content = replaceOnce(content, block, replacement, `admin fetch once: ${block.split("collection('")[1]?.split("'")[0]}`);
  }

  content = content
    .replace(/(final logsStream =[\s\S]*?\.limit\(1000\)\n\s*)\.snapshots\(\);/, '$1.get().asStream();')
    .replace(/(final jobsStream =[\s\S]*?\.limit\(60\)\n\s*)\.snapshots\(\);/, '$1.get().asStream();')
    .replace(/(final ticketsStream =[\s\S]*?\.limit\(60\)\n\s*)\.snapshots\(\);/, '$1.get().asStream();');

  await write(path, content);
}

async function patchLayoutTest() {
  const path = 'test/toolbox_je_me_lance_etudiant_journey_test.dart';
  let content = await read(path);

  content = replaceRegexOnce(
    content,
    /      \/\/ La page contient des avertissements de layout préexistants[\s\S]*?      addTearDown\(\(\) => FlutterError\.onError = oldOnError\);\n\n/,
    "      // Les erreurs de layout ne sont plus neutralisées : tout overflow ou\n      // usage Material invalide doit faire échouer le test et bloquer la CI.\n\n",
    'Les erreurs de layout ne sont plus neutralisées',
    'layout error suppression',
  );

  await write(path, content);
}

async function patchMonitoringClient() {
  const path = 'lib/services/app_monitoring_service.dart';
  let content = await read(path);

  content = replaceOnce(
    content,
    "import 'package:cloud_firestore/cloud_firestore.dart';\nimport 'package:firebase_auth/firebase_auth.dart';\n",
    '',
    'monitoring direct firestore imports',
  );
  content = replaceOnce(
    content,
    "import 'package:flutter/widgets.dart';\n",
    "import 'package:flutter/widgets.dart';\n\nimport 'firebase_functions_region.dart';\n",
    'monitoring callable import',
  );
  content = replaceOnce(
    content,
    "  static const String collectionName = 'app_monitoring_events';\n\n",
    '',
    'monitoring collection constant',
  );

  content = replaceRegexOnce(
    content,
    /      final user = FirebaseAuth\.instance\.currentUser;\n\n      await FirebaseFirestore\.instance\.collection\(collectionName\)\.add\([\s\S]*?      \)\.timeout\(const Duration\(seconds: 5\)\);/,
    "      await callPrestoFunction<dynamic>(\n        functions: prestoFirebaseFunctions,\n        name: 'reportClientMonitoringEvent',\n        timeout: const Duration(seconds: 8),\n        area: 'monitoring',\n        parameters: <String, dynamic>{\n          'createdAtClient': DateTime.now().toUtc().toIso8601String(),\n          'level': level,\n          'scope': scope,\n          'action': action,\n          'message': _sanitizeValue(message),\n          'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,\n          'releaseMode': kReleaseMode,\n          'appBuild': appBuild,\n          'gitCommit': gitCommit,\n          'buildTime': buildTime,\n          'data': cleanedData,\n        },\n      );",
    "name: 'reportClientMonitoringEvent'",
    'monitoring callable write',
  );

  await write(path, content);
}

async function patchFunctionsExports() {
  const path = 'functions/src/index.ts';
  let content = await read(path);
  content = replaceOnce(
    content,
    'export { onNotificationCreated, onNotificationUpdated } from "./modules/notifications/triggers";\n',
    'export { onNotificationCreated, onNotificationUpdated } from "./modules/notifications/triggers";\nexport { reportClientMonitoringEvent } from "./modules/monitoring/callables";\n',
    'monitoring function export',
  );
  await write(path, content);
}

async function main() {
  await patchFirestoreRules();
  await patchPublicOffersQueries();
  await patchConsultOffersWarmLoad();
  await patchAdminFetchOnce();
  await patchLayoutTest();
  await patchMonitoringClient();
  await patchFunctionsExports();
  console.log('production hardening patches: OK');
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

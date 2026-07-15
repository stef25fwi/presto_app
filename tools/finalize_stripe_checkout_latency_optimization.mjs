#!/usr/bin/env node

import fs from 'node:fs/promises';

async function replaceOnce(path, before, after, label) {
  let content = await fs.readFile(path, 'utf8');
  if (content.includes(after)) return;
  const count = content.split(before).length - 1;
  if (count !== 1) {
    throw new Error(`${label}: expected exactly one occurrence, found ${count}`);
  }
  content = content.replace(before, after);
  await fs.writeFile(path, content, 'utf8');
}

await replaceOnce(
  'functions/src/index.ts',
  `  createSubscriptionCheckoutSession,
  getSubscriptionCheckoutStatus,
  createSubscriptionPortalSession,
} from "./modules/billing/callables";`,
  `  createSubscriptionCheckoutSession,
  getSubscriptionCheckoutStatus,
  createSubscriptionPortalSession,
  auditStripeCatalog,
} from "./modules/billing/callables";`,
  'audit Stripe export',
);

await replaceOnce(
  'functions/src/modules/billing/callables.test.ts',
  `  isBlockingSubscriptionStatus,
  normalizePlan,
`,
  `  isBlockingSubscriptionStatus,
  isCheckoutIntentFresh,
  normalizePlan,
`,
  'checkout freshness test import',
);

await replaceOnce(
  'functions/src/modules/billing/callables.test.ts',
  `test("bloque la création d'un second abonnement actif ou impayé", () => {
`,
  `test("réutilise une session Checkout encore suffisamment valide", () => {
  const now = 1_000_000;
  assert.equal(isCheckoutIntentFresh(now + 61_000, now), true);
  assert.equal(isCheckoutIntentFresh(now + 60_000, now), false);
  assert.equal(isCheckoutIntentFresh(now - 1, now), false);
});

test("bloque la création d'un second abonnement actif ou impayé", () => {
`,
  'checkout freshness test',
);

await replaceOnce(
  'functions/src/modules/billing/callables.test.ts',
  `  assert.equal(isBlockingSubscriptionStatus("canceled"), false);
`,
  `  assert.equal(isBlockingSubscriptionStatus("pastDue"), true);
  assert.equal(isBlockingSubscriptionStatus("canceled"), false);
`,
  'pastDue compatibility test',
);

const servicePath =
  'lib/features/subscriptions/subscription_checkout_service.dart';

const typedefBlock = `typedef SubscriptionStripeDataFetcher = Future<Map<String, dynamic>> Function(
  String callableName,
  Map<String, dynamic> payload,
);
typedef SubscriptionExternalLauncher = Future<bool> Function(Uri uri);
typedef SubscriptionClock = DateTime Function();
typedef SubscriptionReturnHistoryPreparer = void Function();

`;

let serviceSource = await fs.readFile(servicePath, 'utf8');
if (!serviceSource.includes('typedef SubscriptionStripeDataFetcher')) {
  const marker = 'enum SubscriptionActionType {';
  const count = serviceSource.split(marker).length - 1;
  if (count !== 1) {
    throw new Error(
      `Flutter checkout typedefs: expected exactly one enum marker, found ${count}`,
    );
  }
  serviceSource = serviceSource.replace(marker, `${typedefBlock}${marker}`);
  await fs.writeFile(servicePath, serviceSource, 'utf8');
}

await replaceOnce(
  servicePath,
  `class SubscriptionCheckoutService {
  const SubscriptionCheckoutService();

  static bool _openingStripe = false;`,
  `class SubscriptionCheckoutService {
  const SubscriptionCheckoutService({
    SubscriptionStripeDataFetcher? stripeDataFetcher,
    SubscriptionExternalLauncher? externalLauncher,
    SubscriptionClock? clock,
    SubscriptionReturnHistoryPreparer? returnHistoryPreparer,
  })  : _stripeDataFetcherOverride = stripeDataFetcher,
        _externalLauncherOverride = externalLauncher,
        _clockOverride = clock,
        _returnHistoryPreparerOverride = returnHistoryPreparer;

  final SubscriptionStripeDataFetcher? _stripeDataFetcherOverride;
  final SubscriptionExternalLauncher? _externalLauncherOverride;
  final SubscriptionClock? _clockOverride;
  final SubscriptionReturnHistoryPreparer? _returnHistoryPreparerOverride;

  static bool _openingStripe = false;`,
  'injectable Flutter checkout API',
);

await replaceOnce(
  servicePath,
  `  static final Map<String, Future<_CachedStripeDestination?>>
      _checkoutPrefetches = <String, Future<_CachedStripeDestination?>>{};

  Future<void> prefetchCheckout(`,
  `  static final Map<String, Future<_CachedStripeDestination?>>
      _checkoutPrefetches = <String, Future<_CachedStripeDestination?>>{};

  @visibleForTesting
  static void resetForTesting() {
    _openingStripe = false;
    _checkoutCache.clear();
    _checkoutPrefetches.clear();
  }

  DateTime get _now => (_clockOverride ?? DateTime.now).call();

  Future<void> prefetchCheckout(`,
  'Flutter checkout test reset and clock',
);

await replaceOnce(
  servicePath,
  `      prepareSubscriptionReturnHistory();

      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_self',
      );`,
  `      final returnHistoryPreparer = _returnHistoryPreparerOverride;
      if (returnHistoryPreparer != null) {
        returnHistoryPreparer();
      } else {
        prepareSubscriptionReturnHistory();
      }

      final launcher = _externalLauncherOverride;
      final opened = launcher != null
          ? await launcher(uri)
          : await launchUrl(
              uri,
              mode: LaunchMode.externalApplication,
              webOnlyWindowName: '_self',
            );`,
  'injectable Stripe return history and launcher',
);

await replaceOnce(
  servicePath,
  `    final fallbackMs = DateTime.now().millisecondsSinceEpoch +
        const Duration(minutes: 20).inMilliseconds;`,
  `    final fallbackMs = _now.millisecondsSinceEpoch +
        const Duration(minutes: 20).inMilliseconds;`,
  'injectable checkout fallback clock',
);

await replaceOnce(
  servicePath,
  `    final now = DateTime.now().millisecondsSinceEpoch;`,
  `    final now = _now.millisecondsSinceEpoch;`,
  'injectable checkout cache clock',
);

await replaceOnce(
  servicePath,
  `  Future<Map<String, dynamic>> _fetchStripeData(
    String callableName,
    Map<String, dynamic> payload,
  ) async {
    final callable = prestoFirebaseFunctions.httpsCallable(`,
  `  Future<Map<String, dynamic>> _fetchStripeData(
    String callableName,
    Map<String, dynamic> payload,
  ) async {
    final override = _stripeDataFetcherOverride;
    if (override != null) {
      return override(callableName, payload);
    }
    final callable = prestoFirebaseFunctions.httpsCallable(`,
  'injectable Stripe data fetcher',
);

const callables = await fs.readFile(
  'functions/src/modules/billing/callables.ts',
  'utf8',
);
const service = await fs.readFile(servicePath, 'utf8');
const widgets = await fs.readFile(
  'lib/features/subscriptions/subscription_widgets.dart',
  'utf8',
);

for (const [label, ok] of [
  ['warm checkout instance', callables.includes('minInstances: 1')],
  ['server checkout intent cache', callables.includes('stripe_checkout_intents')],
  ['catalog audit', callables.includes('export const auditStripeCatalog')],
  ['Flutter checkout prefetch', service.includes('Future<void> prefetchCheckout(')],
  [
    'Flutter checkout dependency injection',
    service.includes('typedef SubscriptionStripeDataFetcher'),
  ],
  [
    'Flutter return history guardrail',
    service.includes('prepareSubscriptionReturnHistory();'),
  ],
  ['subscription page prefetch', widgets.includes('_scheduleCheckoutPrefetch')],
]) {
  if (!ok) throw new Error(`missing generated optimization: ${label}`);
}

console.log('stripe checkout latency optimization finalized: OK');

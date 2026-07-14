#!/usr/bin/env node

import fs from 'node:fs/promises';

async function read(path) {
  return fs.readFile(path, 'utf8');
}

async function write(path, content) {
  await fs.writeFile(path, content, 'utf8');
}

function replaceOnce(content, before, after, label) {
  if (content.includes(after)) return content;
  const count = content.split(before).length - 1;
  if (count !== 1) {
    throw new Error(`${label}: expected exactly one occurrence, found ${count}`);
  }
  return content.replace(before, after);
}

function replaceRange(content, startMarker, endMarker, replacement, label) {
  if (content.includes(replacement)) return content;
  const start = content.indexOf(startMarker);
  const end = content.indexOf(endMarker, start + startMarker.length);
  if (start < 0 || end < 0 || end <= start) {
    throw new Error(`${label}: markers not found`);
  }
  return `${content.slice(0, start)}${replacement}${content.slice(end)}`;
}

const callablesPath = 'functions/src/modules/billing/callables.ts';
let callables = await read(callablesPath);

callables = replaceOnce(
  callables,
  'import { HttpsError, onCall } from "firebase-functions/v2/https";',
  'import { HttpsError, onCall } from "firebase-functions/v2/https";\nimport { onSchedule } from "firebase-functions/v2/scheduler";',
  'scheduler import',
);

callables = replaceOnce(
  callables,
  'const PRICE_CACHE_TTL_MS = 5 * 60 * 1000;',
  'const PRICE_CACHE_TTL_MS = 6 * 60 * 60 * 1000;\nconst CHECKOUT_SESSION_CACHE_SAFETY_MS = 60 * 1000;',
  'checkout cache constants',
);

callables = replaceOnce(
  callables,
  'export function isBlockingSubscriptionStatus(status: unknown): boolean {\n  return BLOCKING_SUBSCRIPTION_STATUSES.has(asString(status).toLowerCase());\n}',
  'export function isBlockingSubscriptionStatus(status: unknown): boolean {\n  const raw = asString(status).toLowerCase().replace(/[\\s-]/g, "_");\n  const normalized = raw === "pastdue" ? "past_due" : raw;\n  return BLOCKING_SUBSCRIPTION_STATUSES.has(normalized);\n}\n\nexport function isCheckoutIntentFresh(expiresAtMs: number, nowMs: number): boolean {\n  return Number.isFinite(expiresAtMs)\n    && expiresAtMs > nowMs + CHECKOUT_SESSION_CACHE_SAFETY_MS;\n}',
  'checkout freshness helper',
);

const fastCheckoutBlock = `function checkoutIntentDocumentId(userId: string, plan: SubscriptionPlan): string {
  return \`${'${userId}_${plan}'}\`;
}

function localCustomerId(userData: StripeObject): string {
  return asString(userData.stripeCustomerId || userData.stripe_customer_id);
}

function localSubscriptionId(userData: StripeObject): string {
  return asString(userData.stripeSubscriptionId || userData.stripe_subscription_id);
}

function localSubscriptionStatus(userData: StripeObject): string {
  return asString(userData.subscriptionStatus || userData.subscription_status);
}

function isMissingCustomerError(error: unknown): boolean {
  return error instanceof StripeApiError
    && (error.status === 404 || error.code === "resource_missing")
    && (!error.param || error.param === "customer");
}

async function clearInvalidCustomerReference(
  userRef: FirebaseFirestore.DocumentReference,
): Promise<void> {
  await userRef.set({
    stripeCustomerId: FieldValue.delete(),
    stripe_customer_id: FieldValue.delete(),
    stripeUpdatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
}

async function destinationForLocalSubscription(
  userData: StripeObject,
): Promise<{ url: string; destination: "portal" | "invoice"; subscriptionId: string } | null> {
  const status = localSubscriptionStatus(userData);
  if (!isBlockingSubscriptionStatus(status)) return null;

  let customerId = localCustomerId(userData);
  const subscriptionId = localSubscriptionId(userData);
  const normalizedStatus = status.toLowerCase().replace(/[\\s-]/g, "_");

  if (["incomplete", "past_due", "pastdue", "unpaid"].includes(normalizedStatus) && subscriptionId) {
    const subscription = await stripeRequest<StripeObject>(
      "GET",
      \`/v1/subscriptions/\${encodeURIComponent(subscriptionId)}\`,
    );
    customerId = customerId || asString(subscription.customer);
    if (!customerId) {
      throw new HttpsError(
        "failed-precondition",
        "Votre abonnement Stripe est en cours de synchronisation. Réessayez dans un instant.",
      );
    }
    return existingSubscriptionDestination(subscription, customerId);
  }

  if (!customerId && subscriptionId) {
    const subscription = await stripeRequest<StripeObject>(
      "GET",
      \`/v1/subscriptions/\${encodeURIComponent(subscriptionId)}\`,
    );
    customerId = asString(subscription.customer);
  }

  if (!customerId) {
    throw new HttpsError(
      "failed-precondition",
      "Votre abonnement Stripe est en cours de synchronisation. Réessayez dans un instant.",
    );
  }

  const portal = await createPortalUrl(customerId);
  const portalUrl = asString(portal.url);
  if (!portalUrl) {
    throw new HttpsError("internal", "Stripe n’a pas retourné d’URL de gestion");
  }
  return { url: portalUrl, destination: "portal", subscriptionId };
}

export const createSubscriptionCheckoutSession = onCall({
  region: PROJECT_REGION,
  enforceAppCheck: ENFORCE_APP_CHECK,
  secrets: STRIPE_CHECKOUT_SECRETS,
  timeoutSeconds: 30,
  minInstances: 1,
  maxInstances: 20,
  concurrency: 80,
  memory: "256MiB",
}, async (request) => {
  const startedAt = Date.now();
  try {
    const auth = request.auth;
    if (!auth?.uid) {
      throw new HttpsError("unauthenticated", "Connexion requise pour s’abonner");
    }

    const plan = normalizePlan(request.data?.plan ?? request.data?.subscriptionPlan);
    const priceId = priceIdForPlan(plan);
    const source = checkoutSource(request.data?.source);
    const userRef = db.collection(COLLECTIONS.users).doc(auth.uid);
    const intentRef = db
      .collection("stripe_checkout_intents")
      .doc(checkoutIntentDocumentId(auth.uid, plan));

    const [userSnap, intentSnap] = await Promise.all([
      userRef.get(),
      intentRef.get(),
    ]);
    const userData = (userSnap.data() || {}) as StripeObject;

    const existingDestination = await destinationForLocalSubscription(userData);
    if (existingDestination) {
      console.info("STRIPE_CHECKOUT_PERFORMANCE", {
        userId: auth.uid,
        plan,
        destination: existingDestination.destination,
        durationMs: Date.now() - startedAt,
        source,
      });
      return {
        ok: true,
        ...existingDestination,
        reason: "existing_subscription",
        serverDurationMs: Date.now() - startedAt,
      };
    }

    const intentData = (intentSnap.data() || {}) as StripeObject;
    const cachedUrl = asString(intentData.url);
    const cachedExpiresAtMs = asNumber(intentData.expires_at_ms);
    if (cachedUrl && isCheckoutIntentFresh(cachedExpiresAtMs, Date.now())) {
      console.info("STRIPE_CHECKOUT_PERFORMANCE", {
        userId: auth.uid,
        plan,
        destination: "checkout",
        cacheHit: true,
        durationMs: Date.now() - startedAt,
        source,
      });
      return {
        ok: true,
        url: cachedUrl,
        destination: "checkout",
        sessionId: asString(intentData.session_id),
        expiresAt: cachedExpiresAtMs,
        cacheHit: true,
        serverDurationMs: Date.now() - startedAt,
      };
    }

    const nowSeconds = Math.floor(Date.now() / 1000);
    const email = extractEmail(userData, asString(auth.token?.email));
    const customerId = localCustomerId(userData);
    const params: Record<string, string> = {
      mode: "subscription",
      client_reference_id: auth.uid,
      success_url: checkoutSuccessUrl(),
      cancel_url: cancelUrl(),
      locale: "fr",
      billing_address_collection: "auto",
      allow_promotion_codes: process.env.STRIPE_ALLOW_PROMOTION_CODES === "false" ? "false" : "true",
      "line_items[0][price]": priceId,
      "line_items[0][quantity]": "1",
      "metadata[firebaseUid]": auth.uid,
      "metadata[plan]": plan,
      "metadata[source]": source,
      "subscription_data[metadata][firebaseUid]": auth.uid,
      "subscription_data[metadata][plan]": plan,
      "subscription_data[metadata][source]": source,
      expires_at: String(nowSeconds + CHECKOUT_EXPIRATION_SECONDS),
    };

    if (customerId) {
      params.customer = customerId;
      params["customer_update[address]"] = "auto";
      params["customer_update[name]"] = "auto";
    } else if (email) {
      params.customer_email = email;
    }

    if (plan === "ilipro") {
      params["tax_id_collection[enabled]"] = "true";
    }
    if (process.env.STRIPE_AUTOMATIC_TAX_ENABLED === "true") {
      params["automatic_tax[enabled]"] = "true";
    }

    const bucket = checkoutIdempotencyBucket(Date.now());
    const checkoutKeyParts: Array<string | number> = [
      "checkout",
      stripeMode(),
      auth.uid,
      plan,
      bucket,
    ];

    let session: StripeSession;
    try {
      session = await stripeRequest<StripeSession>(
        "POST",
        "/v1/checkout/sessions",
        params,
        { idempotencyKey: idempotencyKey(checkoutKeyParts) },
      );
    } catch (error) {
      if (!customerId || !isMissingCustomerError(error)) throw error;

      await clearInvalidCustomerReference(userRef);
      delete params.customer;
      delete params["customer_update[address]"];
      delete params["customer_update[name]"];
      if (email) params.customer_email = email;

      session = await stripeRequest<StripeSession>(
        "POST",
        "/v1/checkout/sessions",
        params,
        {
          idempotencyKey: idempotencyKey([
            ...checkoutKeyParts,
            "customer-recovery",
          ]),
        },
      );
    }

    const url = asString(session.url);
    const sessionId = asString(session.id);
    if (!url || !sessionId) {
      throw new HttpsError("internal", "Stripe n’a pas retourné de session de paiement valide");
    }

    const expiresAtMs = asNumber(session.expires_at) > 0
      ? asNumber(session.expires_at) * 1000
      : Date.now() + CHECKOUT_EXPIRATION_SECONDS * 1000;

    const batch = db.batch();
    batch.set(intentRef, {
      user_id: auth.uid,
      plan,
      price_id: priceId,
      session_id: sessionId,
      url,
      expires_at_ms: expiresAtMs,
      stripe_mode: stripeMode(),
      source,
      updated_at: FieldValue.serverTimestamp(),
      created_at: FieldValue.serverTimestamp(),
    }, { merge: true });
    batch.set(db.collection("stripe_checkout_sessions").doc(sessionId), {
      user_id: auth.uid,
      customer_id: customerId || null,
      plan,
      price_id: priceId,
      source,
      destination: "checkout",
      stripe_mode: stripeMode(),
      stripe_session_status: asString(session.status || "open"),
      expires_at: expiresAtMs,
      created_at: FieldValue.serverTimestamp(),
      updated_at: FieldValue.serverTimestamp(),
    }, { merge: true });
    await batch.commit();

    console.info("STRIPE_CHECKOUT_PERFORMANCE", {
      userId: auth.uid,
      plan,
      destination: "checkout",
      cacheHit: false,
      customerReused: Boolean(customerId),
      durationMs: Date.now() - startedAt,
      source,
    });

    return {
      ok: true,
      url,
      destination: "checkout",
      sessionId,
      expiresAt: expiresAtMs,
      cacheHit: false,
      serverDurationMs: Date.now() - startedAt,
    };
  } catch (error) {
    throw mapStripeError(error);
  }
});

export const auditStripeCatalog = onSchedule({
  region: PROJECT_REGION,
  schedule: "every 6 hours",
  timeZone: "UTC",
  secrets: STRIPE_CHECKOUT_SECRETS,
  timeoutSeconds: 60,
  memory: "256MiB",
}, async () => {
  const startedAt = Date.now();
  try {
    validatedPriceCache.clear();
    const plusPriceId = priceIdForPlan("ilipresto_plus");
    const proPriceId = priceIdForPlan("ilipro");
    await Promise.all([
      validatePriceForPlan("ilipresto_plus", plusPriceId),
      validatePriceForPlan("ilipro", proPriceId),
    ]);
    await db.collection("stripe_runtime_health").doc("catalog").set({
      ok: true,
      stripe_mode: stripeMode(),
      ilipresto_plus_price_id: plusPriceId,
      ilipro_price_id: proPriceId,
      checked_at: FieldValue.serverTimestamp(),
      duration_ms: Date.now() - startedAt,
      error: FieldValue.delete(),
    }, { merge: true });
  } catch (error) {
    await db.collection("stripe_runtime_health").doc("catalog").set({
      ok: false,
      stripe_mode: stripeMode(),
      checked_at: FieldValue.serverTimestamp(),
      duration_ms: Date.now() - startedAt,
      error: error instanceof Error ? error.message : String(error),
    }, { merge: true });
    throw error;
  }
});

`;

callables = replaceRange(
  callables,
  'export const createSubscriptionCheckoutSession = onCall({',
  'export const getSubscriptionCheckoutStatus = onCall({',
  fastCheckoutBlock,
  'fast checkout callable',
);

await write(callablesPath, callables);

const servicePath = 'lib/features/subscriptions/subscription_checkout_service.dart';
let service = await read(servicePath);
const optimizedServiceClass = `class SubscriptionCheckoutService {
  const SubscriptionCheckoutService();

  static bool _openingStripe = false;
  static final Map<String, _CachedStripeDestination> _checkoutCache =
      <String, _CachedStripeDestination>{};
  static final Map<String, Future<_CachedStripeDestination?>>
      _checkoutPrefetches = <String, Future<_CachedStripeDestination?>>{};

  Future<void> prefetchCheckout(
    SubscriptionPlan plan, {
    String source = 'subscription_prefetch',
  }) async {
    if (plan == SubscriptionPlan.free) return;
    final key = subscriptionPlanKey(plan);
    if (_readCachedCheckout(key) != null ||
        _checkoutPrefetches.containsKey(key)) {
      return;
    }

    final future = _fetchCheckoutDestination(
      key,
      source: source,
      swallowErrors: true,
    );
    _checkoutPrefetches[key] = future;
    try {
      final destination = await future;
      if (destination != null) _checkoutCache[key] = destination;
    } finally {
      _checkoutPrefetches.remove(key);
    }
  }

  Future<void> handleAction(
    BuildContext context,
    SubscriptionActionRequest request,
  ) async {
    if (_openingStripe) {
      return _showSnackBar(
        context,
        'Ouverture de Stripe déjà en cours…',
      );
    }

    switch (request.action) {
      case SubscriptionActionType.checkout:
        final plan = request.plan;
        if (plan == null || plan == SubscriptionPlan.free) {
          return _showSnackBar(
            context,
            'Cette formule ne nécessite pas de paiement.',
          );
        }
        return _openStripeUrl(
          context,
          callableName: 'createSubscriptionCheckoutSession',
          payload: <String, dynamic>{
            'plan': subscriptionPlanKey(plan),
            'subscriptionPlan': subscriptionPlanKey(plan),
            'source': request.source,
          },
          unavailableMessage: request.stripeEnabled
              ? 'Impossible de lancer Stripe pour le moment.'
              : 'Stripe n’est pas activé dans la configuration abonnement.',
        );
      case SubscriptionActionType.manage:
        return _openStripeUrl(
          context,
          callableName: 'createSubscriptionPortalSession',
          payload: <String, dynamic>{
            'source': request.source,
          },
          unavailableMessage: request.stripeEnabled
              ? 'Impossible d’ouvrir la gestion Stripe pour le moment.'
              : 'La gestion Stripe n’est pas activée dans la configuration abonnement.',
        );
      case SubscriptionActionType.notify:
        return _showSnackBar(
          context,
          'Vous serez informé lorsque cette formule sera disponible.',
        );
    }
  }

  Future<void> _openStripeUrl(
    BuildContext context, {
    required String callableName,
    required Map<String, dynamic> payload,
    required String unavailableMessage,
  }) async {
    FirebaseFunctionsException? firebaseError;
    Object? genericError;

    _openingStripe = true;
    try {
      final checkoutKey = callableName == 'createSubscriptionCheckoutSession'
          ? (payload['plan'] ?? '').toString().trim()
          : '';

      _CachedStripeDestination? destination;
      if (checkoutKey.isNotEmpty) {
        destination = _readCachedCheckout(checkoutKey);
        final pending = _checkoutPrefetches[checkoutKey];
        if (destination == null && pending != null) {
          destination = await pending;
        }
      }

      if (destination == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                duration: Duration(seconds: 8),
                content: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text('Ouverture sécurisée de Stripe…'),
                  ],
                ),
              ),
            );
        }
        final data = await _fetchStripeData(callableName, payload);
        final rawUrl = _extractUrl(data);
        destination = _destinationFromResponse(data, rawUrl);
        if (checkoutKey.isNotEmpty) _checkoutCache[checkoutKey] = destination;
      }

      final uri = Uri.tryParse(destination.url.trim());
      if (uri == null || !_isTrustedStripeUri(uri)) {
        throw const SubscriptionCheckoutException(
          'L’adresse de paiement retournée n’est pas une URL Stripe sécurisée.',
        );
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
      prepareSubscriptionReturnHistory();

      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_self',
      );
      if (!opened) {
        throw const SubscriptionCheckoutException(
          'Impossible d’ouvrir la page Stripe.',
        );
      }
      return;
    } on FirebaseFunctionsException catch (error) {
      firebaseError = error;
    } catch (error) {
      genericError = error;
    } finally {
      _openingStripe = false;
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    await _showSnackBar(
      context,
      _messageForFailure(
        firebaseError: firebaseError,
        genericError: genericError,
        fallback: unavailableMessage,
      ),
    );
  }

  Future<_CachedStripeDestination?> _fetchCheckoutDestination(
    String planKey, {
    required String source,
    required bool swallowErrors,
  }) async {
    try {
      final data = await _fetchStripeData(
        'createSubscriptionCheckoutSession',
        <String, dynamic>{
          'plan': planKey,
          'subscriptionPlan': planKey,
          'source': source,
        },
      );
      final rawUrl = _extractUrl(data);
      final uri = Uri.tryParse(rawUrl.trim());
      if (uri == null || !_isTrustedStripeUri(uri)) {
        throw const SubscriptionCheckoutException(
          'L’adresse de paiement retournée n’est pas une URL Stripe sécurisée.',
        );
      }
      return _destinationFromResponse(data, rawUrl);
    } catch (_) {
      if (swallowErrors) return null;
      rethrow;
    }
  }

  _CachedStripeDestination _destinationFromResponse(
    Map<String, dynamic> data,
    String url,
  ) {
    final rawExpiresAt = data['expiresAt'] ?? data['expires_at'];
    final parsed = rawExpiresAt is num
        ? rawExpiresAt.toInt()
        : int.tryParse((rawExpiresAt ?? '').toString()) ?? 0;
    final expiresAtMs =
        parsed > 0 && parsed < 1000000000000 ? parsed * 1000 : parsed;
    final fallbackMs = DateTime.now().millisecondsSinceEpoch +
        const Duration(minutes: 20).inMilliseconds;
    return _CachedStripeDestination(
      url: url,
      expiresAtMs: expiresAtMs > 0 ? expiresAtMs : fallbackMs,
    );
  }

  _CachedStripeDestination? _readCachedCheckout(String key) {
    final cached = _checkoutCache[key];
    if (cached == null) return null;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (cached.expiresAtMs <=
        now + const Duration(seconds: 20).inMilliseconds) {
      _checkoutCache.remove(key);
      return null;
    }
    return cached;
  }

  bool _isTrustedStripeUri(Uri uri) {
    if (uri.scheme.toLowerCase() != 'https') return false;
    final host = uri.host.toLowerCase();
    return host == 'stripe.com' || host.endsWith('.stripe.com');
  }

  Future<Map<String, dynamic>> _fetchStripeData(
    String callableName,
    Map<String, dynamic> payload,
  ) async {
    final callable = prestoFirebaseFunctions.httpsCallable(
      callableName,
      options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
    );
    final response = await callable.call<Map<dynamic, dynamic>>(payload);
    return Map<String, dynamic>.from(response.data);
  }

  String _extractUrl(Map<String, dynamic> data) {
    for (final key in const [
      'url',
      'checkoutUrl',
      'paymentUrl',
      'sessionUrl',
      'portalUrl',
    ]) {
      final value = (data[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }

    final session = data['session'];
    if (session is Map) {
      final value = (session['url'] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }

    throw const SubscriptionCheckoutException('URL Stripe introuvable.');
  }

  String _messageForFailure({
    required FirebaseFunctionsException? firebaseError,
    required Object? genericError,
    required String fallback,
  }) {
    if (firebaseError != null) {
      final message = firebaseError.message?.trim();
      if (message != null && message.isNotEmpty) return message;
      switch (firebaseError.code) {
        case 'unauthenticated':
          return 'Connectez-vous pour gérer votre abonnement.';
        case 'permission-denied':
          return 'Cette opération Stripe n’est pas autorisée.';
        case 'resource-exhausted':
          return 'Stripe reçoit trop de demandes. Réessayez dans un instant.';
        case 'unavailable':
          return 'Stripe est temporairement indisponible.';
      }
    }
    if (genericError is SubscriptionCheckoutException) {
      return genericError.message;
    }
    return fallback;
  }

  Future<void> _showSnackBar(BuildContext context, String message) async {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CachedStripeDestination {
  final String url;
  final int expiresAtMs;

  const _CachedStripeDestination({
    required this.url,
    required this.expiresAtMs,
  });
}

`;

service = replaceRange(
  service,
  'class SubscriptionCheckoutService {',
  'class SubscriptionCheckoutException implements Exception {',
  optimizedServiceClass,
  'optimized Flutter checkout service',
);
await write(servicePath, service);

const placeholdersPath = 'lib/features/subscriptions/subscription_action_placeholders.dart';
let placeholders = await read(placeholdersPath);
placeholders = replaceOnce(
  placeholders,
  `Future<void> openSubscriptionManagement(
`,
  `Future<void> prefetchSubscriptionCheckout(
  String plan, {
  bool stripeEnabled = false,
  String source = 'subscription_prefetch',
}) async {
  if (!stripeEnabled) return;
  await _checkoutService.prefetchCheckout(
    subscriptionPlanFromKey(plan),
    source: source,
  );
}

Future<void> openSubscriptionManagement(
`,
  'subscription prefetch helper',
);
await write(placeholdersPath, placeholders);

const widgetsPath = 'lib/features/subscriptions/subscription_widgets.dart';
let widgets = await read(widgetsPath);
widgets = replaceOnce(
  widgets,
  `class _SubscriptionDetailsPageState extends State<SubscriptionDetailsPage> {
  OfferAudience _audience = OfferAudience.particuliers;

  @override
`,
  `class _SubscriptionDetailsPageState extends State<SubscriptionDetailsPage> {
  OfferAudience _audience = OfferAudience.particuliers;
  final Set<SubscriptionPlan> _prefetchScheduled = <SubscriptionPlan>{};

  void _scheduleCheckoutPrefetch({
    required SubscriptionAppConfig config,
    required AppUserSubscriptionState userState,
  }) {
    final targetPlan = _audience == OfferAudience.particuliers
        ? SubscriptionPlan.iliprestoPlus
        : SubscriptionPlan.ilipro;
    if (!config.stripeEnabled ||
        targetPlan == userState.plan ||
        !_prefetchScheduled.add(targetPlan)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        prefetchSubscriptionCheckout(
          subscriptionPlanKey(targetPlan),
          stripeEnabled: true,
          source: 'account_subscription_details_prefetch',
        ),
      );
    });
  }

  @override
`,
  'details prefetch state',
);
widgets = replaceOnce(
  widgets,
  `              final userState = AppUserSubscriptionState.fromMap(
                userSnapshot.data?.data(),
              );
              return SafeArea(
`,
  `              final userState = AppUserSubscriptionState.fromMap(
                userSnapshot.data?.data(),
              );
              _scheduleCheckoutPrefetch(config: config, userState: userState);
              return SafeArea(
`,
  'details prefetch trigger',
);
widgets = replaceOnce(
  widgets,
  `            final userState = AppUserSubscriptionState.fromMap(
              userSnapshot.data?.data(),
            );
            return Container(
`,
  `            final userState = AppUserSubscriptionState.fromMap(
              userSnapshot.data?.data(),
            );
            if (config.stripeEnabled &&
                userState.plan == SubscriptionPlan.free) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                unawaited(
                  prefetchSubscriptionCheckout(
                    subscriptionPlanKey(SubscriptionPlan.iliprestoPlus),
                    stripeEnabled: true,
                    source: 'account_subscription_overview_prefetch',
                  ),
                );
              });
            }
            return Container(
`,
  'overview prefetch trigger',
);
await write(widgetsPath, widgets);

const indexPath = 'functions/src/index.ts';
let index = await read(indexPath);
index = replaceOnce(
  index,
  `  createSubscriptionCheckoutSession,
  createSubscriptionPortalSession,
} from "./modules/billing/callables";`,
  `  createSubscriptionCheckoutSession,
  createSubscriptionPortalSession,
  auditStripeCatalog,
} from "./modules/billing/callables";`,
  'audit export',
);
await write(indexPath, index);

const testsPath = 'functions/src/modules/billing/callables.test.ts';
let tests = await read(testsPath);
tests = replaceOnce(
  tests,
  `  isBlockingSubscriptionStatus,
  normalizePlan,
`,
  `  isBlockingSubscriptionStatus,
  isCheckoutIntentFresh,
  normalizePlan,
`,
  'checkout freshness test import',
);
tests = replaceOnce(
  tests,
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
tests = replaceOnce(
  tests,
  `  assert.equal(isBlockingSubscriptionStatus("canceled"), false);
`,
  `  assert.equal(isBlockingSubscriptionStatus("pastDue"), true);
  assert.equal(isBlockingSubscriptionStatus("canceled"), false);
`,
  'pastDue compatibility test',
);
await write(testsPath, tests);

console.log('stripe checkout latency optimization: OK');

import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/core/cache/expiring_memory_cache.dart';
import 'package:presto_app/data/marketplace/listing_repository.dart';
import 'package:presto_app/models/marketplace_enums.dart';
import 'package:presto_app/models/marketplace_listing_draft.dart';
import 'package:presto_app/services/product_analytics_service.dart';

typedef _CallableRecord = ({
  String name,
  Duration? timeout,
  dynamic parameters,
});

typedef _AnalyticsRecord = ({
  String name,
  Map<String, Object?> parameters,
});

class _FakeFunctions implements FirebaseFunctions {
  final Map<String, dynamic> responses = <String, dynamic>{};
  final List<_CallableRecord> calls = <_CallableRecord>[];

  @override
  HttpsCallable httpsCallable(
    String name, {
    HttpsCallableOptions? options,
  }) {
    return _FakeCallable(
      owner: this,
      name: name,
      timeout: options?.timeout,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCallable implements HttpsCallable {
  const _FakeCallable({
    required this.owner,
    required this.name,
    required this.timeout,
  });

  final _FakeFunctions owner;
  final String name;
  final Duration? timeout;

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    owner.calls.add((
      name: name,
      timeout: timeout,
      parameters: parameters,
    ));
    return _FakeCallableResult<T>(owner.responses[name] as T);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCallableResult<T> implements HttpsCallableResult<T> {
  const _FakeCallableResult(this.data);

  @override
  final T data;
}

class _FakePerformance implements FirebasePerformance {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAnalytics extends ProductAnalyticsService {
  _FakeAnalytics() : super(performance: _FakePerformance());

  final List<_AnalyticsRecord> events = <_AnalyticsRecord>[];

  @override
  Future<void> logEvent(
    String name, {
    Map<String, Object?> parameters = const <String, Object?>{},
  }) async {
    events.add((
      name: name,
      parameters: Map<String, Object?>.from(parameters),
    ));
  }
}

class _TrackingCache
    extends ExpiringMemoryCache<String, PublicListingsPage> {
  _TrackingCache()
      : super(
          defaultTtl: const Duration(seconds: 30),
          maximumEntries: 4,
        );

  int clearCalls = 0;

  @override
  void clear() {
    clearCalls += 1;
    super.clear();
  }
}

const _media = ListingMediaInput(
  storagePath: 'listings/raw/photo.webp',
  downloadUrl: 'https://cdn.test/photo.webp',
  thumbnailUrl: 'https://cdn.test/thumb.webp',
  width: 1200,
  height: 800,
  mimeType: 'image/webp',
  sizeBytes: 4096,
);

MarketplaceListingDraft _draft() {
  return const MarketplaceListingDraft(
    ownerId: 'owner-1',
    title: ' Besoin de jardinage ',
    description: ' Description suffisamment détaillée pour le test. ',
    price: 45,
    categoryId: 'jardinage',
    cityId: '97122_baie-mahault',
    media: <ListingMediaInput>[_media],
    phone: '0690123456',
    budgetType: 'fixed',
    missionDelay: 'Cette semaine',
    isUrgent: true,
    category: 'Jardinage',
    city: 'Baie-Mahault',
    postalCode: '97122',
  );
}

void main() {
  late _FakeFunctions functions;
  late _FakeAnalytics analytics;
  late _TrackingCache cache;
  late ListingRepository repository;

  setUp(() {
    functions = _FakeFunctions();
    analytics = _FakeAnalytics();
    cache = _TrackingCache();
    repository = ListingRepository(
      firestore: FakeFirebaseFirestore(),
      functions: functions,
      analytics: analytics,
      publicListingsCache: cache,
    );
  });

  test('crée un brouillon via le callable et journalise le parcours', () async {
    functions.responses['createListingDraft'] = <String, dynamic>{
      'draftId': ' draft-1 ',
    };

    final draftId = await repository.createDraft(_draft());

    expect(draftId, 'draft-1');
    expect(functions.calls, hasLength(1));
    final call = functions.calls.single;
    expect(call.name, 'createListingDraft');
    expect(call.timeout, const Duration(seconds: 30));
    final payload = Map<String, dynamic>.from(call.parameters as Map);
    final draftPayload = Map<String, dynamic>.from(payload['draft'] as Map);
    expect(draftPayload['ownerId'], 'owner-1');
    expect(draftPayload['title'], 'Besoin de jardinage');
    expect(draftPayload['categoryId'], 'jardinage');
    expect(draftPayload['cityId'], '97122_baie-mahault');
    expect((draftPayload['media'] as List), hasLength(1));

    expect(
      analytics.events.map((event) => event.name),
      <String>['listing_create_started', 'listing_create_completed'],
    );
    expect(analytics.events.first.parameters['category_id'], 'jardinage');
    expect(analytics.events.last.parameters['draft_id'], 'draft-1');
    expect(analytics.events.last.parameters['media_count'], 1);
  });

  test('refuse une réponse de création sans identifiant de brouillon', () async {
    functions.responses['createListingDraft'] = <String, dynamic>{};

    await expectLater(
      repository.createDraft(_draft()),
      throwsA(isA<StateError>()),
    );

    expect(
      analytics.events.map((event) => event.name),
      <String>['listing_create_started'],
    );
  });

  test('met à jour les médias avec le payload attendu', () async {
    functions.responses['updateListingDraftMedia'] = <String, dynamic>{
      'ok': true,
    };

    await repository.updateDraftMedia(
      draftId: 'draft-1',
      media: const <ListingMediaInput>[_media],
    );

    final call = functions.calls.single;
    expect(call.name, 'updateListingDraftMedia');
    expect(call.timeout, const Duration(seconds: 30));
    expect(call.parameters, <String, dynamic>{
      'draftId': 'draft-1',
      'media': <Map<String, dynamic>>[_media.toMap()],
    });
  });

  test('soumet le brouillon, vide le cache et journalise le résultat', () async {
    functions.responses['submitListingDraft'] = <String, dynamic>{
      'listingId': 'listing-1',
      'status': 'active',
      'moderationStatus': 'approved',
      'visibility': 'public',
      'riskScore': 7,
      'thumbnailUrl': 'https://cdn.test/thumb.webp',
      'media': <Map<String, dynamic>>[_media.toMap()],
    };

    final result = await repository.submitDraft(
      draftId: 'draft-1',
      recaptchaToken: 'recaptcha-token',
    );

    expect(result.listingId, 'listing-1');
    expect(result.status, ListingStatus.active);
    expect(result.moderationStatus, ModerationStatus.approved);
    expect(result.visibility, ListingVisibility.public);
    expect(result.riskScore, 7);
    expect(cache.clearCalls, 1);

    final call = functions.calls.single;
    expect(call.name, 'submitListingDraft');
    expect(call.timeout, const Duration(seconds: 45));
    expect(call.parameters, <String, dynamic>{
      'draftId': 'draft-1',
      'recaptchaToken': 'recaptcha-token',
    });

    expect(analytics.events, hasLength(1));
    expect(analytics.events.single.name, 'listing_submitted');
    expect(analytics.events.single.parameters, <String, Object?>{
      'listing_id': 'listing-1',
      'status': 'active',
      'moderation_status': 'approved',
      'risk_score': 7,
    });
  });

  test('incrémente la vue avec le contexte fourni', () async {
    functions.responses['incrementListingView'] = <String, dynamic>{'ok': true};

    await repository.incrementView(
      listingId: 'listing-1',
      viewerKey: 'viewer-session-1',
      source: 'coverage-test',
    );

    final call = functions.calls.single;
    expect(call.name, 'incrementListingView');
    expect(call.timeout, const Duration(seconds: 15));
    expect(call.parameters, <String, dynamic>{
      'listingId': 'listing-1',
      'viewerKey': 'viewer-session-1',
      'source': 'coverage-test',
    });
  });
}

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/data/marketplace/listing_read_repository.dart';
import 'package:presto_app/data/marketplace/listing_repository.dart';
import 'package:presto_app/models/marketplace_enums.dart';
import 'package:presto_app/models/marketplace_listing.dart';
import 'package:presto_app/models/marketplace_listing_draft.dart';
import 'package:presto_app/services/marketplace_human_verification.dart';
import 'package:presto_app/services/marketplace_publish_service.dart';

class _FakeListingRepository extends ListingRepository {
  final List<MarketplaceListingDraft> drafts = <MarketplaceListingDraft>[];
  final List<ListingMediaInput> updatedMedia = <ListingMediaInput>[];
  final List<String> recaptchaTokens = <String>[];
  final List<Object> createErrors = <Object>[];
  final List<Object> submitErrors = <Object>[];
  var createCalls = 0;
  var submitCalls = 0;
  String draftId = 'draft-1';
  String listingId = 'listing-1';

  @override
  Future<String> createDraft(MarketplaceListingDraft draft) async {
    createCalls += 1;
    if (createErrors.isNotEmpty) throw createErrors.removeAt(0);
    drafts.add(draft);
    return draftId;
  }

  @override
  Future<void> updateDraftMedia({
    required String draftId,
    required List<ListingMediaInput> media,
  }) async {
    updatedMedia.addAll(media);
  }

  @override
  Future<ListingSubmissionResult> submitDraft({
    required String draftId,
    required String recaptchaToken,
  }) async {
    submitCalls += 1;
    recaptchaTokens.add(recaptchaToken);
    if (submitErrors.isNotEmpty) throw submitErrors.removeAt(0);
    return ListingSubmissionResult(
      listingId: listingId,
      status: ListingStatus.active,
      moderationStatus: ModerationStatus.approved,
      visibility: ListingVisibility.public,
      riskScore: 0,
      thumbnailUrl: '',
      media: const <Map<String, dynamic>>[],
    );
  }
}

class _FakeListingReadRepository extends ListingReadRepository {
  Map<String, dynamic>? data;
  Object? error;
  String? requestedId;

  @override
  Future<Map<String, dynamic>?> getListingData(String listingId) async {
    requestedId = listingId;
    if (error != null) throw error!;
    return data;
  }
}

class _FakeVerification extends MarketplaceHumanVerification {
  _FakeVerification([List<Object>? outcomes])
      : outcomes = outcomes ?? <Object>['token-ok'];

  final List<Object> outcomes;
  final List<MarketplaceHumanVerificationAction> actions =
      <MarketplaceHumanVerificationAction>[];

  @override
  Future<String> obtainToken(MarketplaceHumanVerificationAction action) async {
    actions.add(action);
    final value = outcomes.isEmpty ? '' : outcomes.removeAt(0);
    if (value is Exception) throw value;
    if (value is Error) throw value;
    return value.toString();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  MarketplacePublishService service({
    required _FakeListingRepository repository,
    _FakeListingReadRepository? reader,
    _FakeVerification? verification,
  }) {
    return MarketplacePublishService(
      listingRepository: repository,
      listingReadRepository: reader ?? _FakeListingReadRepository(),
      verification: verification ?? _FakeVerification(),
    );
  }

  Future<MarketplacePublishResult> publish(
    MarketplacePublishService target, {
    String title = 'Recherche aide jardinage',
    String description =
        'Je recherche une personne disponible pour entretenir mon jardin cette semaine.',
    String category = 'Jardinage',
    String city = 'Baie-Mahault',
    String postalCode = '97122',
    bool hidePhone = false,
  }) {
    return target.publish(
      ownerId: 'owner-1',
      title: title,
      description: description,
      category: category,
      city: city,
      postalCode: postalCode,
      phone: '0690123456',
      subCategory: 'Entretien',
      missionDelay: 'Cette semaine',
      isUrgent: true,
      price: 45,
      budgetType: 'forfait',
      photos: const [],
      hidePhone: hidePhone,
    );
  }

  test('publie un brouillon canonique puis relit l annonce publique', () async {
    final repository = _FakeListingRepository();
    final reader = _FakeListingReadRepository()
      ..data = <String, dynamic>{
        'ownerId': 'owner-1',
        'title': 'Recherche aide jardinage',
        'description': 'Description publique',
        'price': 45,
        'categoryId': 'jardinage',
        'cityId': 'baie-mahault-97122',
        'status': 'active',
        'visibility': 'public',
        'moderationStatus': 'approved',
        'media': const <dynamic>[],
      };
    final verification = _FakeVerification(<Object>[' token-submit ']);

    final result = await publish(
      service(
        repository: repository,
        reader: reader,
        verification: verification,
      ),
      hidePhone: true,
    );

    expect(repository.createCalls, 1);
    expect(repository.submitCalls, 1);
    final draft = repository.drafts.single;
    expect(draft.ownerId, 'owner-1');
    expect(draft.title, 'Recherche aide jardinage');
    expect(draft.city, 'Baie-Mahault');
    expect(draft.postalCode, '97122');
    expect(draft.locationSource, 'local_city_data');
    expect(draft.price, 45);
    expect(draft.isUrgent, isTrue);
    expect(draft.hidePhone, isTrue);
    expect(draft.media, isEmpty);
    expect(repository.recaptchaTokens, <String>['token-submit']);
    expect(
      verification.actions,
      <MarketplaceHumanVerificationAction>[
        MarketplaceHumanVerificationAction.listingSubmit,
      ],
    );
    expect(reader.requestedId, 'listing-1');
    expect(result.listingId, 'listing-1');
    expect(result.isPubliclyVisible, isTrue);
    expect(result.detailData, isNotEmpty);
  });

  test('une relecture absente garde la publication réussie non visible', () async {
    final repository = _FakeListingRepository();
    final reader = _FakeListingReadRepository()..data = null;

    final result = await publish(service(repository: repository, reader: reader));

    expect(result.listingId, 'listing-1');
    expect(result.detailData, isEmpty);
    expect(result.isPubliclyVisible, isFalse);
  });

  test('une relecture privée ou en erreur reste non bloquante', () async {
    final hiddenRepository = _FakeListingRepository();
    final hiddenReader = _FakeListingReadRepository()
      ..data = <String, dynamic>{
        'status': 'draft',
        'visibility': 'private',
      };
    final hidden = await publish(
      service(repository: hiddenRepository, reader: hiddenReader),
    );
    expect(hidden.isPubliclyVisible, isFalse);

    final errorRepository = _FakeListingRepository();
    final errorReader = _FakeListingReadRepository()
      ..error = StateError('lecture indisponible');
    final errorResult = await publish(
      service(repository: errorRepository, reader: errorReader),
    );
    expect(errorResult.listingId, 'listing-1');
    expect(errorResult.detailData, isEmpty);
  });

  test('réessaie une erreur channel pendant la création du brouillon', () async {
    final repository = _FakeListingRepository()
      ..createErrors.add(
        PlatformException(
          code: 'channel-error',
          message: 'Unable to establish connection on channel.',
        ),
      );

    final result = await publish(service(repository: repository));

    expect(result.listingId, 'listing-1');
    expect(repository.createCalls, 2);
  });

  test('réessaie une permission Firestore refusée puis réussit', () async {
    final repository = _FakeListingRepository()
      ..createErrors.add(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        ),
      );

    final result = await publish(service(repository: repository));

    expect(result.listingId, 'listing-1');
    expect(repository.createCalls, 2);
  });

  test('propage une erreur de création non récupérable', () async {
    final repository = _FakeListingRepository()
      ..createErrors.add(StateError('écriture impossible'));

    await expectLater(
      publish(service(repository: repository)),
      throwsA(isA<StateError>()),
    );
    expect(repository.createCalls, 1);
    expect(repository.submitCalls, 0);
  });

  test('réessaie un token vide puis transmet le second token', () async {
    final repository = _FakeListingRepository();
    final verification = _FakeVerification(<Object>['', 'second-token']);

    await publish(
      service(repository: repository, verification: verification),
    );

    expect(verification.actions, hasLength(2));
    expect(repository.recaptchaTokens, <String>['second-token']);
  });

  test('publie sans token si la vérification reste indisponible', () async {
    final repository = _FakeListingRepository();
    final verification = _FakeVerification(<Object>['', '']);

    await publish(
      service(repository: repository, verification: verification),
    );

    expect(verification.actions, hasLength(2));
    expect(repository.recaptchaTokens, <String>['']);
  });

  test('une erreur channel de vérification finit avec un token vide', () async {
    final repository = _FakeListingRepository();
    final verification = _FakeVerification(<Object>[
      PlatformException(
        code: 'channel-error',
        message: 'Unable to establish connection',
      ),
      PlatformException(
        code: 'channel-error',
        message: 'Unable to establish connection',
      ),
      '',
      '',
    ]);

    await publish(
      service(repository: repository, verification: verification),
    );

    expect(repository.recaptchaTokens, <String>['']);
  });

  test('propage l échec de soumission finale', () async {
    final repository = _FakeListingRepository()
      ..submitErrors.add(StateError('soumission impossible'));

    await expectLater(
      publish(service(repository: repository)),
      throwsA(isA<StateError>()),
    );
    expect(repository.createCalls, 1);
    expect(repository.submitCalls, 1);
  });

  group('validation du brouillon', () {
    Future<void> expectRejected({
      String title = 'Recherche aide jardinage',
      String description =
          'Je recherche une personne disponible pour entretenir mon jardin cette semaine.',
      String city = 'Baie-Mahault',
    }) async {
      final repository = _FakeListingRepository();
      await expectLater(
        publish(
          service(repository: repository),
          title: title,
          description: description,
          city: city,
        ),
        throwsA(isA<StateError>()),
      );
      expect(repository.createCalls, 0);
    }

    test('refuse un titre trop court', () async {
      await expectRejected(title: 'abc');
    });

    test('refuse un titre trop long', () async {
      await expectRejected(title: List<String>.filled(200, 'a').join());
    });

    test('refuse une description trop courte', () async {
      await expectRejected(description: 'courte');
    });

    test('refuse une description trop longue', () async {
      await expectRejected(
        description: List<String>.filled(5000, 'd').join(),
      );
    });

    test('refuse une ville vide', () async {
      await expectRejected(city: '   ');
    });
  });

  test('construit un chemin Storage canonique stable', () {
    expect(
      MarketplacePublishService.buildRawPhotoStoragePathForTest(
        uid: 'owner-1',
        draftId: 'draft-1',
        index: 2,
        extension: 'webp',
        timestampMs: 1234,
      ),
      'listingDrafts/owner-1/draft-1/raw/1234_2.webp',
    );
  });

  test('MarketplaceHumanVerificationUnavailable expose son message', () {
    const error = MarketplaceHumanVerificationUnavailable('indisponible');
    expect(error.message, 'indisponible');
    expect(error.toString(), 'indisponible');
  });
}

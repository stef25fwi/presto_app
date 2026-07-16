import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:presto_app/data/marketplace/listing_read_repository.dart';
import 'package:presto_app/data/marketplace/listing_repository.dart';
import 'package:presto_app/models/marketplace_enums.dart';
import 'package:presto_app/models/marketplace_listing.dart';
import 'package:presto_app/models/marketplace_listing_draft.dart';
import 'package:presto_app/services/marketplace_human_verification.dart';
import 'package:presto_app/services/marketplace_publish_service.dart';

class _EdgeListingRepository extends ListingRepository {
  final List<Object> createErrors = <Object>[];
  final List<Object> submitErrors = <Object>[];
  final List<MarketplaceListingDraft> drafts = <MarketplaceListingDraft>[];
  final List<String> tokens = <String>[];
  var createCalls = 0;
  var submitCalls = 0;

  @override
  Future<String> createDraft(MarketplaceListingDraft draft) async {
    createCalls += 1;
    if (createErrors.isNotEmpty) throw createErrors.removeAt(0);
    drafts.add(draft);
    return 'draft-edge';
  }

  @override
  Future<ListingSubmissionResult> submitDraft({
    required String draftId,
    required String recaptchaToken,
  }) async {
    submitCalls += 1;
    tokens.add(recaptchaToken);
    if (submitErrors.isNotEmpty) throw submitErrors.removeAt(0);
    return const ListingSubmissionResult(
      listingId: 'listing-edge',
      status: ListingStatus.active,
      moderationStatus: ModerationStatus.approved,
      visibility: ListingVisibility.public,
      riskScore: 0,
      thumbnailUrl: '',
      media: <Map<String, dynamic>>[],
    );
  }
}

class _EmptyListingReader extends ListingReadRepository {
  @override
  Future<Map<String, dynamic>?> getListingData(String listingId) async => null;
}

class _EdgeVerification extends MarketplaceHumanVerification {
  _EdgeVerification([List<Object>? outcomes])
      : outcomes = outcomes ?? <Object>['edge-token'];

  final List<Object> outcomes;
  var calls = 0;

  @override
  Future<String> obtainToken(MarketplaceHumanVerificationAction action) async {
    calls += 1;
    final outcome = outcomes.isEmpty ? '' : outcomes.removeAt(0);
    if (outcome is Exception) throw outcome;
    if (outcome is Error) throw outcome;
    return outcome.toString();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  MarketplacePublishService service(
    _EdgeListingRepository repository, {
    _EdgeVerification? verification,
  }) {
    return MarketplacePublishService(
      listingRepository: repository,
      listingReadRepository: _EmptyListingReader(),
      verification: verification ?? _EdgeVerification(),
    );
  }

  Future<MarketplacePublishResult> publish(
    MarketplacePublishService target, {
    String category = 'Jardinage',
    String postalCode = '97180',
    String? subCategory = 'Entretien',
    String? missionDelay = 'Cette semaine',
  }) {
    return target.publish(
      ownerId: 'owner-edge',
      title: 'Recherche aide jardinage',
      description:
          'Je recherche une personne disponible pour entretenir mon jardin cette semaine.',
      category: category,
      city: 'Sainte-Anne',
      postalCode: postalCode,
      phone: '0690123456',
      subCategory: subCategory,
      missionDelay: missionDelay,
      isUrgent: false,
      price: 35,
      budgetType: 'forfait',
      photos: const <XFile>[],
    );
  }

  PlatformException channelError({
    String code = 'channel-error',
    String message = 'Unable to establish connection on channel.',
  }) {
    return PlatformException(code: code, message: message);
  }

  test('deux erreurs channel de création produisent le message de repli',
      () async {
    final repository = _EdgeListingRepository()
      ..createErrors.addAll(<Object>[
        channelError(),
        channelError(),
      ]);

    await expectLater(
      publish(service(repository)),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('brouillon Firestore'),
        ),
      ),
    );
    expect(repository.createCalls, 2);
    expect(repository.submitCalls, 0);
  });

  test('le texte de connexion suffit à reconnaître une erreur channel',
      () async {
    final repository = _EdgeListingRepository()
      ..createErrors.add(
        channelError(
          code: 'platform-failure',
          message: 'Unable to establish connection with the native channel',
        ),
      );

    final result = await publish(service(repository));

    expect(result.listingId, 'listing-edge');
    expect(repository.createCalls, 2);
    expect(repository.submitCalls, 1);
  });

  test('deux erreurs channel de soumission produisent le repli final',
      () async {
    final repository = _EdgeListingRepository()
      ..submitErrors.addAll(<Object>[
        channelError(),
        channelError(),
      ]);

    await expectLater(
      publish(service(repository)),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('publication finale'),
        ),
      ),
    );
    expect(repository.createCalls, 1);
    expect(repository.submitCalls, 2);
  });

  test('une erreur non channel de vérification est propagée', () async {
    final repository = _EdgeListingRepository();
    final verification = _EdgeVerification(<Object>[
      StateError('vérification interrompue'),
    ]);

    await expectLater(
      publish(service(repository, verification: verification)),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'vérification interrompue',
        ),
      ),
    );
    expect(verification.calls, 1);
    expect(repository.createCalls, 1);
    expect(repository.submitCalls, 0);
  });

  test('un second refus Firestore reste une erreur après la préparation',
      () async {
    final repository = _EdgeListingRepository()
      ..createErrors.addAll(<Object>[
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        ),
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        ),
      ]);

    await expectLater(
      publish(service(repository)),
      throwsA(
        isA<FirebaseException>().having(
          (error) => error.code,
          'code',
          'permission-denied',
        ),
      ),
    );
    expect(repository.createCalls, 2);
    expect(repository.submitCalls, 0);
  });

  test('une catégorie vide utilise le repli Autre', () async {
    final repository = _EdgeListingRepository();

    final result = await publish(
      service(repository),
      category: '   ',
      subCategory: null,
      missionDelay: null,
    );

    final draft = repository.drafts.single;
    expect(result.listingId, 'listing-edge');
    expect(draft.category, 'Autre');
    expect(draft.categoryId, 'autre');
    expect(draft.subCategory, isNull);
    expect(draft.missionDelay, isNull);
    expect(draft.isUrgent, isFalse);
    expect(draft.hidePhone, isFalse);
  });

  test('un code postal vide est complété depuis la ville canonique', () async {
    final repository = _EdgeListingRepository();

    await publish(service(repository), postalCode: '');

    final draft = repository.drafts.single;
    expect(draft.city, 'Sainte-Anne');
    expect(draft.postalCode, '97180');
    expect(draft.cp, '97180');
    expect(draft.location, 'Sainte-Anne');
    expect(draft.locationSource, 'local_city_data');
    expect(draft.departmentCode, isNotEmpty);
    expect(draft.regionCode, isNotEmpty);
  });
}

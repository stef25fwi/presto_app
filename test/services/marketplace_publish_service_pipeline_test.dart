import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:presto_app/data/marketplace/listing_read_repository.dart';
import 'package:presto_app/data/marketplace/listing_repository.dart';
import 'package:presto_app/models/marketplace_enums.dart';
import 'package:presto_app/models/marketplace_listing.dart';
import 'package:presto_app/models/marketplace_listing_draft.dart';
import 'package:presto_app/services/marketplace_human_verification.dart';
import 'package:presto_app/services/marketplace_publish_service.dart';

class _NullAuthPlatform extends FirebaseAuthPlatform {
  _NullAuthPlatform() : super(appInstance: null);

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) =>
      this;

  @override
  UserPlatform? get currentUser => null;

  @override
  Stream<UserPlatform?> authStateChanges() => Stream<UserPlatform?>.value(null);

  @override
  Stream<UserPlatform?> userChanges() => Stream<UserPlatform?>.value(null);
}

class _FakeListingRepository extends ListingRepository {
  _FakeListingRepository() : super(firestore: FakeFirebaseFirestore());

  MarketplaceListingDraft? createdDraft;
  String? submittedDraftId;
  String? submittedRecaptchaToken;
  Object? createError;
  Object? submitError;
  var createCalls = 0;
  var submitCalls = 0;
  var updateMediaCalls = 0;

  @override
  Future<String> createDraft(MarketplaceListingDraft draft) async {
    createCalls += 1;
    final error = createError;
    if (error != null) throw error;
    createdDraft = draft;
    return 'draft-pipeline-1';
  }

  @override
  Future<void> updateDraftMedia({
    required String draftId,
    required List<ListingMediaInput> media,
  }) async {
    updateMediaCalls += 1;
  }

  @override
  Future<ListingSubmissionResult> submitDraft({
    required String draftId,
    required String recaptchaToken,
  }) async {
    submitCalls += 1;
    submittedDraftId = draftId;
    submittedRecaptchaToken = recaptchaToken;
    final error = submitError;
    if (error != null) throw error;
    return const ListingSubmissionResult(
      listingId: 'listing-pipeline-1',
      status: ListingStatus.active,
      moderationStatus: ModerationStatus.approved,
      visibility: ListingVisibility.public,
      riskScore: 0,
      thumbnailUrl: '',
      media: <Map<String, dynamic>>[],
    );
  }
}

class _FakeListingReadRepository extends ListingReadRepository {
  _FakeListingReadRepository() : super(firestore: FakeFirebaseFirestore());

  Map<String, dynamic>? data;
  Object? error;
  var calls = 0;

  @override
  Future<Map<String, dynamic>?> getListingData(String listingId) async {
    calls += 1;
    final currentError = error;
    if (currentError != null) throw currentError;
    return data;
  }
}

class _FakeVerification extends MarketplaceHumanVerification {
  _FakeVerification(this.tokens);

  final List<String> tokens;
  var calls = 0;

  @override
  Future<String> obtainToken(MarketplaceHumanVerificationAction action) async {
    final index = calls < tokens.length ? calls : tokens.length - 1;
    calls += 1;
    return tokens[index];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    try {
      await Firebase.initializeApp();
    } on FirebaseException catch (error) {
      if (error.code != 'duplicate-app') rethrow;
    }
    FirebaseAuthPlatform.instance = _NullAuthPlatform();
  });

  MarketplacePublishService service({
    required _FakeListingRepository listings,
    required _FakeListingReadRepository reads,
    required _FakeVerification verification,
  }) {
    return MarketplacePublishService(
      listingRepository: listings,
      listingReadRepository: reads,
      verification: verification,
    );
  }

  Future<MarketplacePublishResult> publish(
    MarketplacePublishService service, {
    String title = 'Tonte et entretien complet du jardin',
    String description =
        'Je recherche une personne expérimentée pour entretenir le jardin et évacuer les déchets verts.',
    String city = 'Sainte-Anne',
    String postalCode = '97180',
  }) {
    return service.publish(
      ownerId: 'owner-pipeline-1',
      title: title,
      description: description,
      category: 'Jardinage',
      city: city,
      postalCode: postalCode,
      phone: '0690123456',
      subCategory: 'Entretien extérieur',
      missionDelay: 'Cette semaine',
      isUrgent: false,
      price: 80,
      budgetType: 'fixed',
      photos: const <XFile>[],
    );
  }

  test('publie un brouillon et retourne les données publiques relues', () async {
    final listings = _FakeListingRepository();
    final reads = _FakeListingReadRepository()
      ..data = <String, dynamic>{
        'status': 'active',
        'visibility': 'public',
        'ownerId': 'owner-pipeline-1',
        'ownerName': 'Alice',
        'title': 'Tonte et entretien complet du jardin',
        'description': 'Description publique de la prestation.',
        'city': 'Sainte-Anne',
        'postalCode': '97180',
        'price': 80,
        'media': const <Map<String, dynamic>>[],
      };
    final verification = _FakeVerification(<String>['recaptcha-ok']);

    final result = await publish(
      service(
        listings: listings,
        reads: reads,
        verification: verification,
      ),
    );

    expect(listings.createCalls, 1);
    expect(listings.submitCalls, 1);
    expect(listings.updateMediaCalls, 0);
    expect(listings.submittedDraftId, 'draft-pipeline-1');
    expect(listings.submittedRecaptchaToken, 'recaptcha-ok');
    expect(listings.createdDraft?.ownerId, 'owner-pipeline-1');
    expect(listings.createdDraft?.city, 'Sainte-Anne');
    expect(listings.createdDraft?.postalCode, '97180');
    expect(listings.createdDraft?.media, isEmpty);
    expect(result.listingId, 'listing-pipeline-1');
    expect(result.isPubliclyVisible, isTrue);
    expect(result.detailData['listingId'], 'listing-pipeline-1');
    expect(result.detailData['ownerName'], 'Alice');
  });

  test('une relecture en erreur reste non bloquante après soumission', () async {
    final listings = _FakeListingRepository();
    final reads = _FakeListingReadRepository()
      ..error = StateError('relecture indisponible');

    final result = await publish(
      service(
        listings: listings,
        reads: reads,
        verification: _FakeVerification(<String>['token']),
      ),
    );

    expect(listings.submitCalls, 1);
    expect(reads.calls, 1);
    expect(result.listingId, 'listing-pipeline-1');
    expect(result.detailData, isEmpty);
    expect(result.isPubliclyVisible, isFalse);
  });

  test('publie sans jeton lorsque la vérification reste indisponible',
      () async {
    final listings = _FakeListingRepository();
    final verification = _FakeVerification(<String>['', '']);

    final result = await publish(
      service(
        listings: listings,
        reads: _FakeListingReadRepository(),
        verification: verification,
      ),
    );

    expect(verification.calls, 2);
    expect(listings.submittedRecaptchaToken, '');
    expect(result.listingId, 'listing-pipeline-1');
  });

  test('propage une soumission refusée sans effectuer de relecture', () async {
    final listings = _FakeListingRepository()
      ..submitError = StateError('publication refusée');
    final reads = _FakeListingReadRepository();

    await expectLater(
      publish(
        service(
          listings: listings,
          reads: reads,
          verification: _FakeVerification(<String>['token']),
        ),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'publication refusée',
        ),
      ),
    );

    expect(listings.submitCalls, 1);
    expect(reads.calls, 0);
  });

  final invalidInputs = <({String name, String title, String description})>[
    (
      name: 'titre trop court',
      title: 'Court',
      description:
          'Cette description est suffisamment longue pour atteindre le contrôle du titre.',
    ),
    (
      name: 'titre trop long',
      title: List<String>.filled(121, 'a').join(),
      description:
          'Cette description est suffisamment longue pour atteindre le contrôle du titre.',
    ),
    (
      name: 'description trop courte',
      title: 'Titre suffisamment long',
      description: 'Trop courte',
    ),
    (
      name: 'description trop longue',
      title: 'Titre suffisamment long',
      description: List<String>.filled(4001, 'd').join(),
    ),
  ];

  for (final input in invalidInputs) {
    test('refuse ${input.name} avant de créer le brouillon', () async {
      final listings = _FakeListingRepository();

      await expectLater(
        publish(
          service(
            listings: listings,
            reads: _FakeListingReadRepository(),
            verification: _FakeVerification(<String>['token']),
          ),
          title: input.title,
          description: input.description,
        ),
        throwsA(isA<StateError>()),
      );

      expect(listings.createCalls, 0);
    });
  }

  test('refuse une ville vide avant de créer le brouillon', () async {
    final listings = _FakeListingRepository();

    await expectLater(
      publish(
        service(
          listings: listings,
          reads: _FakeListingReadRepository(),
          verification: _FakeVerification(<String>['token']),
        ),
        city: '   ',
        postalCode: '',
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('ville est obligatoire'),
        ),
      ),
    );

    expect(listings.createCalls, 0);
  });

  test('couvre les helpers photo et le message de vérification', () {
    final path = MarketplacePublishService.buildRawPhotoStoragePathForTest(
      uid: 'owner-1',
      draftId: 'draft-1',
      index: 2,
      extension: 'webp',
    );
    expect(path, contains('owner-1'));
    expect(path, contains('draft-1'));
    expect(path, endsWith('_2.webp'));

    final media = MarketplacePublishService.parseProcessedOfferPhotoForTest(
      <String, dynamic>{
        'storagePath': 'listings/final.webp',
        'downloadUrl': 'https://example.test/final.webp',
        'width': 1200,
        'height': 800,
        'mimeType': 'image/webp',
        'sizeBytes': 4096,
      },
    );
    expect(media.thumbnailUrl, 'https://example.test/final.webp');
    expect(media.width, 1200);
    expect(media.height, 800);

    expect(
      MarketplacePublishService.resolveStorageExtensionForTest(
        path: 'photo.unknown',
        mimeType: 'image/avif',
      ),
      'avif',
    );
    expect(
      MarketplacePublishService.resolveStorageContentTypeForTest(
        path: 'photo.tiff',
      ),
      'image/tiff',
    );
    expect(
      const MarketplaceHumanVerificationUnavailable('verification impossible')
          .toString(),
      'verification impossible',
    );
  });
}

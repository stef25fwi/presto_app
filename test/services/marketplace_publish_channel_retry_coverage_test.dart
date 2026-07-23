import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
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

class _RetryNullAuthPlatform extends FirebaseAuthPlatform {
  _RetryNullAuthPlatform() : super(appInstance: null);

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

class _RetryListingRepository extends ListingRepository {
  _RetryListingRepository({
    this.createChannelFailures = 0,
    this.createPermissionFailures = 0,
  }) : super(firestore: FakeFirebaseFirestore());

  final int createChannelFailures;
  final int createPermissionFailures;
  var createCalls = 0;
  var submitCalls = 0;
  String? submittedRecaptchaToken;

  @override
  Future<String> createDraft(MarketplaceListingDraft draft) async {
    createCalls += 1;
    if (createCalls <= createPermissionFailures) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'App Check token refresh required.',
      );
    }
    if (createChannelFailures < 0 || createCalls <= createChannelFailures) {
      throw PlatformException(
        code: 'channel-error',
        message: 'Unable to establish connection on channel.',
      );
    }
    return 'retry-draft';
  }

  @override
  Future<ListingSubmissionResult> submitDraft({
    required String draftId,
    required String recaptchaToken,
  }) async {
    submitCalls += 1;
    submittedRecaptchaToken = recaptchaToken;
    return const ListingSubmissionResult(
      listingId: 'retry-listing',
      status: ListingStatus.active,
      moderationStatus: ModerationStatus.approved,
      visibility: ListingVisibility.public,
      riskScore: 0,
      thumbnailUrl: '',
      media: <Map<String, dynamic>>[],
    );
  }
}

class _RetryListingReadRepository extends ListingReadRepository {
  _RetryListingReadRepository() : super(firestore: FakeFirebaseFirestore());

  @override
  Future<Map<String, dynamic>?> getListingData(String listingId) async => null;
}

class _StaticVerification extends MarketplaceHumanVerification {
  const _StaticVerification(this.token);

  final String token;

  @override
  Future<String> obtainToken(MarketplaceHumanVerificationAction action) async =>
      token;
}

class _ChannelFailingVerification extends MarketplaceHumanVerification {
  var calls = 0;

  @override
  Future<String> obtainToken(MarketplaceHumanVerificationAction action) async {
    calls += 1;
    throw PlatformException(
      code: 'channel-error',
      message: 'Unable to establish connection to verification channel.',
    );
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
    FirebaseAuthPlatform.instance = _RetryNullAuthPlatform();
  });

  MarketplacePublishService service({
    required _RetryListingRepository listings,
    required MarketplaceHumanVerification verification,
  }) {
    return MarketplacePublishService(
      listingRepository: listings,
      listingReadRepository: _RetryListingReadRepository(),
      verification: verification,
    );
  }

  Future<MarketplacePublishResult> publish(
    MarketplacePublishService current,
  ) {
    return current.publish(
      ownerId: 'retry-owner',
      title: 'Entretien complet du jardin extérieur',
      description:
          'Je recherche une personne expérimentée pour entretenir le jardin et évacuer les déchets verts.',
      category: 'Jardinage',
      city: 'Sainte-Anne',
      postalCode: '97180',
      phone: '0690123456',
      subCategory: 'Entretien extérieur',
      missionDelay: 'Cette semaine',
      isUrgent: false,
      price: 80,
      budgetType: 'fixed',
      photos: const <XFile>[],
    );
  }

  test('réessaie le brouillon après une erreur de canal puis publie', () async {
    final listings = _RetryListingRepository(createChannelFailures: 1);

    final result = await publish(
      service(
        listings: listings,
        verification: const _StaticVerification('retry-token'),
      ),
    );

    expect(listings.createCalls, 2);
    expect(listings.submitCalls, 1);
    expect(listings.submittedRecaptchaToken, 'retry-token');
    expect(result.listingId, 'retry-listing');
    expect(result.isPubliclyVisible, isFalse);
  });

  test('transforme deux erreurs de canal du brouillon en erreur lisible',
      () async {
    final listings = _RetryListingRepository(createChannelFailures: -1);

    await expectLater(
      publish(
        service(
          listings: listings,
          verification: const _StaticVerification('unused-token'),
        ),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Connexion au service "brouillon Firestore" impossible'),
        ),
      ),
    );

    expect(listings.createCalls, 2);
    expect(listings.submitCalls, 0);
  });

  test('réessaie après permission-denied puis termine la publication', () async {
    final listings = _RetryListingRepository(createPermissionFailures: 1);

    final result = await publish(
      service(
        listings: listings,
        verification: const _StaticVerification('permission-token'),
      ),
    );

    expect(listings.createCalls, 2);
    expect(listings.submitCalls, 1);
    expect(listings.submittedRecaptchaToken, 'permission-token');
    expect(result.listingId, 'retry-listing');
  });

  test('publie sans reCAPTCHA après les retries du canal client', () async {
    final listings = _RetryListingRepository();
    final verification = _ChannelFailingVerification();

    final result = await publish(
      service(listings: listings, verification: verification),
    );

    expect(verification.calls, 4);
    expect(listings.submittedRecaptchaToken, '');
    expect(result.listingId, 'retry-listing');
  });
}

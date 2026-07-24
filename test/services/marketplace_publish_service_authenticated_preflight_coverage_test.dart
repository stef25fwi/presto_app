import 'package:firebase_auth/firebase_auth.dart';
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

class _PublishMultiFactorPlatform extends MultiFactorPlatform {
  _PublishMultiFactorPlatform(super.auth);
}

class _PublishUserPlatform extends UserPlatform {
  _PublishUserPlatform(FirebaseAuthPlatform auth)
      : super(
          auth,
          _PublishMultiFactorPlatform(auth),
          InternalUserDetails(
            userInfo: InternalUserInfo(
              uid: 'publish-owner',
              email: 'publish-owner@ilipresto.fr',
              displayName: 'Annonceur Test',
              isAnonymous: false,
              isEmailVerified: true,
              creationTimestamp:
                  DateTime(2026, 1, 1).millisecondsSinceEpoch,
              lastSignInTimestamp:
                  DateTime(2026, 7, 24).millisecondsSinceEpoch,
            ),
            providerData: const <Map<String, dynamic>?>[],
          ),
        );

  var tokenCalls = 0;

  @override
  Future<String?> getIdToken(bool forceRefresh) async {
    tokenCalls += 1;
    throw FirebaseException(
      plugin: 'firebase_auth',
      code: 'permission-denied',
      message: 'preflight intentionally unavailable in widget test',
    );
  }
}

class _PublishAuthPlatform extends FirebaseAuthPlatform {
  _PublishAuthPlatform() : super(appInstance: null) {
    user = _PublishUserPlatform(this);
  }

  late final _PublishUserPlatform user;

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) =>
      this;

  @override
  UserPlatform? get currentUser => user;

  @override
  Stream<UserPlatform?> authStateChanges() =>
      Stream<UserPlatform?>.value(user);

  @override
  Stream<UserPlatform?> userChanges() => Stream<UserPlatform?>.value(user);
}

class _PublishListingRepository extends ListingRepository {
  var createCalls = 0;
  var submitCalls = 0;
  MarketplaceListingDraft? capturedDraft;

  @override
  Future<String> createDraft(MarketplaceListingDraft draft) async {
    createCalls += 1;
    capturedDraft = draft;
    return 'authenticated-draft';
  }

  @override
  Future<ListingSubmissionResult> submitDraft({
    required String draftId,
    required String recaptchaToken,
  }) async {
    submitCalls += 1;
    return const ListingSubmissionResult(
      listingId: 'authenticated-listing',
      status: ListingStatus.active,
      moderationStatus: ModerationStatus.approved,
      visibility: ListingVisibility.public,
      riskScore: 0,
      thumbnailUrl: '',
      media: <Map<String, dynamic>>[],
    );
  }
}

class _PublishReadRepository extends ListingReadRepository {
  @override
  Future<Map<String, dynamic>?> getListingData(String listingId) async => null;
}

class _PublishVerification extends MarketplaceHumanVerification {
  var calls = 0;

  @override
  Future<String> obtainToken(MarketplaceHumanVerificationAction action) async {
    calls += 1;
    return 'authenticated-token';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _PublishAuthPlatform authPlatform;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    authPlatform = _PublishAuthPlatform();
    FirebaseAuthPlatform.instance = authPlatform;
  });

  setUp(() {
    authPlatform.user.tokenCalls = 0;
  });

  test('continue après un préflight authentifié indisponible', () async {
    final repository = _PublishListingRepository();
    final verification = _PublishVerification();
    final service = MarketplacePublishService(
      listingRepository: repository,
      listingReadRepository: _PublishReadRepository(),
      verification: verification,
    );

    final result = await service.publish(
      ownerId: 'publish-owner',
      title: 'Recherche aide pour entretien du jardin',
      description:
          'Je recherche une personne disponible pour entretenir complètement mon jardin cette semaine.',
      category: 'Jardinage',
      city: 'Sainte-Anne',
      postalCode: '97180',
      phone: '0690123456',
      subCategory: 'Entretien',
      missionDelay: 'Cette semaine',
      isUrgent: false,
      price: 75,
      budgetType: 'forfait',
      photos: const <XFile>[],
    );

    expect(authPlatform.user.tokenCalls, greaterThanOrEqualTo(1));
    expect(repository.createCalls, 1);
    expect(repository.submitCalls, 1);
    expect(repository.capturedDraft?.ownerId, 'publish-owner');
    expect(verification.calls, 1);
    expect(result.listingId, 'authenticated-listing');
    expect(result.isPubliclyVisible, isFalse);
  });
}

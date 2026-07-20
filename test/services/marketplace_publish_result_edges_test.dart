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
  Stream<UserPlatform?> authStateChanges() => Stream.value(null);

  @override
  Stream<UserPlatform?> userChanges() => Stream.value(null);
}

class _RecordingListingRepository extends ListingRepository {
  _RecordingListingRepository() : super(firestore: FakeFirebaseFirestore());

  MarketplaceListingDraft? draft;

  @override
  Future<String> createDraft(MarketplaceListingDraft draft) async {
    this.draft = draft;
    return 'draft-edge-1';
  }

  @override
  Future<ListingSubmissionResult> submitDraft({
    required String draftId,
    required String recaptchaToken,
  }) async {
    return const ListingSubmissionResult(
      listingId: 'listing-edge-1',
      status: ListingStatus.active,
      moderationStatus: ModerationStatus.approved,
      visibility: ListingVisibility.public,
      riskScore: 0,
      thumbnailUrl: '',
      media: <Map<String, dynamic>>[],
    );
  }
}

class _StaticListingReadRepository extends ListingReadRepository {
  _StaticListingReadRepository(this.value)
      : super(firestore: FakeFirebaseFirestore());

  final Map<String, dynamic>? value;

  @override
  Future<Map<String, dynamic>?> getListingData(String listingId) async => value;
}

class _StaticVerification extends MarketplaceHumanVerification {
  const _StaticVerification();

  @override
  Future<String> obtainToken(MarketplaceHumanVerificationAction action) async =>
      'token-edge';
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

  Future<({MarketplacePublishResult result, MarketplaceListingDraft draft})>
      publishWith(Map<String, dynamic>? listingData) async {
    final listings = _RecordingListingRepository();
    final service = MarketplacePublishService(
      listingRepository: listings,
      listingReadRepository: _StaticListingReadRepository(listingData),
      verification: const _StaticVerification(),
    );

    final result = await service.publish(
      ownerId: 'owner-edge-1',
      title: 'Besoin d aide pour monter un meuble',
      description:
          'Je recherche une personne disponible pour monter proprement un meuble et vérifier sa stabilité.',
      category: 'Catégorie inconnue',
      city: 'Sainte-Anne',
      postalCode: '97180',
      phone: '0690123456',
      subCategory: null,
      missionDelay: null,
      isUrgent: true,
      price: 55,
      budgetType: 'fixed',
      photos: const <XFile>[],
      hidePhone: true,
    );

    return (result: result, draft: listings.draft!);
  }

  test('conserve une annonce relue mais non publique hors du détail UI',
      () async {
    final execution = await publishWith(<String, dynamic>{
      'status': 'draft',
      'visibility': 'private',
      'ownerId': 'owner-edge-1',
      'title': 'Annonce non publique',
    });

    expect(execution.result.listingId, 'listing-edge-1');
    expect(execution.result.detailData, isEmpty);
    expect(execution.result.isPubliclyVisible, isFalse);
  });

  test('accepte une relecture absente après une soumission réussie', () async {
    final execution = await publishWith(null);

    expect(execution.result.listingId, 'listing-edge-1');
    expect(execution.result.detailData, isEmpty);
    expect(execution.result.isPubliclyVisible, isFalse);
  });

  test('normalise le brouillon avec catégorie de repli et options métier',
      () async {
    final execution = await publishWith(null);

    expect(execution.draft.category, 'Autre');
    expect(execution.draft.hidePhone, isTrue);
    expect(execution.draft.isUrgent, isTrue);
    expect(execution.draft.subCategory, isNull);
    expect(execution.draft.missionDelay, isNull);
    expect(execution.draft.city, 'Sainte-Anne');
    expect(execution.draft.postalCode, '97180');
    expect(execution.draft.media, isEmpty);
  });
}

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:presto_app/data/marketplace/listing_read_repository.dart';
import 'package:presto_app/data/marketplace/listing_repository.dart';
import 'package:presto_app/models/marketplace_listing_draft.dart';
import 'package:presto_app/services/marketplace_human_verification.dart';
import 'package:presto_app/services/marketplace_publish_service.dart';

class _LocationNullAuthPlatform extends FirebaseAuthPlatform {
  _LocationNullAuthPlatform() : super(appInstance: null);

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
}

class _LocationListingRepository extends ListingRepository {
  _LocationListingRepository() : super(firestore: FakeFirebaseFirestore());

  var createCalls = 0;

  @override
  Future<String> createDraft(MarketplaceListingDraft draft) async {
    createCalls += 1;
    return 'unexpected-draft';
  }
}

class _LocationReadRepository extends ListingReadRepository {
  _LocationReadRepository() : super(firestore: FakeFirebaseFirestore());
}

class _LocationVerification extends MarketplaceHumanVerification {
  var calls = 0;

  @override
  Future<String> obtainToken(MarketplaceHumanVerificationAction action) async {
    calls += 1;
    return 'unexpected-token';
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
    FirebaseAuthPlatform.instance = _LocationNullAuthPlatform();
  });

  test('refuse une ville inconnue sans lancer réseau ni écriture', () async {
    final listings = _LocationListingRepository();
    final verification = _LocationVerification();
    final service = MarketplacePublishService(
      listingRepository: listings,
      listingReadRepository: _LocationReadRepository(),
      verification: verification,
    );

    await expectLater(
      service.publish(
        ownerId: 'location-owner',
        title: 'Entretien complet du jardin extérieur',
        description:
            'Je recherche une personne expérimentée pour entretenir le jardin et évacuer les déchets verts.',
        category: 'Jardinage',
        city: 'X',
        postalCode: '',
        phone: '0690123456',
        subCategory: 'Entretien extérieur',
        missionDelay: 'Cette semaine',
        isUrgent: false,
        price: 80,
        budgetType: 'fixed',
        photos: const <XFile>[],
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Choisissez une ville'),
        ),
      ),
    );

    expect(listings.createCalls, 0);
    expect(verification.calls, 0);
  });
}

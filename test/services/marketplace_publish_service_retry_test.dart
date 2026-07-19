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
}

class _RetryListingRepository extends ListingRepository {
  _RetryListingRepository() : super(firestore: FakeFirebaseFirestore());

  final createErrors = <Object>[];
  var createCalls = 0;
  var submitCalls = 0;
  String? submittedToken;

  @override
  Future<String> createDraft(MarketplaceListingDraft draft) async {
    createCalls += 1;
    if (createErrors.isNotEmpty) throw createErrors.removeAt(0);
    return 'retry-draft';
  }

  @override
  Future<ListingSubmissionResult> submitDraft({
    required String draftId,
    required String recaptchaToken,
  }) async {
    submitCalls += 1;
    submittedToken = recaptchaToken;
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

class _RetryReadRepository extends ListingReadRepository {
  _RetryReadRepository() : super(firestore: FakeFirebaseFirestore());

  @override
  Future<Map<String, dynamic>?> getListingData(String listingId) async => null;
}

class _RetryVerification extends MarketplaceHumanVerification {
  _RetryVerification(this.errors);

  final List<Object> errors;
  var calls = 0;

  @override
  Future<String> obtainToken(MarketplaceHumanVerificationAction action) async {
    calls += 1;
    if (errors.isNotEmpty) throw errors.removeAt(0);
    return 'token-ok';
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
    required _RetryVerification verification,
  }) {
    return MarketplacePublishService(
      listingRepository: listings,
      listingReadRepository: _RetryReadRepository(),
      verification: verification,
    );
  }

  Future<MarketplacePublishResult> publish(
    MarketplacePublishService service,
  ) {
    return service.publish(
      ownerId: 'retry-owner',
      title: 'Tonte et entretien complet du jardin',
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

  PlatformException channelError() => PlatformException(
        code: 'channel-error',
        message: 'Unable to establish connection on channel.',
      );

  test('construit les dépendances par défaut et l exception non constante', () {
    final defaultService = MarketplacePublishService();
    final error = MarketplaceHumanVerificationUnavailable(
      'vérification temporairement indisponible',
    );

    expect(defaultService, isA<MarketplacePublishService>());
    expect(error.toString(), 'vérification temporairement indisponible');
  });

  test('réessaie le brouillon après une erreur de canal puis réussit', () async {
    final listings = _RetryListingRepository()
      ..createErrors.add(channelError());

    final result = await publish(
      service(
        listings: listings,
        verification: _RetryVerification(<Object>[]),
      ),
    );

    expect(listings.createCalls, 2);
    expect(listings.submitCalls, 1);
    expect(result.listingId, 'retry-listing');
  });

  test('transforme deux erreurs de canal en erreur utilisateur bornée', () async {
    final listings = _RetryListingRepository()
      ..createErrors.addAll(<Object>[channelError(), channelError()]);

    await expectLater(
      publish(
        service(
          listings: listings,
          verification: _RetryVerification(<Object>[]),
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

  test('utilise le fallback vide après épuisement des retries reCAPTCHA',
      () async {
    final listings = _RetryListingRepository();
    final verification = _RetryVerification(
      <Object>[
        channelError(),
        channelError(),
        channelError(),
        channelError(),
      ],
    );

    final result = await publish(
      service(listings: listings, verification: verification),
    );

    expect(verification.calls, 4);
    expect(listings.submittedToken, '');
    expect(result.listingId, 'retry-listing');
  });

  test('réessaie le brouillon après permission-denied', () async {
    final listings = _RetryListingRepository()
      ..createErrors.add(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'session à rafraîchir',
        ),
      );

    final result = await publish(
      service(
        listings: listings,
        verification: _RetryVerification(<Object>[]),
      ),
    );

    expect(listings.createCalls, 2);
    expect(listings.submitCalls, 1);
    expect(result.listingId, 'retry-listing');
  });

  test('ne réessaie pas une erreur métier non liée au canal', () async {
    final listings = _RetryListingRepository()
      ..createErrors.add(StateError('brouillon refusé'));

    await expectLater(
      publish(
        service(
          listings: listings,
          verification: _RetryVerification(<Object>[]),
        ),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'brouillon refusé',
        ),
      ),
    );

    expect(listings.createCalls, 1);
    expect(listings.submitCalls, 0);
  });
}

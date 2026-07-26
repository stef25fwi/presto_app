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

class _BoundaryListingRepository extends ListingRepository {
  final List<MarketplaceListingDraft> drafts = <MarketplaceListingDraft>[];

  @override
  Future<String> createDraft(MarketplaceListingDraft draft) async {
    drafts.add(draft);
    return 'boundary-draft';
  }

  @override
  Future<ListingSubmissionResult> submitDraft({
    required String draftId,
    required String recaptchaToken,
  }) async {
    return const ListingSubmissionResult(
      listingId: 'boundary-listing',
      status: ListingStatus.active,
      moderationStatus: ModerationStatus.approved,
      visibility: ListingVisibility.public,
      riskScore: 0,
      thumbnailUrl: '',
      media: <Map<String, dynamic>>[],
    );
  }
}

class _BoundaryListingReader extends ListingReadRepository {
  @override
  Future<Map<String, dynamic>?> getListingData(String listingId) async => null;
}

class _BoundaryVerification extends MarketplaceHumanVerification {
  @override
  Future<String> obtainToken(MarketplaceHumanVerificationAction action) async {
    return 'boundary-token';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  MarketplacePublishService service(_BoundaryListingRepository repository) {
    return MarketplacePublishService(
      listingRepository: repository,
      listingReadRepository: _BoundaryListingReader(),
      verification: _BoundaryVerification(),
    );
  }

  Future<MarketplacePublishResult> publish(
    MarketplacePublishService target, {
    required String title,
    required String description,
  }) {
    return target.publish(
      ownerId: 'boundary-owner',
      title: title,
      description: description,
      category: 'Jardinage',
      city: 'Sainte-Anne',
      postalCode: '97180',
      phone: '0690123456',
      subCategory: null,
      missionDelay: null,
      isUrgent: false,
      price: 20,
      budgetType: 'fixed',
      photos: const <XFile>[],
    );
  }

  test('accepte exactement la longueur minimale du titre et de la description',
      () async {
    final repository = _BoundaryListingRepository();

    final result = await publish(
      service(repository),
      title: '12345678',
      description: '12345678901234567890',
    );

    expect(result.listingId, 'boundary-listing');
    expect(repository.drafts, hasLength(1));
    expect(repository.drafts.single.title, '12345678');
    expect(repository.drafts.single.description, '12345678901234567890');
  });

  test('la validation utilise les valeurs nettoyées sans modifier le brouillon',
      () async {
    final repository = _BoundaryListingRepository();

    final result = await publish(
      service(repository),
      title: '  Titre valide  ',
      description: '  Description suffisamment longue pour être valide.  ',
    );

    expect(result.listingId, 'boundary-listing');
    expect(repository.drafts.single.title, '  Titre valide  ');
    expect(
      repository.drafts.single.description,
      '  Description suffisamment longue pour être valide.  ',
    );
  });
}

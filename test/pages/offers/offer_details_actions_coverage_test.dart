import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/offers/offer_details_page.dart';

class _SignedOutActionsAuthPlatform extends FirebaseAuthPlatform {
  _SignedOutActionsAuthPlatform() : super(appInstance: null);

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) => this;

  @override
  UserPlatform? get currentUser => null;

  @override
  Stream<UserPlatform?> authStateChanges() => Stream<UserPlatform?>.value(null);

  @override
  Stream<UserPlatform?> idTokenChanges() => Stream<UserPlatform?>.value(null);

  @override
  Stream<UserPlatform?> userChanges() => Stream<UserPlatform?>.value(null);
}

Map<String, dynamic> _marketplaceOffer() {
  return <String, dynamic>{
    'id': 'listing-actions-1',
    'listingId': 'listing-actions-1',
    'isMarketplace': true,
    'title': 'Montage meuble Pointe-à-Pitre 97110',
    'detail': 'Montage d’une armoire deux portes',
    'description': 'Je cherche une personne pour monter une armoire.',
    'city': 'Pointe-à-Pitre',
    'postalCode': '97110',
    'category': 'Bricolage',
    'categoryId': 'bricolage',
    'cityId': '97110_pointe-a-pitre',
    'userId': 'advertiser-actions-1',
    'phone': '0690123456',
    'budget': 75,
    'publishedAt': DateTime(2026, 8, 14, 18, 30),
    'availability': 'Cette semaine',
    'status': 'active',
    'visibility': 'public',
    'moderationStatus': 'approved',
    'mediaProcessingStatus': 'completed',
    'imageUrls': <String>['https://example.invalid/actions.jpg'],
    'media': <Map<String, dynamic>>[
      <String, dynamic>{'downloadUrl': 'https://example.invalid/actions.jpg'},
    ],
    'advertiser': <String, dynamic>{
      'id': 'advertiser-actions-1',
      'name': 'Alex Test',
      'verified': true,
      'rating': 4.9,
      'reviewsCount': 12,
      'avatarUrl': '',
    },
    'practicalInfo': <String, dynamic>{
      'serviceArea': 'Pointe-à-Pitre et alentours',
      'canTravel': true,
      'schedule': 'À convenir',
      'missionDelay': 'Sous 3 jours',
      'paymentMethod': 'À convenir entre utilisateurs',
      'serviceType': 'Mission ponctuelle',
    },
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseAuthPlatform originalAuthPlatform;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    originalAuthPlatform = FirebaseAuthPlatform.instance;
    FirebaseAuthPlatform.instance = _SignedOutActionsAuthPlatform();
  });

  tearDownAll(() {
    FirebaseAuthPlatform.instance = originalAuthPlatform;
  });

  Future<void> pumpOffer(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: OfferDetailsPage(
          offer: _marketplaceOffer(),
          currentUserId: 'guest-actions',
        ),
      ),
    );
    for (var i = 0; i < 6; i += 1) {
      await tester.pump(const Duration(milliseconds: 80));
    }
  }

  testWidgets('signalement marketplace demande une connexion puis peut être annulé',
      (tester) async {
    await pumpOffer(tester);

    expect(find.byTooltip('Signaler'), findsOneWidget);
    await tester.tap(find.byTooltip('Signaler'));
    await tester.pump();

    expect(
      find.text('Connectez-vous pour signaler cette annonce'),
      findsOneWidget,
    );
    expect(find.text('Je me connecte'), findsOneWidget);
    expect(find.text('Je crée mon compte'), findsOneWidget);

    final later = find.text('Plus tard');
    expect(later, findsOneWidget);
    await tester.ensureVisible(later);
    await tester.pump();
    await tester.tap(later);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('contact puis appel signed-out traverse les deux feuilles locales',
      (tester) async {
    await pumpOffer(tester);

    final contactCta = find.text('Proposer mes services').last;
    expect(contactCta, findsOneWidget);
    await tester.ensureVisible(contactCta);
    await tester.pump();
    await tester.tap(contactCta);
    await tester.pump();

    expect(find.text('Proposer mes services'), findsWidgets);
    expect(find.text('Envoyer un message'), findsOneWidget);

    final callCta = find.text('Appeler');
    expect(callCta, findsOneWidget);
    await tester.ensureVisible(callCta);
    await tester.pump();
    await tester.tap(callCta);
    await tester.pump();

    expect(
      find.text("Connectez-vous pour appeler l'annonceur"),
      findsOneWidget,
    );

    final callLater = find.text('Plus tard');
    expect(callLater, findsOneWidget);
    await tester.ensureVisible(callLater);
    await tester.pump();
    await tester.tap(callLater);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/offers/offer_details_page.dart';

class _SignedOutOfferAuthPlatform extends FirebaseAuthPlatform {
  _SignedOutOfferAuthPlatform() : super(appInstance: null);

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({InternalUserDetails? currentUser, String? languageCode}) => this;

  @override
  UserPlatform? get currentUser => null;

  @override
  Stream<UserPlatform?> authStateChanges() => Stream<UserPlatform?>.value(null);

  @override
  Stream<UserPlatform?> idTokenChanges() => Stream<UserPlatform?>.value(null);

  @override
  Stream<UserPlatform?> userChanges() => Stream<UserPlatform?>.value(null);
}

Map<String, dynamic> _offer({bool marketplace = false, Object budget = 85, String budgetLabel = '', String status = 'active', String mediaProcessingStatus = 'completed'}) {
  return <String, dynamic>{
    'id': marketplace ? 'listing-memory-1' : 'offer-memory-1',
    'listingId': marketplace ? 'listing-memory-1' : 'offer-memory-1',
    'isMarketplace': marketplace,
    'title': 'Peinture chambre Basse-Terre 97100',
    'detail': 'Mur intérieur et plafond',
    'description': 'Je cherche une personne pour repeindre une chambre.',
    'city': 'Basse-Terre',
    'postalCode': '97100',
    'category': 'Peinture',
    'categoryId': marketplace ? 'peinture' : '',
    'cityId': marketplace ? '97100_basse-terre' : '',
    'userId': 'advertiser-memory-1',
    'phone': '0690123456',
    'budget': budget,
    'budgetLabel': budgetLabel,
    'publishedAt': DateTime(2026, 8, 12, 14, 35),
    'publishedAtLabel': 'Aujourd’hui',
    'availability': 'Cette semaine',
    'status': status,
    'visibility': marketplace ? 'public' : '',
    'moderationStatus': marketplace ? 'pending' : '',
    'mediaProcessingStatus': mediaProcessingStatus,
    'imageUrls': <String>['https://example.invalid/offer-memory.jpg'],
    'media': <Map<String, dynamic>>[<String, dynamic>{'downloadUrl': 'https://example.invalid/offer-memory.jpg'}],
    'statusBadges': <String>['Urgent'],
    'isUrgent': true,
    'viewCount': 12,
    'phoneViewCount': 3,
    'advertiser': <String, dynamic>{
      'id': 'advertiser-memory-1', 'name': 'Marie Test', 'role': 'Particulier', 'verified': true,
      'rating': 4.8, 'reviewsCount': 7, 'city': 'Basse-Terre',
      'bio': 'Disponible pour échanger sur la mission.', 'avatarUrl': '', 'isOnline': true, 'lastSeenLabel': 'En ligne',
    },
    'practicalInfo': <String, dynamic>{
      'serviceArea': 'Basse-Terre et alentours', 'canTravel': true, 'schedule': 'À convenir',
      'missionDelay': 'Sous 7 jours', 'averageDelay': 'Réponse rapide',
      'paymentMethod': 'À convenir entre utilisateurs', 'serviceType': 'Mission ponctuelle',
    },
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    FirebaseAuthPlatform.instance = _SignedOutOfferAuthPlatform();
  });

  Future<void> pumpOffer(WidgetTester tester, Map<String, dynamic> offer) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: OfferDetailsPage(offer: offer, currentUserId: 'guest-memory')));
    for (var i = 0; i < 6; i += 1) {
      await tester.pump(const Duration(milliseconds: 80));
    }
  }

  testWidgets('rend une annonce complète en mémoire et ouvre les actions locales', (tester) async {
    await pumpOffer(tester, _offer());
    expect(find.text('Détail annonce'), findsOneWidget);
    expect(find.text('PEINTURE CHAMBRE'), findsOneWidget);
    expect(find.text('Basse-Terre 97100'), findsOneWidget);
    expect(find.text('Mur intérieur et plafond'), findsOneWidget);
    expect(find.text('Marie Test'), findsWidgets);
    expect(find.byTooltip('Partager'), findsOneWidget);
    expect(find.byTooltip('Ajouter aux favoris'), findsOneWidget);

    await tester.tap(find.byTooltip('Partager'));
    await tester.pump();
    expect(find.text("Partager l'annonce"), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('Facebook'), findsOneWidget);
    expect(find.text('Instagram'), findsOneWidget);
    expect(find.text('Mail'), findsOneWidget);
    Navigator.of(tester.element(find.text("Partager l'annonce"))).pop();
    await tester.pump();

    await tester.tap(find.byTooltip('Ajouter aux favoris'));
    await tester.pump();
    expect(find.text('Connectez-vous pour enregistrer cette annonce'), findsOneWidget);
    expect(find.text('Je me connecte'), findsOneWidget);
    expect(find.text('Je crée mon compte'), findsOneWidget);
    expect(find.text('Plus tard'), findsOneWidget);
    await tester.tap(find.text('Plus tard'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('masque un budget nul ou négociable sans hydrater Firestore', (tester) async {
    await pumpOffer(tester, _offer(budget: 0, budgetLabel: 'À négocier'));
    expect(find.text('Détail annonce'), findsOneWidget);
    expect(find.text('PEINTURE CHAMBRE'), findsOneWidget);
    expect(find.text('0 €'), findsNothing);
    expect(find.byTooltip('Partager'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rend les états Marketplace photo en traitement depuis la map locale', (tester) async {
    await pumpOffer(tester, _offer(marketplace: true, status: 'pending', mediaProcessingStatus: 'processing'));
    expect(find.text('Détail annonce'), findsOneWidget);
    expect(find.byTooltip('Signaler'), findsOneWidget);
    expect(find.text('PEINTURE CHAMBRE'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

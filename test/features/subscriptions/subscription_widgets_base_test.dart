import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/subscriptions/subscription_models.dart';
import 'package:presto_app/features/subscriptions/subscription_widgets_base.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const enabledConfig = SubscriptionAppConfig(
    subscriptionSectionEnabled: true,
    subscriptionsPrepared: true,
    stripeEnabled: false,
    freeAccessMode: false,
  );

  AppUserSubscriptionState state(SubscriptionPlan plan) {
    return AppUserSubscriptionState(
      plan: plan,
      status: SubscriptionStatus.active,
      subscriptionExpiresAt: null,
      phoneVerified: true,
      proVerified: plan == SubscriptionPlan.ilipro,
    );
  }

  Widget app(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: child,
          ),
        ),
      ),
    );
  }

  setUp(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
        .physicalSize = const Size(1200, 3000);
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
        .devicePixelRatio = 1;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
        .resetPhysicalSize();
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
        .resetDevicePixelRatio();
  });

  testWidgets('la carte actuelle affiche la formule gratuite', (tester) async {
    await tester.pumpWidget(
      app(
        SubscriptionCurrentStatusCard(
          userId: 'user-1',
          userState: state(SubscriptionPlan.free),
          config: enabledConfig,
          showDetailsButton: false,
        ),
      ),
    );

    expect(find.text('OFFRE ACTUELLE'), findsOneWidget);
    expect(find.text('✓ Actif'), findsOneWidget);
    expect(find.text('Gratuit'), findsOneWidget);
    expect(find.text('0 €/mois'), findsOneWidget);
    expect(find.text('Publier et consulter des annonces'), findsOneWidget);
    expect(find.text('Découvrir les autres offres'), findsNothing);
  });

  testWidgets('la carte actuelle affiche ilipresto+ et son bouton détail', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        SubscriptionCurrentStatusCard(
          userId: 'user-2',
          userState: state(SubscriptionPlan.iliprestoPlus),
          config: enabledConfig,
        ),
      ),
    );

    expect(find.text('iliprestō+'), findsOneWidget);
    expect(find.text('1,99 €/mois'), findsOneWidget);
    expect(find.text('2 exports PDF par mois'), findsOneWidget);
    expect(find.text('Découvrir les autres offres'), findsOneWidget);
  });

  testWidgets('la carte actuelle affiche les avantages ilipro', (tester) async {
    await tester.pumpWidget(
      app(
        SubscriptionCurrentStatusCard(
          userId: 'user-3',
          userState: state(SubscriptionPlan.ilipro),
          config: enabledConfig,
          showDetailsButton: false,
        ),
      ),
    );

    expect(find.text('ilipro'), findsOneWidget);
    expect(find.text('9,99 €/mois'), findsOneWidget);
    expect(find.text('Visibilité professionnelle renforcée'), findsOneWidget);
    expect(find.text('Statistiques et profil professionnel enrichi'), findsOneWidget);
  });

  testWidgets('les onglets particuliers masquent la formule professionnelle', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        SubscriptionPlanTabs(
          config: enabledConfig,
          userState: state(SubscriptionPlan.free),
          audience: OfferAudience.particuliers,
        ),
      ),
    );

    expect(find.text('Gratuit'), findsNothing);
    expect(find.text('iliprestō+'), findsOneWidget);
    expect(find.text('Particuliers'), findsOneWidget);
    expect(find.text('Choisir iliprestō+'), findsOneWidget);
    expect(find.text('ilipro'), findsNothing);
  });

  testWidgets('showCurrentPlan rend la formule actuelle désactivée', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        SubscriptionPlanTabs(
          config: enabledConfig,
          userState: state(SubscriptionPlan.iliprestoPlus),
          showCurrentPlan: true,
          audience: OfferAudience.particuliers,
        ),
      ),
    );

    expect(find.text('Gratuit'), findsOneWidget);
    expect(find.text('iliprestō+'), findsOneWidget);
    expect(find.text('ACTUELLE'), findsOneWidget);
    expect(find.text('Offre actuelle'), findsOneWidget);
    expect(find.text('Choisir Gratuit'), findsOneWidget);
  });

  testWidgets('les onglets pro n affichent que la formule ilipro', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        SubscriptionPlanTabs(
          config: enabledConfig,
          userState: state(SubscriptionPlan.free),
          audience: OfferAudience.pro,
        ),
      ),
    );

    expect(find.text('ilipro'), findsOneWidget);
    expect(find.text('Professionnels'), findsOneWidget);
    expect(find.text('Choisir ilipro'), findsOneWidget);
    expect(find.text('Gratuit'), findsNothing);
    expect(find.text('iliprestō+'), findsNothing);
  });
}

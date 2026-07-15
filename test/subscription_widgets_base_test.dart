import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/subscriptions/subscription_models.dart';
import 'package:presto_app/features/subscriptions/subscription_widgets_base.dart';

const _config = SubscriptionAppConfig(
  subscriptionSectionEnabled: true,
  subscriptionsPrepared: true,
  stripeEnabled: false,
  freeAccessMode: false,
);

AppUserSubscriptionState _state(SubscriptionPlan plan) {
  return AppUserSubscriptionState(
    plan: plan,
    status: SubscriptionStatus.active,
    subscriptionExpiresAt: null,
    phoneVerified: true,
    proVerified: plan == SubscriptionPlan.ilipro,
  );
}

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: child,
      ),
    ),
  );
}

void main() {
  testWidgets('current status cards render every plan presentation',
      (tester) async {
    await tester.pumpWidget(
      _host(
        Column(
          children: [
            SubscriptionCurrentStatusCard(
              userId: 'free-user',
              userState: _state(SubscriptionPlan.free),
              config: _config,
              showDetailsButton: false,
            ),
            const SizedBox(height: 20),
            SubscriptionCurrentStatusCard(
              userId: 'plus-user',
              userState: _state(SubscriptionPlan.iliprestoPlus),
              config: _config,
              showDetailsButton: false,
            ),
            const SizedBox(height: 20),
            SubscriptionCurrentStatusCard(
              userId: 'pro-user',
              userState: _state(SubscriptionPlan.ilipro),
              config: _config,
              showDetailsButton: false,
            ),
          ],
        ),
      ),
    );

    expect(find.text('OFFRE ACTUELLE'), findsNWidgets(3));
    expect(find.text('✓ Actif'), findsNWidgets(3));
    expect(find.text('Gratuit'), findsOneWidget);
    expect(find.text('0 €/mois'), findsOneWidget);
    expect(find.text('iliprestō+'), findsOneWidget);
    expect(find.text('1,99 €/mois'), findsOneWidget);
    expect(find.text('ilipro'), findsOneWidget);
    expect(find.text('9,99 €/mois'), findsOneWidget);
    expect(find.text('Découvrir les autres offres'), findsNothing);
    expect(find.byIcon(Icons.check_circle_rounded), findsAtLeastNWidgets(10));
  });

  testWidgets('current status card exposes the details navigation action',
      (tester) async {
    await tester.pumpWidget(
      _host(
        SubscriptionCurrentStatusCard(
          userId: 'free-user',
          userState: _state(SubscriptionPlan.free),
          config: _config,
        ),
      ),
    );

    expect(find.text('Découvrir les autres offres'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('particular plan tabs filter current plan and show launch notice',
      (tester) async {
    await tester.pumpWidget(
      _host(
        SubscriptionPlanTabs(
          config: _config,
          userState: _state(SubscriptionPlan.free),
          audience: OfferAudience.particuliers,
        ),
      ),
    );

    expect(find.text('Gratuit'), findsNothing);
    expect(find.text('iliprestō+'), findsOneWidget);
    expect(find.text('Particuliers'), findsOneWidget);
    expect(find.text('Choisir iliprestō+'), findsOneWidget);
    expect(find.text('ilipro'), findsNothing);
    expect(find.text('2 exports PDF par mois'), findsOneWidget);

    await tester.tap(find.text('Choisir iliprestō+'));
    await tester.pump();
    expect(
      find.text('Vous serez informé lorsque cette formule sera disponible.'),
      findsOneWidget,
    );
  });

  testWidgets('plan tabs can include the current free plan', (tester) async {
    await tester.pumpWidget(
      _host(
        SubscriptionPlanTabs(
          config: _config,
          userState: _state(SubscriptionPlan.free),
          audience: OfferAudience.particuliers,
          showCurrentPlan: true,
        ),
      ),
    );

    expect(find.text('Gratuit'), findsOneWidget);
    expect(find.text('iliprestō+'), findsOneWidget);
    expect(find.text('ACTUELLE'), findsOneWidget);
    expect(find.text('Offre actuelle'), findsOneWidget);
    final disabled = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(disabled.onPressed, isNull);
  });

  testWidgets('professional plan tabs only display ilipro', (tester) async {
    await tester.pumpWidget(
      _host(
        SubscriptionPlanTabs(
          config: _config,
          userState: _state(SubscriptionPlan.free),
          audience: OfferAudience.pro,
          showCurrentPlan: true,
        ),
      ),
    );

    expect(find.text('ilipro'), findsOneWidget);
    expect(find.text('Professionnels'), findsOneWidget);
    expect(find.text('Choisir ilipro'), findsOneWidget);
    expect(find.text('Gratuit'), findsNothing);
    expect(find.text('iliprestō+'), findsNothing);
    expect(find.text('Profil professionnel enrichi'), findsOneWidget);
  });

  testWidgets('current plus and pro plans display their active badges',
      (tester) async {
    await tester.pumpWidget(
      _host(
        Column(
          children: [
            SubscriptionPlanTabs(
              config: _config,
              userState: _state(SubscriptionPlan.iliprestoPlus),
              audience: OfferAudience.particuliers,
              showCurrentPlan: true,
            ),
            const SizedBox(height: 20),
            SubscriptionPlanTabs(
              config: _config,
              userState: _state(SubscriptionPlan.ilipro),
              audience: OfferAudience.pro,
              showCurrentPlan: true,
            ),
          ],
        ),
      ),
    );

    expect(find.text('ACTUELLE'), findsNWidgets(2));
    expect(find.text('Offre actuelle'), findsNWidgets(2));
    expect(find.byType(OutlinedButton), findsNWidgets(2));
  });
}

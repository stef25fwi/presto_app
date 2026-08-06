import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/subscriptions/subscription_credit_service.dart';
import 'package:presto_app/features/subscriptions/subscription_credits_card.dart';

void main() {
  Widget buildBadge(SubscriptionCreditStatus status) {
    return MaterialApp(
      home: Scaffold(
        body: SubscriptionCreditBadge(
          label: 'IA texte',
          status: status,
        ),
      ),
    );
  }

  testWidgets('affiche le badge illimité', (tester) async {
    await tester.pumpWidget(
      buildBadge(
        const SubscriptionCreditStatus(
          used: 0,
          limit: 0,
          remaining: 0,
          unlimited: true,
          exhausted: false,
        ),
      ),
    );

    expect(find.text('IA texte · ∞'), findsOneWidget);
  });

  testWidgets('affiche le badge non inclus', (tester) async {
    await tester.pumpWidget(
      buildBadge(
        const SubscriptionCreditStatus(
          used: 0,
          limit: 0,
          remaining: 0,
          unlimited: false,
          exhausted: false,
        ),
      ),
    );

    expect(find.text('IA texte · 0'), findsOneWidget);
  });

  testWidgets('affiche le badge épuisé', (tester) async {
    await tester.pumpWidget(
      buildBadge(
        const SubscriptionCreditStatus(
          used: 5,
          limit: 5,
          remaining: 0,
          unlimited: false,
          exhausted: true,
        ),
      ),
    );

    expect(find.text('IA texte · 0/5'), findsOneWidget);
  });

  testWidgets('affiche les crédits restants', (tester) async {
    await tester.pumpWidget(
      buildBadge(
        const SubscriptionCreditStatus(
          used: 2,
          limit: 10,
          remaining: 8,
          unlimited: false,
          exhausted: false,
        ),
      ),
    );

    expect(find.text('IA texte · 8/10'), findsOneWidget);
  });
}

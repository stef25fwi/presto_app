import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/subscriptions/subscription_credit_service.dart';
import 'package:presto_app/features/subscriptions/subscription_credits_card.dart';

class _FakeCreditService extends SubscriptionCreditService {
  _FakeCreditService(this.responses);

  final List<Future<SubscriptionCreditSnapshot>> responses;
  int calls = 0;

  @override
  Future<SubscriptionCreditSnapshot> getSnapshot() {
    final index = calls < responses.length ? calls : responses.length - 1;
    calls += 1;
    return responses[index];
  }
}

SubscriptionCreditStatus _status({
  int used = 0,
  int limit = 10,
  int remaining = 10,
  bool unlimited = false,
  bool exhausted = false,
}) {
  return SubscriptionCreditStatus(
    used: used,
    limit: limit,
    remaining: remaining,
    unlimited: unlimited,
    exhausted: exhausted,
  );
}

SubscriptionCreditSnapshot _snapshot({
  bool freeAccessMode = false,
  DateTime? nextResetAt,
}) {
  return SubscriptionCreditSnapshot(
    plan: 'ilipresto_plus',
    period: '2026-07',
    freeAccessMode: freeAccessMode,
    nextResetAt: nextResetAt,
    credits: {
      SubscriptionCreditKind.journeys: _status(used: 1, limit: 5, remaining: 4),
      SubscriptionCreditKind.pdf: _status(limit: 0, remaining: 0, exhausted: true),
      SubscriptionCreditKind.voiceAi: _status(used: 4, limit: 5, remaining: 1),
      SubscriptionCreditKind.textAi: _status(
        limit: 999999,
        remaining: 999999,
        unlimited: true,
      ),
      SubscriptionCreditKind.activeOffers: _status(
        used: 2,
        limit: 3,
        remaining: 1,
      ),
    },
  );
}

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(child: child),
    ),
  );
}

void main() {
  testWidgets('affiche le chargement puis les cinq crédits et leur état',
      (tester) async {
    final completer = Completer<SubscriptionCreditSnapshot>();
    final service = _FakeCreditService([completer.future]);

    await tester.pumpWidget(
      _host(SubscriptionCreditsCard(userId: 'user-1', service: service)),
    );

    expect(find.text('Chargement de vos crédits…'), findsOneWidget);
    expect(service.calls, 1);

    completer.complete(_snapshot(nextResetAt: DateTime(2026, 8, 1)));
    await tester.pumpAndSettle();

    expect(find.text('Mes crédits'), findsOneWidget);
    expect(find.text('Crédits mensuels renouvelés le 01/08.'), findsOneWidget);
    expect(find.text('Parcours'), findsOneWidget);
    expect(find.text('4 restants sur 5'), findsOneWidget);
    expect(find.text('PDF'), findsOneWidget);
    expect(find.text('Non inclus'), findsOneWidget);
    expect(find.text('IA vocale'), findsOneWidget);
    expect(find.text('1 restant sur 5'), findsOneWidget);
    expect(find.text('IA texte'), findsOneWidget);
    expect(find.text('Illimité'), findsOneWidget);
    expect(find.text('Annonces actives'), findsOneWidget);
  });

  testWidgets('affiche la période gratuite et actualise la carte',
      (tester) async {
    final service = _FakeCreditService([
      Future.value(_snapshot(freeAccessMode: true)),
      Future.value(_snapshot(nextResetAt: null)),
    ]);

    await tester.pumpWidget(
      _host(SubscriptionCreditsCard(userId: 'user-1', service: service)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Accès illimité pendant la période gratuite.'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Actualiser mes crédits'));
    await tester.pumpAndSettle();

    expect(service.calls, 2);
    expect(
      find.text('Crédits mensuels actualisés automatiquement.'),
      findsOneWidget,
    );
  });

  testWidgets('affiche une erreur puis recharge avec succès', (tester) async {
    final service = _FakeCreditService([
      Future<SubscriptionCreditSnapshot>.delayed(
        Duration.zero,
        () => throw StateError('réseau'),
      ),
      Future.value(_snapshot()),
    ]);

    await tester.pumpWidget(
      _host(SubscriptionCreditsCard(userId: 'user-1', service: service)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Impossible de charger vos crédits pour le moment.'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Réessayer'));
    await tester.pumpAndSettle();

    expect(service.calls, 2);
    expect(find.text('Parcours'), findsOneWidget);
  });

  testWidgets('recharge quand utilisateur ou service change', (tester) async {
    final first = _FakeCreditService([
      Future.value(_snapshot()),
      Future.value(_snapshot(freeAccessMode: true)),
    ]);
    final second = _FakeCreditService([Future.value(_snapshot())]);

    await tester.pumpWidget(
      _host(SubscriptionCreditsCard(userId: 'user-1', service: first)),
    );
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      _host(SubscriptionCreditsCard(userId: 'user-2', service: first)),
    );
    await tester.pumpAndSettle();
    expect(first.calls, 2);

    await tester.pumpWidget(
      _host(SubscriptionCreditsCard(userId: 'user-2', service: second)),
    );
    await tester.pumpAndSettle();
    expect(second.calls, 1);
  });

  testWidgets('les badges restent masqués pendant le chargement puis s’affichent',
      (tester) async {
    final completer = Completer<SubscriptionCreditSnapshot>();
    final service = _FakeCreditService([completer.future]);

    await tester.pumpWidget(
      _host(
        SubscriptionCreditsInlineBadges(
          kinds: const [
            SubscriptionCreditKind.journeys,
            SubscriptionCreditKind.pdf,
            SubscriptionCreditKind.voiceAi,
            SubscriptionCreditKind.textAi,
            SubscriptionCreditKind.activeOffers,
          ],
          service: service,
        ),
      ),
    );

    expect(find.byType(SubscriptionCreditBadge), findsNothing);

    completer.complete(_snapshot());
    await tester.pumpAndSettle();

    expect(find.byType(SubscriptionCreditBadge), findsNWidgets(5));
    expect(find.text('Parcours · 4/5'), findsOneWidget);
    expect(find.text('PDF · 0'), findsOneWidget);
    expect(find.text('IA vocale · 1/5'), findsOneWidget);
    expect(find.text('IA texte · ∞'), findsOneWidget);
    expect(find.text('Annonces · 1/3'), findsOneWidget);
  });

  testWidgets('les badges utilisent le nouveau service après mise à jour',
      (tester) async {
    final first = _FakeCreditService([Future.value(_snapshot())]);
    final second = _FakeCreditService([Future.value(_snapshot(freeAccessMode: true))]);

    await tester.pumpWidget(
      _host(
        SubscriptionCreditsInlineBadges(
          kinds: const [SubscriptionCreditKind.textAi],
          service: first,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(first.calls, 1);

    await tester.pumpWidget(
      _host(
        SubscriptionCreditsInlineBadges(
          kinds: const [SubscriptionCreditKind.textAi],
          service: second,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(second.calls, 1);
    expect(find.text('IA texte · ∞'), findsOneWidget);
  });

  testWidgets('un badge autonome rend son libellé compact', (tester) async {
    await tester.pumpWidget(
      _host(
        SubscriptionCreditBadge(
          label: 'PDF',
          status: _status(used: 2, limit: 5, remaining: 3),
        ),
      ),
    );

    expect(find.text('PDF · 3/5'), findsOneWidget);
  });
}

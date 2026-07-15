import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/admin/messaging/widgets/admin_messaging_stat_card.dart';

Widget _host(AdminMessagingStatCard card) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(width: 260, child: card),
    ),
  );
}

void main() {
  testWidgets('renders a static statistics card without action affordance',
      (tester) async {
    await tester.pumpWidget(
      _host(
        const AdminMessagingStatCard(
          title: 'Conversations ouvertes',
          value: '24',
          subtitle: 'Sur les 7 derniers jours',
          icon: Icons.forum_rounded,
          color: Colors.blue,
        ),
      ),
    );

    expect(find.text('24'), findsOneWidget);
    expect(find.text('Conversations ouvertes'), findsOneWidget);
    expect(find.text('Sur les 7 derniers jours'), findsOneWidget);
    expect(find.byIcon(Icons.forum_rounded), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new_rounded), findsNothing);
    expect(find.byType(InkWell), findsNothing);

    final value = tester.widget<Text>(find.text('24'));
    final title = tester.widget<Text>(find.text('Conversations ouvertes'));
    final subtitle =
        tester.widget<Text>(find.text('Sur les 7 derniers jours'));
    final icon = tester.widget<Icon>(find.byIcon(Icons.forum_rounded));

    expect(value.style?.fontSize, 28);
    expect(value.style?.fontWeight, FontWeight.w900);
    expect(title.style?.fontSize, 15);
    expect(title.style?.fontWeight, FontWeight.w800);
    expect(subtitle.style?.fontSize, 13);
    expect(subtitle.style?.height, 1.35);
    expect(icon.color, Colors.blue);
  });

  testWidgets('renders an actionable card and forwards the tap',
      (tester) async {
    var tapCount = 0;

    await tester.pumpWidget(
      _host(
        AdminMessagingStatCard(
          title: 'Signalements',
          value: '3',
          subtitle: 'À modérer',
          icon: Icons.flag_rounded,
          color: Colors.red,
          onTap: () => tapCount++,
        ),
      ),
    );

    expect(find.byType(InkWell), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new_rounded), findsOneWidget);

    final actionIcon =
        tester.widget<Icon>(find.byIcon(Icons.open_in_new_rounded));
    final inkWell = tester.widget<InkWell>(find.byType(InkWell));
    expect(actionIcon.color, Colors.red);
    expect(actionIcon.size, 18);
    expect(inkWell.borderRadius, BorderRadius.circular(20));

    await tester.tap(find.byType(InkWell));
    expect(tapCount, 1);
  });
}

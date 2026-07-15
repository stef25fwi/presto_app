import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/widgets/home_bottom_nav_item.dart';

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(
      backgroundColor: Colors.blue,
      body: Center(child: child),
    ),
  );
}

void main() {
  testWidgets('renders the default item and forwards taps', (tester) async {
    var tapCount = 0;

    await tester.pumpWidget(
      _host(
        HomeBottomNavItem(
          icon: Icons.home,
          label: 'Accueil',
          onTap: () => tapCount++,
        ),
      ),
    );

    expect(find.text('Accueil'), findsOneWidget);
    expect(find.byIcon(Icons.home), findsOneWidget);
    expect(find.text('0'), findsNothing);

    final icon = tester.widget<Icon>(find.byIcon(Icons.home));
    final label = tester.widget<Text>(find.text('Accueil'));
    expect(icon.size, 27);
    expect(icon.color, Colors.white);
    expect(label.style?.fontSize, 10);
    expect(label.style?.fontWeight, FontWeight.w500);

    await tester.tap(find.byType(HomeBottomNavItem));
    expect(tapCount, 1);
  });

  testWidgets('renders selected styling and a positive badge', (tester) async {
    await tester.pumpWidget(
      _host(
        HomeBottomNavItem(
          icon: Icons.chat_bubble,
          label: 'Messages',
          selected: true,
          badgeCount: 12,
          onTap: () {},
        ),
      ),
    );

    expect(find.text('12'), findsOneWidget);
    final label = tester.widget<Text>(find.text('Messages'));
    final badge = tester.widget<Text>(find.text('12'));
    expect(label.style?.fontWeight, FontWeight.w700);
    expect(badge.style?.fontSize, 10);
    expect(badge.style?.fontWeight, FontWeight.w800);
    expect(badge.style?.color, Colors.white);
  });

  testWidgets('renders the large central item with Presto styling',
      (tester) async {
    await tester.pumpWidget(
      _host(
        HomeBottomNavItem(
          icon: Icons.add,
          label: 'Publier',
          isBig: true,
          badgeCount: -1,
          onTap: () {},
        ),
      ),
    );

    final icon = tester.widget<Icon>(find.byIcon(Icons.add));
    final label = tester.widget<Text>(find.text('Publier'));
    expect(icon.size, 32);
    expect(icon.color, const Color(0xFFFF6600));
    expect(label.style?.fontSize, 10.5);
    expect(find.text('-1'), findsNothing);
  });

  testWidgets('animates when selection becomes active and disposes cleanly',
      (tester) async {
    const key = ValueKey<String>('animated-nav-item');
    final transitionFinder = find.descendant(
      of: find.byKey(key),
      matching: find.byType(ScaleTransition),
    );

    await tester.pumpWidget(
      _host(
        HomeBottomNavItem(
          key: key,
          icon: Icons.explore,
          label: 'Explorer',
          onTap: () {},
        ),
      ),
    );

    expect(transitionFinder, findsOneWidget);
    ScaleTransition transition =
        tester.widget<ScaleTransition>(transitionFinder);
    expect(transition.scale.value, 1.0);

    await tester.pumpWidget(
      _host(
        HomeBottomNavItem(
          key: key,
          icon: Icons.explore,
          label: 'Explorer',
          selected: true,
          onTap: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    transition = tester.widget<ScaleTransition>(transitionFinder);
    expect(transition.scale.value, greaterThan(1.0));

    await tester.pump(const Duration(milliseconds: 300));
    transition = tester.widget<ScaleTransition>(transitionFinder);
    expect(transition.scale.value, closeTo(1.0, 0.001));

    await tester.pumpWidget(_host(const SizedBox.shrink()));
    expect(tester.takeException(), isNull);
  });
}

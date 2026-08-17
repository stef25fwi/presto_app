import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/widgets/entrepreneur_toolbox_slide.dart';
import 'package:presto_app/widgets/presto_info_icon_animated.dart';

class _NavigatorObserver extends NavigatorObserver {
  int pushCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushCount++;
    super.didPush(route, previousRoute);
  }
}

Widget _host({
  required double height,
  NavigatorObserver? observer,
}) {
  return MaterialApp(
    navigatorObservers: observer == null
        ? const <NavigatorObserver>[]
        : <NavigatorObserver>[observer],
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 600,
          height: height,
          child: const EntrepreneurToolboxSlide(),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders compact toolbox slide and opens the toolbox route',
      (tester) async {
    final observer = _NavigatorObserver();
    await tester.pumpWidget(_host(height: 120, observer: observer));
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text("Boite a outils de l'entrepreneur"), findsOneWidget);
    expect(find.text('Cliquez ici'), findsOneWidget);
    expect(find.byType(PrestoInfoIconAnimated), findsNothing);
    expect(observer.pushCount, 1);

    final rootGesture = tester.widget<InkWell>(
      find.ancestor(
        of: find.text("Boite a outils de l'entrepreneur"),
        matching: find.byType(InkWell),
      ).first,
    );
    expect(rootGesture.onTap, isNotNull);
    rootGesture.onTap!();
    await tester.pump();
    expect(observer.pushCount, 2);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('renders hero toolbox slide above the compact breakpoint',
      (tester) async {
    await tester.pumpWidget(_host(height: 300));
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('PRO'), findsOneWidget);
    expect(find.text("Boite a outils de\nl'entrepreneur"), findsOneWidget);
    expect(
      find.text('Liens utiles CCI, Region, aides et infos cles.'),
      findsOneWidget,
    );
    expect(find.byType(PrestoInfoIconAnimated), findsOneWidget);
    expect(find.text('I'), findsOneWidget);
    expect(EntrepreneurToolboxSlide.kPrestoOrange,
        const Color(0xFFFF6600));
    expect(EntrepreneurToolboxSlide.kPrestoBlue, const Color(0xFF1A73E8));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('uses the compact variant exactly at 130 pixels',
      (tester) async {
    await tester.pumpWidget(_host(height: 130));
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text("Boite a outils de l'entrepreneur"), findsOneWidget);
    expect(find.text('PRO'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

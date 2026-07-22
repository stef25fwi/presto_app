import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/offers/widgets/animated_payment_info_pill.dart';

const _containerKey = ValueKey<String>('payment-info-pill-container');
const _textStyleKey = ValueKey<String>('payment-info-pill-text-style');

Widget _host(VoidCallback onTap) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: AnimatedPaymentInfoPill(onTap: onTap),
        ),
      ),
    ),
  );
}

Finder _infosTextFinder() {
  return find.descendant(
    of: find.byType(AnimatedPaymentInfoPill),
    matching: find.text('Infos'),
  );
}

BoxDecoration _decoration(WidgetTester tester) {
  final container =
      tester.widget<AnimatedContainer>(find.byKey(_containerKey));
  return container.decoration! as BoxDecoration;
}

void main() {
  testWidgets('has no blue shadow and becomes light gray on hover',
      (tester) async {
    var tapCount = 0;
    await tester.pumpWidget(_host(() => tapCount++));

    BoxDecoration decoration = _decoration(tester);
    expect(decoration.boxShadow, isNull);
    expect(
      (decoration.gradient! as LinearGradient).colors,
      const [Color(0xFF1A73E8), Color(0xFF0D5FD1)],
    );

    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(tester.getCenter(_infosTextFinder()));
    await tester.pump();

    decoration = _decoration(tester);
    expect(decoration.boxShadow, isNull);
    expect(
      (decoration.gradient! as LinearGradient).colors,
      const [Color(0xFFE8EAEE), Color(0xFFDDE1E7)],
    );

    final textStyle = tester
        .widget<AnimatedDefaultTextStyle>(find.byKey(_textStyleKey))
        .style;
    expect(textStyle.color, const Color(0xFF303846));

    await tester.tap(_infosTextFinder());
    expect(tapCount, 1);

    await gesture.moveTo(Offset.zero);
    await tester.pump();

    decoration = _decoration(tester);
    expect(
      (decoration.gradient! as LinearGradient).colors,
      const [Color(0xFF1A73E8), Color(0xFF0D5FD1)],
    );

    await gesture.removePointer();
  });
}

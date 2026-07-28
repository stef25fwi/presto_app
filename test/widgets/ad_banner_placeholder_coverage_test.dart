import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/widgets/ad_banner.dart';

class _PlaceholderCapture {
  String? folder;
  BorderRadius? radius;
  Duration? interval;
  int? antiRepeatWindow;
  bool? enabled;

  Widget build({
    required String fallbackFolderPrefix,
    required BorderRadius borderRadius,
    required Duration interval,
    required int antiRepeatWindow,
    required bool enabled,
  }) {
    folder = fallbackFolderPrefix;
    radius = borderRadius;
    this.interval = interval;
    this.antiRepeatWindow = antiRepeatWindow;
    this.enabled = enabled;
    return const SizedBox(key: ValueKey<String>('captured-placeholder'));
  }
}

void main() {
  testWidgets('renders the standard placeholder while ads are disabled', (
    tester,
  ) async {
    const margin = EdgeInsets.all(12);
    final capture = _PlaceholderCapture();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdBanner(
            enabled: false,
            margin: margin,
            placeholderFolderPrefix: 'assets/test_ads/',
            animatePlaceholder: false,
            placeholderBuilder: capture.build,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('captured-placeholder')),
      findsOneWidget,
    );
    expect(capture.folder, 'assets/test_ads/');
    expect(capture.radius, BorderRadius.circular(6));
    expect(capture.interval, const Duration(seconds: 4));
    expect(capture.antiRepeatWindow, 3);
    expect(capture.enabled, isFalse);

    final containers = tester.widgetList<Container>(find.byType(Container));
    expect(containers.any((container) => container.margin == margin), isTrue);
  });

  testWidgets('renders the flat full-width placeholder variant', (tester) async {
    final capture = _PlaceholderCapture();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdBanner(
            enabled: false,
            flat: true,
            animatePlaceholder: false,
            placeholderBuilder: capture.build,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('captured-placeholder')),
      findsOneWidget,
    );
    expect(capture.folder, 'assets/carousel_home/');
    expect(capture.radius, BorderRadius.circular(18));
    expect(capture.interval, const Duration(seconds: 4));
    expect(capture.antiRepeatWindow, 0);
    expect(capture.enabled, isFalse);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/widgets/ad_banner.dart';
import 'package:presto_app/widgets/managed_ad_placeholder_ticker.dart';

void main() {
  testWidgets('renders the standard placeholder while ads are disabled', (
    tester,
  ) async {
    const margin = EdgeInsets.all(12);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdBanner(
            enabled: false,
            margin: margin,
            placeholderFolderPrefix: 'assets/test_ads/',
            animatePlaceholder: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(ManagedAdPlaceholderTicker), findsOneWidget);
    final ticker = tester.widget<ManagedAdPlaceholderTicker>(
      find.byType(ManagedAdPlaceholderTicker),
    );
    expect(ticker.fallbackFolderPrefix, 'assets/test_ads/');
    expect(ticker.enabled, isFalse);
    expect(ticker.antiRepeatWindow, 3);

    final containers = tester.widgetList<Container>(find.byType(Container));
    expect(containers.any((container) => container.margin == margin), isTrue);
  });

  testWidgets('renders the flat full-width placeholder variant', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdBanner(
            enabled: false,
            flat: true,
            animatePlaceholder: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(ManagedAdPlaceholderTicker), findsOneWidget);
    final ticker = tester.widget<ManagedAdPlaceholderTicker>(
      find.byType(ManagedAdPlaceholderTicker),
    );
    expect(ticker.fallbackFolderPrefix, 'assets/carousel_home/');
    expect(ticker.enabled, isFalse);
    expect(ticker.antiRepeatWindow, isNull);
    expect(ticker.borderRadius, BorderRadius.circular(18));
  });
}

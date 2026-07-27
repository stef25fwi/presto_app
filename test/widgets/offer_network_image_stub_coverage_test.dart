import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/widgets/offer_network_image_stub.dart';

void main() {
  testWidgets('utilise loadingChild puis errorChild comme fallback',
      (tester) async {
    const errorChild = Text('error');
    const loadingChild = Text('loading');

    final withLoading = buildOfferNetworkImage(
      url: 'https://example.invalid/image.jpg',
      fit: BoxFit.cover,
      errorChild: errorChild,
      loadingChild: loadingChild,
    );
    final withoutLoading = buildOfferNetworkImage(
      url: 'https://example.invalid/image.jpg',
      fit: BoxFit.contain,
      errorChild: errorChild,
    );

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(children: [withLoading, withoutLoading]),
      ),
    );

    expect(find.text('loading'), findsOneWidget);
    expect(find.text('error'), findsOneWidget);
  });
}

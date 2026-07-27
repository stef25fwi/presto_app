import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/app/secondary_named_routes.dart';
import 'package:presto_app/pages/toolbox_hub_page.dart';
import 'package:presto_app/pages/toolbox_page.dart';

void main() {
  testWidgets('construit les trois routes secondaires attendues', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (value) {
            context = value;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final routes = buildSecondaryNamedRoutes();

    expect(
      routes.keys,
      containsAll(<String>{
        AppRoutes.toolboxHub,
        AppRoutes.toolboxCurrent,
        AppRoutes.entrepreneurCalculator,
      }),
    );
    expect(routes, hasLength(3));
    expect(routes[AppRoutes.toolboxHub]!(context), isA<ToolboxPage>());
    expect(routes[AppRoutes.toolboxCurrent]!(context), isA<CurrentToolboxPage>());
    expect(
      routes[AppRoutes.entrepreneurCalculator]!(context),
      isA<EntrepreneurCalculatorPage>(),
    );
  });
}

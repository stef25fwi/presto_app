import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/auth/register_page.dart';
import 'package:presto_app/pages/legal_info_page.dart';

void main() {
  Future<void> pumpRegister(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: RegisterPage()));
    await tester.pump();
  }

  testWidgets('ouvre les CGU depuis la case d acceptation', (tester) async {
    await pumpRegister(tester);

    await tester.tap(find.text('CGU'));
    await tester.pumpAndSettle();

    final page = tester.widget<LegalInfoPage>(find.byType(LegalInfoPage));
    expect(page.initialTab, 2);
  });

  testWidgets('ouvre la politique de confidentialité depuis l inscription',
      (tester) async {
    await pumpRegister(tester);

    await tester.tap(find.text('politique de confidentialité'));
    await tester.pumpAndSettle();

    final page = tester.widget<LegalInfoPage>(find.byType(LegalInfoPage));
    expect(page.initialTab, 1);
  });
}

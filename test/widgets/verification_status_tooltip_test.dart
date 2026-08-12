import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/widgets/verification_status_tooltip.dart';

void main() {
  testWidgets('l’infobulle de vérification est déclenchée au toucher',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VerificationStatusTooltip(
            message: kSiretVerificationDisclaimer,
            child: Text('SIRET vérifié'),
          ),
        ),
      ),
    );

    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(tooltip.triggerMode, TooltipTriggerMode.tap);
    expect(tooltip.message, kSiretVerificationDisclaimer);
    expect(tooltip.showDuration, const Duration(seconds: 7));
  });

  test('les deux textes excluent explicitement une approbation iliprestō', () {
    expect(kPhoneVerificationDisclaimer, contains('ni une approbation'));
    expect(kPhoneVerificationDisclaimer, contains('contrôle SMS'));
    expect(kSiretVerificationDisclaimer, contains('ni une approbation'));
    expect(kSiretVerificationDisclaimer, contains('établissement actif'));
  });
}

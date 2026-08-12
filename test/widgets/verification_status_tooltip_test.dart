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
            message: kSiretLeaderMatchDisclaimer,
            child: Text('SIRET + dirigeant concordants'),
          ),
        ),
      ),
    );

    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(tooltip.triggerMode, TooltipTriggerMode.tap);
    expect(tooltip.message, kSiretLeaderMatchDisclaimer);
    expect(tooltip.showDuration, const Duration(seconds: 7));
  });

  test('les textes excluent explicitement une approbation iliprestō', () {
    expect(kPhoneVerificationDisclaimer, contains('ni une approbation'));
    expect(kPhoneVerificationDisclaimer, contains('contrôle SMS'));
    expect(kSiretVerificationDisclaimer, contains('ni une approbation'));
    expect(kSiretVerificationDisclaimer, contains('établissement actif'));
    expect(kSiretLeaderMatchDisclaimer, contains('ni une approbation'));
    expect(
      kSiretLeaderMatchDisclaimer,
      contains('ne prouve pas que la personne connectée est ce dirigeant'),
    );
  });
}

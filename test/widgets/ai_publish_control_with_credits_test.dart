import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/subscriptions/subscription_credit_service.dart';
import 'package:presto_app/features/subscriptions/subscription_credits_card.dart';
import 'package:presto_app/widgets/ai_publish_control.dart';
import 'package:presto_app/widgets/ai_publish_control_with_credits.dart';

void main() {
  SubscriptionCreditService deterministicCreditsService() {
    return SubscriptionCreditService(
      caller: (name, parameters) async {
        expect(name, 'getMySubscriptionCredits');
        expect(parameters, isNull);
        return <String, dynamic>{
          'plan': 'free',
          'period': '2026-08',
          'freeAccessMode': true,
          'credits': <String, dynamic>{
            'voiceAi': <String, dynamic>{
              'used': 0,
              'limit': 1,
              'remaining': 1,
              'unlimited': false,
              'exhausted': false,
            },
            'textAi': <String, dynamic>{
              'used': 0,
              'limit': 2,
              'remaining': 2,
              'unlimited': false,
              'exhausted': false,
            },
          },
        };
      },
    );
  }

  Future<void> useTallViewport(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  }

  testWidgets('affiche les crédits IA et transmet toutes les options',
      (tester) async {
    await useTallViewport(tester);
    final link = LayerLink();
    final creditsService = deterministicCreditsService();
    var started = 0;
    var stopped = 0;
    var selectedVocal = 0;
    var selectedText = 0;
    var diagnostics = 0;
    var cleared = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiPublishControlWithCredits(
            state: AiPublishState.analyzing,
            micAnchorLink: link,
            isAudioAnalyzing: true,
            onStartRecording: () => started++,
            onStopRecording: () => stopped++,
            onSelectVocal: () => selectedVocal++,
            onSelectText: () => selectedText++,
            onDiagnostic: () => diagnostics++,
            onClear: () => cleared++,
            showAdminDiagnostics: true,
            highlightVocalCard: true,
            dimVocalCard: true,
            creditsService: creditsService,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SubscriptionCreditsInlineBadges), findsOneWidget);
    final badges = tester.widget<SubscriptionCreditsInlineBadges>(
      find.byType(SubscriptionCreditsInlineBadges),
    );
    expect(badges.service, same(creditsService));
    expect(
      badges.kinds,
      const <SubscriptionCreditKind>[
        SubscriptionCreditKind.voiceAi,
        SubscriptionCreditKind.textAi,
      ],
    );

    final control = tester.widget<AiPublishControl>(
      find.byType(AiPublishControl),
    );
    expect(control.state, AiPublishState.analyzing);
    expect(control.micAnchorLink, same(link));
    expect(control.isAudioAnalyzing, isTrue);
    expect(control.showAdminDiagnostics, isTrue);
    expect(control.highlightVocalCard, isTrue);
    expect(control.dimVocalCard, isTrue);

    control.onStartRecording();
    control.onStopRecording();
    control.onSelectVocal();
    control.onSelectText();
    control.onDiagnostic();
    control.onClear();

    expect(started, 1);
    expect(stopped, 1);
    expect(selectedVocal, 1);
    expect(selectedText, 1);
    expect(diagnostics, 1);
    expect(cleared, 1);
  });

  testWidgets('conserve les valeurs optionnelles par défaut', (tester) async {
    await useTallViewport(tester);
    final creditsService = deterministicCreditsService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiPublishControlWithCredits(
            state: AiPublishState.ready,
            micAnchorLink: LayerLink(),
            onStartRecording: () {},
            onStopRecording: () {},
            onSelectVocal: () {},
            onSelectText: () {},
            onDiagnostic: () {},
            onClear: () {},
            creditsService: creditsService,
          ),
        ),
      ),
    );
    await tester.pump();

    final control = tester.widget<AiPublishControl>(
      find.byType(AiPublishControl),
    );
    expect(control.isAudioAnalyzing, isFalse);
    expect(control.showAdminDiagnostics, isFalse);
    expect(control.highlightVocalCard, isFalse);
    expect(control.dimVocalCard, isFalse);
  });
}

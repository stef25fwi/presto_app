import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/publish_offer_page.dart';

void main() {
  test('le parcours IA conserve toutes ses étapes dans l ordre', () {
    expect(
      PublishOfferAiFlowStep.values,
      const <PublishOfferAiFlowStep>[
        PublishOfferAiFlowStep.chooseMethod,
        PublishOfferAiFlowStep.voiceSelected,
        PublishOfferAiFlowStep.voiceAnalyzing,
        PublishOfferAiFlowStep.textSelected,
        PublishOfferAiFlowStep.textAnalyzing,
        PublishOfferAiFlowStep.completed,
      ],
    );
  });
}

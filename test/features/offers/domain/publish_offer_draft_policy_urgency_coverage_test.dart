import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/offers/domain/publish_offer_draft_policy.dart';

void main() {
  test('détecte les deux variantes dès que possible', () {
    expect(
      PublishOfferDraftPolicy.transcriptMentionsUrgency(
        'Intervention dès que possible.',
      ),
      isTrue,
    );
    expect(
      PublishOfferDraftPolicy.transcriptMentionsUrgency(
        'Intervention des que possible.',
      ),
      isTrue,
    );
  });
}

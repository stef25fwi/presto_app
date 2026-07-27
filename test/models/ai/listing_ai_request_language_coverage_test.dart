import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/models/ai/listing_ai_request.dart';

void main() {
  test('utilise fr-FR lorsque le code langue est vide', () {
    const request = ListingAiRequest(
      input: 'Une annonce',
      languageCode: '   ',
    );

    expect(request.toCallablePayload(), <String, dynamic>{
      'input': 'Une annonce',
      'languageCode': 'fr-FR',
    });
  });
}

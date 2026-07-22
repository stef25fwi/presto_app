import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/messages/conversation_thread_page.dart';

void main() {
  test('couvre les valeurs explicites des modèles publics du fil', () {
    const attachment = MessageAttachment(
      type: 'image',
      name: 'preuve.webp',
      url: 'https://cdn/full.webp',
      thumbnailUrl: 'https://cdn/thumb.webp',
      storagePath: 'messages/preview.webp',
      mimeType: 'image/webp',
      sizeBytes: 321,
    );
    expect(attachment.thumbnailUrl, 'https://cdn/thumb.webp');
    expect(attachment.toInput().toJson()['sizeBytes'], 321);

    final decimal = OfferPreview.fromMap('offer-decimal', <String, dynamic>{
      'title': 'Mission décimale',
      'dailyRate': 12.30,
      'photoUrl': 'https://cdn/offer.webp',
    });
    expect(decimal.priceLabel, '12.3 €');
    expect(decimal.imageUrl, 'https://cdn/offer.webp');

    expect(
      OfferPreview.fromMap(
        'offer-negative',
        <String, dynamic>{'price': -1},
      ).priceLabel,
      isEmpty,
    );
    expect(
      OfferPreview.fromMap(
        'offer-text',
        <String, dynamic>{'amount': 'Sur devis €'},
      ).priceLabel,
      'Sur devis €',
    );

    final normalized = MessageModeration.fromMap(
      <String, dynamic>{'status': ' PENDING ', 'visibility': ' HIDDEN '},
    );
    expect(normalized.status, 'pending');
    expect(normalized.visibility, 'hidden');
    expect(normalized.shouldHideContent, isTrue);
  });

  test('couvre les fallbacks publics de modération et de pièce jointe', () {
    final hiddenApproved = MessageModeration.fromMap(
      <String, dynamic>{'status': 'approved', 'visibility': 'hidden'},
    );
    expect(hiddenApproved.shouldHideContent, isTrue);
    expect(hiddenApproved.placeholderText, 'Message modéré');

    final attachment = MessageAttachment.fromMap(<String, dynamic>{
      'type': 'document',
      'name': 'preuve.txt',
      'url': 'https://cdn/preuve.txt',
      'thumbnailUrl': 'https://cdn/preuve-thumb.webp',
      'sizeBytes': 'invalide',
    });
    expect(attachment, isNotNull);
    expect(attachment!.thumbnailUrl, 'https://cdn/preuve-thumb.webp');
    expect(attachment.sizeBytes, 0);
  });
}

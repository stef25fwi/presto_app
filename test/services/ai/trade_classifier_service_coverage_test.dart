import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/ai/trade_classifier_service.dart';

void main() {
  group('TradeClassifierService coverage', () {
    test('classifie une URL avec un métier connu et confiant', () async {
      Map<String, dynamic>? sent;
      final service = TradeClassifierService(
        caller: (parameters) async {
          sent = Map<String, dynamic>.from(parameters);
          return <String, dynamic>{
            'metier': 'serveur',
            'confidence': 0.92,
          };
        },
      );

      final result = await service.classifyFromUrl('https://example.test/photo.jpg');

      expect(sent, <String, dynamic>{
        'imageUrl': 'https://example.test/photo.jpg',
      });
      expect(result.metier, 'serveur');
      expect(result.confidence, 0.92);
      expect(result.isConfident, isTrue);
      expect(result.match?.categorie, 'Restauration / Extra');
    });

    test('transmet le base64 et le type MIME personnalisé', () async {
      Map<String, dynamic>? sent;
      final service = TradeClassifierService(
        caller: (parameters) async {
          sent = Map<String, dynamic>.from(parameters);
          return <String, dynamic>{
            'metier': 'inconnu',
            'confidence': 0.88,
          };
        },
      );

      final result = await service.classifyFromBase64(
        'abc123',
        mimeType: 'image/png',
      );

      expect(sent, <String, dynamic>{
        'imageBase64': 'abc123',
        'mimeType': 'image/png',
      });
      expect(result.metier, 'inconnu');
      expect(result.confidence, 0.88);
      expect(result.isConfident, isFalse);
    });

    test('utilise image/jpeg et refuse une confiance sous le seuil', () async {
      Map<String, dynamic>? sent;
      final service = TradeClassifierService(
        caller: (parameters) async {
          sent = Map<String, dynamic>.from(parameters);
          return <String, dynamic>{
            'metier': 'serveur',
            'confidence': 0.59,
          };
        },
      );

      final result = await service.classifyFromBase64('payload');

      expect(sent, <String, dynamic>{
        'imageBase64': 'payload',
        'mimeType': 'image/jpeg',
      });
      expect(result.isConfident, isFalse);
    });

    test('convertit une confiance absente en zéro', () async {
      final service = TradeClassifierService(
        caller: (_) async => <String, dynamic>{'metier': null},
      );

      final result = await service.classifyFromUrl('image');

      expect(result.metier, isNull);
      expect(result.confidence, 0);
      expect(result.match, isNull);
    });
  });
}

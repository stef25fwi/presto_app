import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:presto_app/features/admin_videomaker/video_maker_models.dart';

void main() {
  group('GeneratedVideo', () {
    test('parse toutes les valeurs et nettoie les champs optionnels', () {
      final video = GeneratedVideo.fromObject(<Object?, Object?>{
        'id': 42,
        'prompt': 'Créer une vidéo',
        'status': 'completed',
        'model': 'veo-test',
        'aspectRatio': '16:9',
        'publicUrl': ' https://example.com/video.mp4 ',
        'createdAt': '2026-07-15T10:30:00Z',
        'errorMessage': '   ',
      });

      expect(video.id, '42');
      expect(video.prompt, 'Créer une vidéo');
      expect(video.status, 'completed');
      expect(video.model, 'veo-test');
      expect(video.aspectRatio, '16:9');
      expect(video.publicUrl, 'https://example.com/video.mp4');
      expect(video.createdAt, DateTime.parse('2026-07-15T10:30:00Z'));
      expect(video.errorMessage, isNull);
    });

    test('applique les valeurs par défaut sur une entrée invalide', () {
      final video = GeneratedVideo.fromObject('invalid');

      expect(video.id, isEmpty);
      expect(video.prompt, 'Sans prompt');
      expect(video.status, 'processing');
      expect(video.model, 'veo-3.1-generate-preview');
      expect(video.aspectRatio, '9:16');
      expect(video.publicUrl, isNull);
      expect(video.createdAt, isNull);
      expect(video.errorMessage, isNull);
    });
  });

  group('imageMimeTypeFor', () {
    test('préfère le mime fourni et le normalise', () {
      final file = XFile('/tmp/photo.bin', mimeType: ' IMAGE/PNG ');
      expect(imageMimeTypeFor(file), 'image/png');
    });

    test('déduit le mime depuis les extensions supportées', () {
      expect(imageMimeTypeFor(XFile('/tmp/photo.png')), 'image/png');
      expect(imageMimeTypeFor(XFile('/tmp/photo.webp')), 'image/webp');
      expect(imageMimeTypeFor(XFile('/tmp/photo.heic')), 'image/heic');
      expect(imageMimeTypeFor(XFile('/tmp/photo.heif')), 'image/heif');
      expect(imageMimeTypeFor(XFile('/tmp/photo.unknown')), 'image/jpeg');
    });
  });

  test('stringMap convertit les clés et refuse les autres types', () {
    expect(stringMap(null), isEmpty);
    expect(stringMap('invalid'), isEmpty);
    expect(
      stringMap(<Object?, Object?>{1: 'one', 'two': 2}),
      <String, Object?>{'1': 'one', 'two': 2},
    );
  });

  test('formatVideoMakerDate gère null et produit un format stable', () {
    expect(formatVideoMakerDate(null), 'Date indisponible');
    final formatted = formatVideoMakerDate(DateTime(2026, 7, 5, 9, 4));
    expect(formatted, '05/07/2026 09:04');
  });

  test('formatVideoMakerBytes couvre octets, Ko et Mo', () {
    expect(formatVideoMakerBytes(512), '512 o');
    expect(formatVideoMakerBytes(1536), '1.5 Ko');
    expect(formatVideoMakerBytes(2 * 1024 * 1024), '2.0 Mo');
    expect(maxVideoMakerImageBytes, 5 * 1024 * 1024);
    expect(supportedVideoMakerImageMimeTypes, contains('image/webp'));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:presto_app/features/admin_videomaker/video_maker_models.dart';

void main() {
  test('GeneratedVideo parses complete payload and nullable fields', () {
    final video = GeneratedVideo.fromObject(<Object?, Object?>{
      'id': 42,
      'prompt': '  carnaval  ',
      'status': 'done',
      'model': 'veo-test',
      'aspectRatio': '16:9',
      'durationSeconds': 12,
      'resolution': '1080p',
      'referenceImageCount': '3',
      'referenceImageNames': <Object?>['a.webp', 7],
      'publicUrl': ' https://example.test/video.mp4 ',
      'fileName': ' video.mp4 ',
      'sizeBytes': '2048',
      'createdAt': '2026-07-28T12:34:00.000Z',
      'generatedAt': '2026-07-28T12:35:00.000Z',
      'errorMessage': '   ',
    });

    expect(video.id, '42');
    expect(video.prompt, '  carnaval  ');
    expect(video.referenceImageCount, 3);
    expect(video.referenceImageNames, <String>['a.webp', '7']);
    expect(video.publicUrl, 'https://example.test/video.mp4');
    expect(video.fileName, 'video.mp4');
    expect(video.sizeBytes, 2048);
    expect(video.createdAt, isNotNull);
    expect(video.generatedAt, isNotNull);
    expect(video.errorMessage, isNull);
  });

  test('GeneratedVideo applies deterministic defaults for malformed input', () {
    final video = GeneratedVideo.fromObject('not-a-map');

    expect(video.id, isEmpty);
    expect(video.prompt, 'Sans prompt');
    expect(video.status, 'processing');
    expect(video.model, 'veo-3.1-generate-preview');
    expect(video.aspectRatio, '9:16');
    expect(video.durationSeconds, '8');
    expect(video.resolution, '720p');
    expect(video.referenceImageCount, 0);
    expect(video.referenceImageNames, isEmpty);
    expect(video.publicUrl, isNull);
    expect(video.sizeBytes, isNull);
    expect(video.createdAt, isNull);
  });

  test('image MIME type prefers metadata then file extension fallbacks', () {
    expect(
      imageMimeTypeFor(XFile('/tmp/photo.unknown', mimeType: ' IMAGE/PNG ')),
      'image/png',
    );
    expect(imageMimeTypeFor(XFile('/tmp/photo.WEBP')), 'image/webp');
    expect(imageMimeTypeFor(XFile('/tmp/photo.heic')), 'image/heic');
    expect(imageMimeTypeFor(XFile('/tmp/photo.heif')), 'image/heif');
    expect(imageMimeTypeFor(XFile('/tmp/photo.bin')), 'image/jpeg');
  });

  test('stringMap normalizes keys and formatters cover unit thresholds', () {
    expect(stringMap(null), isEmpty);
    expect(stringMap(<Object?, Object?>{1: 'one'}), <String, Object?>{'1': 'one'});

    expect(formatVideoMakerBytes(12), '12 o');
    expect(formatVideoMakerBytes(1024), '1.0 Ko');
    expect(formatVideoMakerBytes(1024 * 1024), '1.0 Mo');
    expect(formatVideoMakerDate(null), 'Date indisponible');

    final formatted = formatVideoMakerDate(DateTime(2026, 7, 8, 9, 5));
    expect(formatted, contains('08/07/2026'));
    expect(formatted, endsWith('09:05'));
  });
}

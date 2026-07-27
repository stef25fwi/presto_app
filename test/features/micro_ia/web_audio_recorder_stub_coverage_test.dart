import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/micro_ia/web_audio_recorder_stub.dart';

void main() {
  group('Web audio recorder non-web stub', () {
    test('exposes the complete upload payload', () {
      final bytes = Uint8List.fromList(<int>[1, 2, 3]);
      final upload = WebMicroIaAudioUpload(
        bytes: bytes,
        contentType: 'audio/wav',
        extension: 'wav',
        usedClientSideWavConversion: true,
      );

      expect(upload.bytes, same(bytes));
      expect(upload.contentType, 'audio/wav');
      expect(upload.extension, 'wav');
      expect(upload.usedClientSideWavConversion, isTrue);
    });

    test('recorder operations report that Web is required', () {
      final recorder = WebAudioRecorder();

      expect(
        () => recorder.start(),
        throwsA(
          isA<UnsupportedError>().having(
            (error) => error.message,
            'message',
            'WebAudioRecorder is only available on Web',
          ),
        ),
      );
      expect(
        () => recorder.stopToBlob(),
        throwsA(
          isA<UnsupportedError>().having(
            (error) => error.message,
            'message',
            'WebAudioRecorder is only available on Web',
          ),
        ),
      );
    });

    test('blob conversion helpers report that Web is required', () {
      final blob = Object();

      expect(
        () => webBlobToBytes(blob),
        throwsA(
          isA<UnsupportedError>().having(
            (error) => error.message,
            'message',
            'webBlobToBytes is only available on Web',
          ),
        ),
      );
      expect(
        () => webBlobToWav16kMono(blob),
        throwsA(
          isA<UnsupportedError>().having(
            (error) => error.message,
            'message',
            'webBlobToWav16kMono is only available on Web',
          ),
        ),
      );
      expect(
        () => webBlobToMicroIaUpload(blob),
        throwsA(
          isA<UnsupportedError>().having(
            (error) => error.message,
            'message',
            'webBlobToMicroIaUpload is only available on Web',
          ),
        ),
      );
      expect(
        () => webBlobToMicroIaUpload(blob, preferRawBytes: true),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}

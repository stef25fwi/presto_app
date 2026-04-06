// lib/features/micro_ia/web_audio_recorder_stub.dart

import 'dart:typed_data';

class WebMicroIaAudioUpload {
  const WebMicroIaAudioUpload({
    required this.bytes,
    required this.contentType,
    required this.extension,
    required this.usedClientSideWavConversion,
  });

  final Uint8List bytes;
  final String contentType;
  final String extension;
  final bool usedClientSideWavConversion;
}

class WebAudioRecorder {
  Future<void> start() {
    throw UnsupportedError('WebAudioRecorder is only available on Web');
  }

  Future<Object> stopToBlob() {
    throw UnsupportedError('WebAudioRecorder is only available on Web');
  }
}

/// Stub: not available outside Web.
Future<Uint8List> webBlobToBytes(Object blob) {
  throw UnsupportedError('webBlobToBytes is only available on Web');
}

/// Stub: not available outside Web.
Future<Uint8List> webBlobToWav16kMono(Object blob) {
  throw UnsupportedError('webBlobToWav16kMono is only available on Web');
}

Future<WebMicroIaAudioUpload> webBlobToMicroIaUpload(Object blob) {
  throw UnsupportedError('webBlobToMicroIaUpload is only available on Web');
}

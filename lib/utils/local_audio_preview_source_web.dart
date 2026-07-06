// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<String> createLocalAudioPreviewSource(
  Uint8List bytes, {
  required String contentType,
}) async {
  final normalizedContentType =
      contentType.trim().isEmpty ? 'audio/webm' : contentType.trim();
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: normalizedContentType),
  );
  return web.URL.createObjectURL(blob);
}

void disposeLocalAudioPreviewSource(String source) {
  if (source.trim().isEmpty) return;
  web.URL.revokeObjectURL(source);
}

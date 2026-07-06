import 'dart:typed_data';

Future<Uint8List> readTempFile(String path) {
  throw UnsupportedError('readTempFile is not available on web');
}

Future<String> writeTempFile(
  Uint8List bytes, {
  required String fileName,
}) {
  throw UnsupportedError('writeTempFile is not available on web');
}

void deleteTempFile(String path) {}

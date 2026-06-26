import 'dart:io';
import 'dart:typed_data';

Future<Uint8List> readTempFile(String path) => File(path).readAsBytes();

void deleteTempFile(String path) {
  try {
    File(path).deleteSync();
  } catch (_) {}
}

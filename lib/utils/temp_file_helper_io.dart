import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<Uint8List> readTempFile(String path) => File(path).readAsBytes();

Future<String> writeTempFile(
  Uint8List bytes, {
  required String fileName,
}) async {
  final dir = await getTemporaryDirectory();
  final sanitizedName = fileName
      .trim()
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_');
  final safeName = sanitizedName.isEmpty ? 'piece_jointe.bin' : sanitizedName;
  final path =
      '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_$safeName';
  final file = File(path);
  await file.writeAsBytes(bytes, flush: true);
  return path;
}

void deleteTempFile(String path) {
  try {
    File(path).deleteSync();
  } catch (_) {}
}
